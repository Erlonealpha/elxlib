local class = require("elxlibs.std.class")
local exception = require("elxlibs.std.exception")
local exc = require("elxlibs.asyncio.exceptions")
local futures = require("elxlibs.asyncio.futures")
local tasks = require("elxlibs.asyncio.tasks")

---@class asyncio.loops
local M = {}

---@class asyncio.EventLoop : std.object
---@overload fun():asyncio.EventLoop
local EventLoop = class.new()

function EventLoop:__init()
    self._ready = {}
    self._stopping = false
    self._closed = false
end

function EventLoop:create_future()
    return futures.Future(self)
end

function EventLoop:create_task(coro, name)
    self:_check_close()
    return tasks.Task(coro, self, name)
end

function EventLoop:run_until_complete(future) end

function EventLoop:run_forever() end

function EventLoop:stop() end

function EventLoop:close() end

function EventLoop:call_soon(callback,...) end

function EventLoop:call_later(delay, callback,...) end

function EventLoop:call_at(when, callback,...) end

function EventLoop:_check_close()
    if self._closed then
        exception.raise(exception.RuntimeError("Event loop is closed"))
    end
end


M.EventLoop = EventLoop

local _running_loop = nil

--- Create a new event loop.
--- @return asyncio.EventLoop
function M.new_event_loop()
    return EventLoop()
end

--- Get the running event loop.
--- @return asyncio.EventLoop
function M.get_running_loop()
    if _running_loop == nil then
        _running_loop = M.new_event_loop()
    end
    return _running_loop
end

return M