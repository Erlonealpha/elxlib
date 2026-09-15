local exception = require "elxlibs.std.exception"
local class = require "elxlibs.std.class"

---@class std._exception
local _M = {}

---@generic P: std.BaseException
---@generic T: P
---@[constructor("__init")]
---@param name `T`
---@param parent P
---@param str string?
---@return T
local function new_exception(name, parent, str)
    ---@diagnostic disable-next-line: param-type-mismatch
    return class.new(name, {parent}, {__name = name, __str = str, __is_std_exception = true})
end

---@class std.BaseException : std.object
---@overload fun(msg: string): self
local BaseException = class.new("std.BaseException", {}, {__name = "BaseException", __str = "base exception"})

---@param msg string?
function BaseException:__init(msg)
    self._message = msg
end

function BaseException:__tostring()
    local msg = self._message or self.__str
    local traceback = self.__traceback or ''
    return string.format('%s: %s%s', self.__name, tostring(msg), traceback)
end

---@class std.Exception : std.BaseException
---@overload fun(msg:string?): self
local Exception = new_exception(
    "std.Exception",            BaseException,  "exception")
---@class std.RuntimeError : std.Exception
---@overload fun(msg:string?): self
local RuntimeError = new_exception(
    "std.RuntimeError",             Exception,  "runtime error")
---@class std.TypeError : std.Exception
---@overload fun(msg:string?): self
local TypeError = new_exception(
    "std.TypeError",                Exception,  "type error")
---@class std.ValueError : std.Exception
---@overload fun(msg:string?): self
local ValueError = new_exception(
    "std.ValueError",               Exception,  "value error")
---@class std.IndexError : std.Exception
---@overload fun(msg:string?): self
local IndexError = new_exception(
    "std.IndexError",               Exception,  "index error")
---@class std.KeyError : std.Exception
---@overload fun(msg:string?): self
local KeyError = new_exception(
    "std.KeyError",                 Exception,  "key error")
---@class std.AttributeError : std.Exception
---@overload fun(msg:string?): self
local AttributeError = new_exception(
    "std.AttributeError",           Exception,  "attribute error")
---@class std.NotImplementedError : std.Exception
---@overload fun(msg:string?): self
local NotImplementedError = new_exception(
    "std.NotImplementedError",      Exception,  "not implemented error")
---@class std.AssertionError : std.Exception
---@overload fun(msg:string?): self
local AssertionError = new_exception(
    "std.AssertionError",           Exception,  "assertion error")
---@class std.EOFError : std.Exception
---@overload fun(msg:string?): self
local EOFError = new_exception(
    "std.EOFError",                 Exception,  "end of file error")
---@class std.IOError : std.Exception
---@overload fun(msg:string?): self
local IOError = new_exception(
    "std.IOError",                  Exception,  "input/output error")
---@class std.OSError : std.Exception
---@overload fun(msg:string?): self
local OSError = new_exception(
    "std.OSError",                  Exception,  "operating system error")
---@class std.ImportError : std.Exception
---@overload fun(msg:string?): self
local ImportError = new_exception(
    "std.ImportError",              Exception,  "import error")
---@class std.MemoryError : std.Exception
---@overload fun(msg:string?): self
local MemoryError = new_exception(
    "std.MemoryError",              Exception,  "memory error")
---@class std.TimeoutError : std.OSError
---@overload fun(msg:string?): self
local TimeoutError = new_exception(
    "std.TimeoutError",             OSError,    "timeout error")


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