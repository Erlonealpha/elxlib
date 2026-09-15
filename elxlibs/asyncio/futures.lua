local class = require("elxlibs.std.class")
local loops = require("elxlibs.asyncio.loops")
local exception = require("elxlibs.std.exception")
local exceptions = require("elxlibs.asyncio.exceptions")

local raise = exception.raise
local unpack = table.unpack
local coroutine_yield = coroutine.yield

local PENDING = "pending"
local CANCELLED = "cancelled"
local FINISHED = "finished"

local futures = {}

---@generic T, S = self
---@class asyncio.Future<T> : asyncio.Awaitable<T>
---@field _loop asyncio.EventLoop
---@field _state "pending"|"cancelled"|"finished"
---@field _result T?
---@field _exception any?
---@field _cancelled_exc any?
---@field _cancel_msg string?
---@field _callbacks fun(fut: S)[]
---@overload fun(loop?: asyncio.EventLoop): asyncio.Future<T>
local Future = class.new("asyncio.Future")

---@param loop? asyncio.EventLoop
function Future:__init(loop)
    -- debug_msg('Future:__init', loop)

    self._loop = loop or loops.get_running_loop()
    self._state = PENDING
    self._exception = nil
    self._cancelled_exc = nil
    self._cancel_msg = nil
    self._asyncio_blocking = false
    self._log_traceback = false
    self._callbacks = {}
end

function Future:cancel(msg)
    self._log_traceback = false
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

function Future:cancelled()
    return self._state == CANCELLED
end

---@return T...
function Future:result()
    -- debug_msg('Future:result', self)
    if self._state == CANCELLED then
        raise(self:_make_cancelled_error())
    elseif self._state ~= FINISHED then
        raise(exceptions.InvalidStateError("Result is not available yet."))
    end
    self._log_traceback = false
    if self._exception ~= nil then
        raise(self._exception, 0)
    end
    return unpack(self._result)
end

function Future:exception()
    if self._state == CANCELLED then
        raise(self:_make_cancelled_error())
    elseif self._state ~= FINISHED then
        raise(exceptions.InvalidStateError("Exception is not set."))
    end
    self._log_traceback = false
    return self._exception
end

---@generic T
---@param cb fun(fut: self)
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

---@param ... T...
function Future:set_result(...)
    if self._state ~= PENDING then
        raise(exceptions.InvalidStateError("Future is already done, state: ".. self._state))
    end
    self._state = FINISHED
    self._result = {...}
    self:__schedule_callbacks()
end

function Future:set_exception(exc)
    if self._state ~= PENDING then
        raise(exceptions.InvalidStateError("Future is already done, state: ".. self._state))
    end
    self._state = FINISHED
    self._exception = exc
    self:__schedule_callbacks()
    self._log_traceback = true
end

---@return asyncio.CancelledError
function Future:_make_cancelled_error()
    if self._cancelled_exc ~= nil then
        return self._cancelled_exc
    end
    return exceptions.CancelledError(self._cancel_msg or "Future was cancelled.")
end

---@return asyncio.EventLoop
function Future:_get_loop()
    return self._loop
end

---@async
---@return T
function Future:__await()
    if not self:done() then
        -- debug_msg('Future:__await', self._name)
        local err = coroutine_yield(self)
        -- debug_msg('Future:__await yield', self._name, err)
        if err then
            raise(err, 0)
        end
    end
    if not self:done() then
        raise(exception.RuntimeError("await wasn't used with future."))
    end
    return self:result()
end

---@async
---@return T?, any?
function Future:__try_await()
    local err
    if not self:done() then
        err = coroutine_yield(self)
    end
    if not self:done() then
        raise(exception.RuntimeError("await wasn't used with future."))
    end
    if self._exception ~= nil then
        return nil, self._exception
    end
    return self:result(), err
end

function Future:__schedule_callbacks()
    for _, callback in ipairs(self._callbacks) do
        self._loop:call_soon(callback, {self})
    end
    self._callbacks = {}
end

function Future:__gc()
    if self._log_traceback then
        local exc = self._exception
        self._loop:call_exception_handler{
            future = self,
            msg = 'Future exception was never retrieved',
            exception = exc
        }
    end
end


futures.Future = Future
futures.PENDING = PENDING
futures.CANCELLED = CANCELLED
futures.FINISHED = FINISHED

return futures
