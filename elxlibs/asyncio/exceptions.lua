local std = require('elxlibs.std')
local exception = std.exception

local debug_traceback = debug.traceback

---@class asyncio.exceptions
local exceptions = {}

---@class asyncio.CancelledError : std.BaseException
---@overload fun(msg: string?):self
exceptions.CancelledError = exception.new_exception(
    'asyncio.CancelledError', exception.BaseException,
    'The Future or Task was canceled')

exceptions.TimeoutError = exception.TimeoutError

---@class asyncio.InvalidStateError : std.Exception
---@overload fun(msg: string?):self
exceptions.InvalidStateError = exception.new_exception(
    'asyncio.InvalidStateError', exception.Exception,
    'The operation is not allowed in the current state')

---@param thread thread
---@param error any
function exceptions.collect_thread_error(thread, error)
    if type(error) == "table" and error.__is_std_exception then
        if error.__traceback == nil then
            error.__traceback = debug_traceback(thread, tostring(error), 0)
        end
        return error
    else
        if type(error) ~= "string" then
            error = tostring(error)
        end
        if not error:match('stack traceback') then
            return debug_traceback(thread, error, 0)
        else
            return error
        end
    end
end

return exceptions
