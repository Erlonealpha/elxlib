-- This file is part of libsElx and is released under the terms of the MIT license.
-- Copyright (C) 2025 ErloneAlpha

-- This file is the main module of the std library. It provides some basic functions and classes.


---@class elxstd
local M = {version = "0.1.0"}

-- set this to true to obitain permission to access/modify the class/instance metatables
_G._STD_CLASS_DEBUG = false

local exception = require "elxlibs.std.exception"
local class = require "elxlibs.std.class"

-- lazy initialization of modules
require "elxlibs.std.exception_init"

function M.round(num)
    if num >= 0 then
        return math.floor(num + 0.5)
    else
        return math.ceil(num - 0.5)
    end
end

function M.clamp(num, min, max)
    return math.max(math.min(num, max), min)
end

---@param str string
---@param pattern string
---@param maxsplit? number
---@return string[]
function M.split(str, pattern, maxsplit)
    local function escape_pattern(p)
        return p:gsub("([^%w])", "%%%1")
    end

    local result = {}
    local full_pattern = '(.-)' .. escape_pattern(pattern)
    local last_end = 1
    local start_index, end_index, capture = str:find(full_pattern, 1)

    while start_index and end_index do
        table.insert(result, capture)
        last_end = end_index + 1
        if maxsplit and #result >= maxsplit then
            break
        end
        start_index, end_index, capture = str:find(full_pattern, last_end)
    end

    if last_end <= #str + 1 then
        table.insert(result, str:sub(last_end))
    end

    return result
end


-- ---@param str string
-- ---@return string
-- function M.strip(str, chars)
--     if not str then
--         return ""
--     end
--     if type(str) ~= "string" then
--         exception.raise(exception.TypeError("Expected string, got " .. type(str)))
--     end
--     if not chars then
--         chars = " "
--     end
-- end

---@param str string
---@return string[]
function M.comma_split(str)
    if not str then
        return {}
    end
    if type(str) ~= "string" then
        exception.raise(exception.TypeError("Expected string, got " .. type(str)))
    end
    return str:match("^%s*$") and {} or M.split(str, "%s*,%s*")
end

function M.trim(str)
    return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

M.class = class
M.super = class.super
M.kindof = class.kindof
M.issubclass = class.issubclass
M.isinstance = class.isinstance

M.exception = exception
M.raise = exception.raise
M.try = exception.try
M.catch = exception.catch
M.finally = exception.finally

M.BaseException = exception.BaseException
M.Exception = exception.Exception
M.RuntimeError = exception.RuntimeError
M.TypeError = exception.TypeError
M.ValueError = exception.ValueError
M.IndexError = exception.IndexError
M.KeyError = exception.KeyError
M.AttributeError = exception.AttributeError
M.NotImplementedError = exception.NotImplementedError
M.AssertionError = exception.AssertionError
M.EOFError = exception.EOFError
M.IOError = exception.IOError
M.OSError = exception.OSError
M.ImportError = exception.ImportError
M.MemoryError = exception.MemoryError
M.TimeoutError = exception.TimeoutError

return M