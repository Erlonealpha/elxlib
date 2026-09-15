local class = require("elxlibs.std.class")
local exception = require("elxlibs.std.exception")
local events = require("elxlibs.asyncio.events")
local log = require("elxlibs.asyncio.log")

local function lzy_futures()
    return require("elxlibs.asyncio.futures")
end
local function lzy_tasks()
    return require("elxlibs.asyncio.tasks")
end

local type = type
local error = error
local table = table
local ipairs = ipairs
local tostring = tostring
local try = exception.try
local finally = exception.finally
local raise = exception.raise


---@class asyncio.loops
local M = {}

---@generic T
---@class asyncio.EventLoop : std.object
---@field _ready asyncio.Handle[]
---@field _scheduled asyncio.TimerHandle[]
---@overload fun():asyncio.EventLoop
local EventLoop = class.new('asyncio.EventLoop')

function EventLoop:__init()
    self._ready = {}
    self._scheduled = {}
    self._running = false
    self._stopping = false
    self._closed = false
end

---@generic T
---@return asyncio.Future<T>
function EventLoop:create_future()
    return lzy_futures().Future(self)
end

---@generic T
---@param func (async fun(...):T)|thread|asyncio.Coroutine<T>
---@param name string?
---@return asyncio.Task<T>
function EventLoop:create_task(func, name)
    self:_check_close()
    return lzy_tasks().Task(func, self, name)
end

---@generic T
---@param future asyncio.Future<T>
---@return T
function EventLoop:run_until_complete(future)
    self:_check_close()
    if future._loop ~= self then
        raise(exception.ValueError("The future belongs to a different event loop"))
    end
    future:add_done_callback(function(fut)
        fut._loop:stop()
    end)
    self:run_forever()
    return future:result()
end

function EventLoop:run_forever()
    self:_check_close()
    self:_check_running()
    self._running = true
    debug_msg('set running loop', self)
    events._set_running_loop(self)

    try {
        function ()
            while true do
                self:_run_once()
                if self._stopping then
                    break
                end
            end
        end,
        finally {
            function (...) 
                self._stopping = false
                self._running = false
                debug_msg('clear running loop')
                events._set_running_loop()
            end
        }
    }
end

function EventLoop:stop()
    self._stopping = true
end

function EventLoop:close()
    if self:is_running() then
        error('cannot close a running event loop')
    end
    if self._closed then
        return
    end
    self._closed = true
    local nready = #self._ready
    for i = 1, nready do
        self._ready[i] = nil
    end
    local nsched = #self._scheduled
    for i = 1, nsched do
        self._scheduled[i] = nil
    end
end

---@param callback function
---@param args? any[]
function EventLoop:_callsoon(callback, args)
    table.insert(self._ready, events.Handle(callback, args, self))
end

---@generic T
---@param delay number
---@param callback fun(...: T...)
---@param args? T[]
---@return asyncio.TimerHandle
function EventLoop:call_later(delay, callback, args)
    return self:call_at(self:time()+delay, callback, args)
end

---@generic T
---@param when number
---@param callback fun(...: T...)
---@param args? T[]
---@return asyncio.TimerHandle
function EventLoop:call_at(when, callback, args) 
    -- debug_msgf('EventLoop:call_at(%.2f, %s)', when, callback)
    if when == nil then
        error('when cannot be nil')
    end
    self:_check_close()
    self._check_callable(callback, 'call_later')
    local handle = events.TimerHandle(callback, args, when, self)
    -- Keep the queue ordered so the first item is always the next deadline.
    -- Inserting after equal deadlines preserves FIFO ordering for callbacks
    -- scheduled at the same time.
    local index = #self._scheduled + 1
    for i, item in ipairs(self._scheduled) do
        if when < item.when then
            index = i
            break
        end
    end
    table.insert(self._scheduled, index, handle)
    return handle
end

---@param callback function
---@param args? any[]
function EventLoop:call_soon(callback, args)
    self:_check_close()
    self._check_callable(callback, 'call_soon')
    self:_callsoon(callback, args)
end

---@return number
function EventLoop:time()
    return os.time()
end

function EventLoop:is_running()
    return self._running
end

function EventLoop:closed()
    return self._closed
end

function EventLoop:_check_close()
    if self._closed then
        raise(exception.RuntimeError("Event loop is closed"))
    end
end

function EventLoop:_check_running()
    if self._running then
        error('this event loop is already running')
    end
    local running_loop = events._get_running_loop()
    if running_loop ~= nil and running_loop ~= self then
        error('cannot running this event loop while another loop is running')
    end
end

function EventLoop._check_callable(callable, funcname)
    local t = type(callable)
    if t ~= "function" then
        error('a function was expected by ' .. funcname .. '(),' ..
            'got' .. t
        )
    end
end

function EventLoop:_run_once()
    local time = self:time()
    while #self._scheduled > 0 do
        local sche = self._scheduled[1]
        if sche.when > time then
            break
        end
        table.insert(self._ready, table.remove(self._scheduled, 1))
    end

    local ntodo = #self._ready
    for i = 1, ntodo do
        local handle = table.remove(self._ready, 1)
        if not handle._cancelled then
            handle:_run()
        end
    end
end

---@alias asyncio._exc_handler_context {
---     msg: any,
---     exception?: any,
---     handle?: asyncio.Handle,
---     task?: asyncio.Task<any>,
---     future?: asyncio.Future<any>,
--- }

---@param handler fun(context: asyncio._exc_handler_context)
function EventLoop:set_exception_handler(handler)
    self._check_callable(handler, 'set_exception_handler')
    self._exception_handler = handler
end

---@return fun(context: asyncio._exc_handler_context)?
function EventLoop:get_exception_handler()
    return self._exception_handler
end

---@param context asyncio._exc_handler_context
function EventLoop.default_exception_handler(context)
    local msg = context.msg
    if not msg then
        msg = 'unhandled exception in asyncio.EventLoop'
    end
    if context.exception ~= nil then
        msg = msg .. '\n' .. tostring(context.exception)
    end
    log.error(msg)
end

---@param context asyncio._exc_handler_context
function EventLoop:call_exception_handler(context)
    if self._exception_handler == nil then
        self.default_exception_handler(context)
    else
        self._exception_handler(context)
    end
end


M.EventLoop = EventLoop

--- Create a new event loop.
--- @return asyncio.EventLoop
function M.new_event_loop()
    return EventLoop()
end

M.get_event_loop = events.get_event_loop

--- Get the running event loop.
M.get_running_loop = events.get_running_loop

return M
