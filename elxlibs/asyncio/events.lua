local std = require 'elxlibs.std'

local table = table
local xpcall = xpcall
local string = string
local debug_traceback = debug.traceback
local raise = std.raise

local events = {}

---@class asyncio.Handle : std.object
---@field func fun(...)
---@field args any[]?
---@field loop asyncio.EventLoop
---@overload fun(func: fun(...), args?: any[], loop: asyncio.EventLoop):self
local Handle = std.class.new("asyncio.Handle")
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
    if self.args ~= nil and #self.args > 0 then
        ok, err = xpcall(function()
            self.func(table.unpack(self.args))
        end, debug_traceback)
    else
        ok, err = xpcall(self.func, debug_traceback)
    end
    if not ok then
        self.loop:call_exception_handler{
            handle = self,
            msg = string.format('exception in %s', self.func),
            exception = err,
        }
    end
end

---@class asyncio.TimerHandle : asyncio.Handle
---@field when number
---@overload fun(func: fun(...), args?: any[], when: number, loop: asyncio.EventLoop):self
local TimerHandle = std.class.new('asyncio.Handle', {Handle})
function TimerHandle:__init(func, args, when, loop)
    std.super(TimerHandle, self, Handle).__init(self, func, args, loop)
    self.when = when
end

events.Handle = Handle
events.TimerHandle = TimerHandle

---@type {loop: asyncio.EventLoop?}
local _running_loop = {loop = nil}

--- @return asyncio.EventLoop
function events.get_event_loop()
    local curr = events.get_running_loop()
    if curr == nil then
        curr = require('elxlibs.asyncio.loops').new_event_loop()
    end
    return curr
end

--- @return asyncio.EventLoop
function events.get_running_loop()
    if _running_loop.loop == nil then
        raise(std.RuntimeError('no running event loop'))
    end
    -- debug_msg('get_running_loop', _running_loop.loop)
    return _running_loop.loop
end

---@param loop asyncio.EventLoop?
function events._set_running_loop(loop)
    -- debug_msg('_set_running_loop', loop)
    _running_loop.loop = loop
end

function events._get_running_loop()
    -- debug_msg('_get_running_loop', _running_loop.loop)
    return _running_loop.loop
end

return events
