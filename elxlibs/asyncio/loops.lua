local class = require("elxlibs.std.class")
local exception = require("elxlibs.std.exception")
local exc = require("elxlibs.asyncio.exceptions")
local events = require("elxlibs.asyncio.events")


local function lzy_futures()
    return require("elxlibs.asyncio.futures")
end
local function lzy_tasks()
    return require("elxlibs.asyncio.tasks")
end

---@class asyncio.loops
local M = {}

---@class asyncio.EventLoop : std.object
---@overload fun():asyncio.EventLoop
local EventLoop = class.new('EventLoop')

function EventLoop:__init()
    ---@type {func: function, args: any[]?, _debug_msg?: string}[]
    self._ready = {}
    ---@type {func: function, args: any[]?, when?: number, _debug_msg?: string}[]
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
---@param func fun(...):T
---@param name string?
function EventLoop:create_task(func, name)
    self:_check_close()
    return lzy_tasks().Task(func, self, name)
end

---@generic T
---@param future asyncio.Future<T>
function EventLoop:run_until_complete(future)
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
    -- debug_msg('set running loop', self)
    events._set_running_loop(self)

    exception.try {
        function ()
            while true do
                self:_run_once()
                if self._stopping then
                    break
                end
            end
        end,
        exception.finally {
            function (...) 
                self._stopping = false
                self._running = false
                -- debug_msg('clear running loop')
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
    table.insert(self._ready, {func = callback, args = args})
end

---@param delay number
---@param callback function
---@param args? any[]
function EventLoop:call_later(delay, callback, args)
    return self:call_at(self:time()+delay, callback, args)
end

---@param when number
---@param callback function
---@param args? any[]
function EventLoop:call_at(when, callback, args) 
    if when == nil then
        error('when cannot be nil')
    end
    self:_check_close()
    self:_check_callable(callback, 'call_later')
    table.insert(self._scheduled, {
        func = callback,
        args = args,
        when = when,
    })
end

---@param callback function
---@param args? any[]
function EventLoop:call_soon(callback, args)
    self:_check_close()
    self:_check_callable(callback, 'call_soon')
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
        exception.raise(exception.RuntimeError("Event loop is closed"))
    end
end

function EventLoop:_check_running()
    if self._running then
        error('this event loop is already running')
    end
    if events._get_running_loop() ~= nil then
        error('cannot running this event loop while another loop is running')
    end
end

function EventLoop:_check_callable(callable, funcname)
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
        if sche.when >= time then
            break
        end
        table.insert(self._ready, table.remove(self._scheduled, 1))
    end

    local ntodo = #self._ready
    for i = 1, ntodo do
        local t = table.remove(self._ready, 1)
        if t.args and #t.args > 0 then
            t.func(table.unpack(t.args))
        else
            t.func()
        end
    end
end


M.EventLoop = EventLoop

--- Create a new event loop.
--- @return asyncio.EventLoop
function M.new_event_loop()
    return EventLoop()
end

--- Get the running event loop.
--- @return asyncio.EventLoop
function M.get_running_loop()
    local loop = events._get_running_loop()
    if loop == nil then
        loop = M.new_event_loop()
        events._set_running_loop(loop)
    end
    return loop
end

return M