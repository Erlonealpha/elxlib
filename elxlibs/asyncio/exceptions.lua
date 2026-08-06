local std = require('elxlibs.std')
local exception = std.exception

---@class asyncio.exceptions
local exceptions = {}

exceptions.CancelledError = exception.new_exception(
    'asyncio.exceptions.Exception', exception.BaseException,
    'The Future or Task was canceled')

exceptions.TimeoutError = exception.TimeoutError

exceptions.InvalidStateError = exception.new_exception(
    'asyncio.exceptions.InvalidStateError', exception.Exception,
    'The operation is not allowed in the current state')

return exceptions