local class = require("elxlibs.std.class")
local loops = require("elxlibs.asyncio.loops")
local exception = require("elxlibs.std.exception")
local exceptions = require("elxlibs.asyncio.exceptions")

local function lzy_loops()
    return require("elxlibs.asyncio.loops")
end

local PENDING = "pending"
local CANCELLED = "cancelled"
local FINISHED = "finished"

local futures = {}

---@generic T
---@class asyncio.Future<T> : std.object
---@overload fun(loop?: asyncio.EventLoop): asyncio.Future<T>
local Future = class.new("asyncio.Future")

---@param loop? asyncio.EventLoop
function Future:__init(loop)
    -- debug_msg('Future:__init', loop)

    ---@type asyncio.EventLoop
    self._loop = loop or lzy_loops().get_running_loop()
    ---@type "pending"|"cancelled"|"finished"
    self._state = PENDING
    self._result = nil
    self._exception = nil
    self._cancelled_exc = nil
    self._cancel_msg = nil
    self._asyncio_blocking = false
    self._callbacks = {}
end

function Future:cancel(msg)
    if self._state ~= PENDING then
        return false
    end
    self._cancel_msg = msg
    self._state = CANCELLED
    self:__schedule_callbacks()
    return true
end

function Future:done()
    return self._state ~= PENDING
end

---@return T
function Future:result()
    -- debug_msg('Future:result', self)
    if self._state == CANCELLED then
        exception.raise(exceptions.CancelledError(self._cancel_msg or "Future was cancelled."))
    elseif self._state ~= FINISHED then
        exception.raise(exceptions.InvalidStateError("Result is not available yet."))
    end
    if self._exception ~= nil then
        -- debug_msg('Future:result', self, 'with err', self._exception)
        exception.raise(self._exception)
    end
    return self._result
end

function Future:exception()
    if self._state == CANCELLED then
        exception.raise(exceptions.CancelledError(self._cancel_msg or "Future was cancelled."))
    elseif self._state ~= FINISHED then
        exception.raise(exceptions.InvalidStateError("Exception is not set."))
    end
    return self._exception
end

---@param cb fun(self:asyncio.Future<T>)
function Future:add_done_callback(cb)
    if self._state ~= PENDING then
        self._loop:call_soon(cb, {self})
    else
        table.insert(self._callbacks, cb)
    end
end

function Future:remove_done_callback(fn)
    for i, cb in ipairs(self._callbacks) do
        if cb == fn then
            table.remove(self._callbacks, i)
        end
    end
end

---@param result T
function Future:set_result(result)
    if self._state ~= PENDING then
        exception.raise(exceptions.InvalidStateError("Future is already done, state: ".. self._state))
    end
    self._state = FINISHED
    self._result = result
    self:__schedule_callbacks()
end

function Future:set_exception(exc)
    if self._state ~= PENDING then
        exception.raise(exceptions.InvalidStateError("Future is already done, state: ".. self._state))
    end
    self._state = FINISHED
    self._exception = exc
    self:__schedule_callbacks()
end

---@async
---@return T
function Future:__await()
    if not self:done() then
        -- debug_msg('Future:__await', self._name)
        local err = coroutine.yield(self)
        -- debug_msg('Future:__await yield', self._name, err)
        if err then
            exception.raise(err)
        end
    end
    if not self:done() then
        exception.raise(exception.RuntimeError("await wasn't used with future."))
    end
    return self:result()
end

---@async
---@return T?, any?
function Future:__try_await()
    local err
    if not self:done() then
        err = coroutine.yield(self)
    end
    if not self:done() then
        exception.raise(exception.RuntimeError("await wasn't used with future."))
    end
    return self:result(), err
end

function Future:__schedule_callbacks()
    for _, callback in ipairs(self._callbacks) do
        self._loop:call_soon(callback, {self})
    end
    self._callbacks = {}
end


futures.Future = Future
futures.PENDING = PENDING
futures.CANCELLED = CANCELLED
futures.FINISHED = FINISHED

return futures