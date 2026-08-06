local exception = require "elxlibs.std.exception"
local class = require "elxlibs.std.class"

---@generic T: std.BaseException
---@param name string
---@param parent T
---@param str string?
local function new_exception(name, parent, str)
    return class.new(name, {parent}, {__name = name, __str = str})
end

---@class std.BaseException : std.object
---@overload fun(msg:string): std.BaseException
local BaseException = class.new("BaseException", {}, {__name = "BaseException", __str = "base exception"})


function BaseException:__init(msg)
    self._message = msg
end

function BaseException:__tostring()
    local msg = self._message or self.__str
    return self.__name.. ": ".. tostring(msg)
end

---@class std.Exception : std.BaseException
---@overload fun(msg:string): std.Exception
local Exception = new_exception(
    "Exception",            BaseException,  "exception")
---@class std.RuntimeError : std.Exception
---@overload fun(msg:string): std.RuntimeError
local RuntimeError = new_exception(
    "RuntimeError",             Exception,  "runtime error")
---@class std.TypeError : std.Exception
---@overload fun(msg:string): std.TypeError
local TypeError = new_exception(
    "TypeError",                Exception,  "type error")
---@class std.ValueError : std.Exception
---@overload fun(msg:string): std.ValueError
local ValueError = new_exception(
    "ValueError",               Exception,  "value error")
---@class std.IndexError : std.Exception
---@overload fun(msg:string): std.IndexError
local IndexError = new_exception(
    "IndexError",               Exception,  "index error")
---@class std.KeyError : std.Exception
---@overload fun(msg:string): std.KeyError
local KeyError = new_exception(
    "KeyError",                 Exception,  "key error")
---@class std.AttributeError : std.Exception
---@overload fun(msg:string): std.AttributeError
local AttributeError = new_exception(
    "AttributeError",           Exception,  "attribute error")
---@class std.NotImplementedError : std.Exception
---@overload fun(msg:string): std.NotImplementedError
local NotImplementedError = new_exception(
    "NotImplementedError",      Exception,  "not implemented error")
---@class std.AssertionError : std.Exception
---@overload fun(msg:string): std.AssertionError
local AssertionError = new_exception(
    "AssertionError",           Exception,  "assertion error")
---@class std.EOFError : std.Exception
---@overload fun(msg:string): std.EOFError
local EOFError = new_exception(
    "EOFError",                 Exception,  "end of file error")
---@class std.IOError : std.Exception
---@overload fun(msg:string): std.IOError
local IOError = new_exception(
    "IOError",                  Exception,  "input/output error")
---@class std.OSError : std.Exception
---@overload fun(msg:string): std.OSError
local OSError = new_exception(
    "OSError",                  Exception,  "operating system error")
---@class std.ImportError : std.Exception
---@overload fun(msg:string): std.ImportError
local ImportError = new_exception(
    "ImportError",              Exception,  "import error")
---@class std.MemoryError : std.Exception
---@overload fun(msg:string): std.MemoryError
local MemoryError = new_exception(
    "MemoryError",              Exception,  "memory error")
---@class std.TimeoutError : std.OSError
---@overload fun(msg:string): std.TimeoutError
local TimeoutError = new_exception(
    "TimeoutError",             OSError,    "timeout error")


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


return exception