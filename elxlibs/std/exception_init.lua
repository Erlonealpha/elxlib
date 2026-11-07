---@namespace std

local exception = require "elxlibs.std.exception"
local class = require "elxlibs.std.class"

---@class _exception
local _M = {}

---@generic P: BaseException
---@generic T: P
---@[constructor("__init")]
---@param name `T`
---@param parent P
---@param str string?
---@return T
local function new_exception(name, parent, str)
    ---@diagnostic disable-next-line: param-type-mismatch
    return class.new(name, parent, {__name = name, __str = str, __is_std_exception = true})
end

---@diagnostic disable-next-line: generic-constraint-mismatch EmmyluaBUG
---@class BaseException : object
---@field __name string
---@field __str string
---@field __traceback string?
---@field __cause any?
---@field __is_std_exception true
---@overload fun(msg: string): self
local BaseException = class.new("BaseException", nil, { __str = "base exception" })

---@param msg string?
function BaseException:__init(msg)
    self._message = msg
end

function BaseException:__tostring()
    local msg = self._message or self.__str
    local traceback = self.__traceback or ''
    local cause = ''
    if self.__cause ~= nil then
        local sep = '\nThe above exception was the direct cause of the following exception:\n'
        if type(self.__cause) ~= 'string' then
            cause = tostring(self.__cause) .. sep
        else
            cause = self.__cause .. sep
        end
    end

    return string.format('%s%s: %s%s', cause, self.__name, tostring(msg), traceback)
end

---@class Exception : BaseException
---@overload fun(msg:string?): self
local Exception = new_exception(
    "Exception",            BaseException,  "exception")
---@class RuntimeError : Exception
---@overload fun(msg:string?): self
local RuntimeError = new_exception(
    "RuntimeError",             Exception,  "runtime error")
---@class TypeError : Exception
---@overload fun(msg:string?): self
local TypeError = new_exception(
    "TypeError",                Exception,  "type error")
---@class ValueError : Exception
---@overload fun(msg:string?): self
local ValueError = new_exception(
    "ValueError",               Exception,  "value error")
---@class IndexError : Exception
---@overload fun(msg:string?): self
local IndexError = new_exception(
    "IndexError",               Exception,  "index error")
---@class KeyError : Exception
---@overload fun(msg:string?): self
local KeyError = new_exception(
    "KeyError",                 Exception,  "key error")
---@class AttributeError : Exception
---@overload fun(msg:string?): self
local AttributeError = new_exception(
    "AttributeError",           Exception,  "attribute error")
---@class NotImplementedError : Exception
---@overload fun(msg:string?): self
local NotImplementedError = new_exception(
    "NotImplementedError",      Exception,  "not implemented error")
---@class AssertionError : Exception
---@overload fun(msg:string?): self
local AssertionError = new_exception(
    "AssertionError",           Exception,  "assertion error")
---@class EOFError : Exception
---@overload fun(msg:string?): self
local EOFError = new_exception(
    "EOFError",                 Exception,  "end of file error")
---@class IOError : Exception
---@overload fun(msg:string?): self
local IOError = new_exception(
    "IOError",                  Exception,  "input/output error")
---@class OSError : Exception
---@overload fun(msg:string?): self
local OSError = new_exception(
    "OSError",                  Exception,  "operating system error")
---@class ImportError : Exception
---@overload fun(msg:string?): self
local ImportError = new_exception(
    "ImportError",              Exception,  "import error")
---@class MemoryError : Exception
---@overload fun(msg:string?): self
local MemoryError = new_exception(
    "MemoryError",              Exception,  "memory error")
---@class TimeoutError : OSError
---@overload fun(msg:string?): self
local TimeoutError = new_exception(
    "TimeoutError",             OSError,    "timeout error")


_M.new_exception = new_exception
_M.BaseException = BaseException
_M.Exception = Exception
_M.RuntimeError = RuntimeError
_M.TypeError = TypeError
_M.ValueError = ValueError
_M.IndexError = IndexError
_M.KeyError = KeyError
_M.AttributeError = AttributeError
_M.NotImplementedError = NotImplementedError
_M.AssertionError = AssertionError
_M.EOFError = EOFError
_M.IOError = IOError
_M.OSError = OSError
_M.ImportError = ImportError
_M.MemoryError = MemoryError
_M.TimeoutError = TimeoutError

exception.new_exception = new_exception
exception.BaseException = BaseException
exception.Exception = Exception
exception.RuntimeError = RuntimeError
exception.TypeError = TypeError
exception.ValueError = ValueError
exception.IndexError = IndexError
exception.KeyError = KeyError
exception.AttributeError = AttributeError
exception.NotImplementedError = NotImplementedError
exception.AssertionError = AssertionError
exception.EOFError = EOFError
exception.IOError = IOError
exception.OSError = OSError
exception.ImportError = ImportError
exception.MemoryError = MemoryError
exception.TimeoutError = TimeoutError

_M = nil

return exception