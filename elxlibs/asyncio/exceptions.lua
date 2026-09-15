local std = require('elxlibs.std')
local exception = std.exception

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

return exceptions
