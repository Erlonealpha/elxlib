---@namespace asyncio

local std = require 'elxlibs.std'

local table = table
local xpcall = std.xpcall
local string = string
local raise = std.raise

local events = {}

---@alias CallbackArgs {n?:integer} & any[]

---@class Handle : std.object
---@field func fun(...)
---@field args CallbackArgs?
---@field loop EventLoop
---@overload fun(func: fun(...), args?: any[], loop: EventLoop):self
local Handle = std.class.new('Handle')
---@param args CallbackArgs?
function Handle:__init(func, args, loop) 
    self.func = func
    self.args = args
    self.loop = loop
    self._cancelled = false
end

function Handle:cancel()
    if not self._cancelled then
        self._cancelled = true
        self.func = nil
        self.args = nil
    end
end

function Handle:_run()
    local ok, err
    if self.args ~= nil then
        ok, err = xpcall(function()
            self.func(table.unpack(self.args, 1, self.args.n or #self.args))
        end)
    else
        ok, err = xpcall(self.func)
    end
    if not ok then
        self.loop:call_exception_handler{
            handle = self,
            msg = string.format('exception in %s', self.func),
            exception = err,
        }
    end
end

---@class TimerHandle : Handle
---@field when number
---@overload fun(func: fun(...), args?: any[], when: number, loop: EventLoop):self
local TimerHandle = std.class.new('TimerHandle', Handle)
function TimerHandle:__init(func, args, when, loop)
    std.super(TimerHandle, self, Handle).__init(self, func, args, loop)
    self.when = when
end

events.Handle = Handle
events.TimerHandle = TimerHandle

---@type {loop: EventLoop?}
local _running_loop = {loop = nil}

--- @return EventLoop
function events.get_event_loop()
    local curr = events._get_running_loop()
    if curr == nil then
        curr = require('elxlibs.asyncio.loops').new_event_loop()
    end
    return curr
end

--- @return EventLoop
function events.get_running_loop()
    if _running_loop.loop == nil then
        raise(std.RuntimeError('no running event loop'))
    end
    -- debug_msg('get_running_loop', _running_loop.loop)
    return _running_loop.loop
end

---@param loop EventLoop?
function events._set_running_loop(loop)
    -- debug_msg('_set_running_loop', loop)
    _running_loop.loop = loop
end

function events._get_running_loop()
    -- debug_msg('_get_running_loop', _running_loop.loop)
    return _running_loop.loop
end

return events
