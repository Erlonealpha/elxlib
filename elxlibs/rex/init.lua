---@diagnostic disable-next-line: unresolved-require
---@type LrexlibPcre2
local _rex = require "rex_pcre2"
local rex = {}
package.loaded['rex_pcre2'] = rex

local type = type
local table = table
local debug = debug
local error = error
local xpcall = xpcall

---@generic T
---@param fn T
---@return T
local function pcall_wrap(fn, rv_wrap)
    return function (arg0, arg1, ...)
        local patt_type = type(arg1)
        if patt_type == "table" and arg1.__wrapped then
            arg1 = arg1.__regex
        end
        local args = {...}
        local rv = table.pack(xpcall(function()
            return fn(arg0, arg1, table.unpack(args))
        end, debug.traceback))
        if not rv[1] then
            error(rv[2], 0)
        end
        if rv_wrap ~= nil then
            return rv_wrap(rv[2])
        end
        return table.unpack(rv, 2, rv.n)
    end
end

local function pcall_wrap_self(fn, self)
    return function (s, ...)
        local args = {...}
        local rv = table.pack(xpcall(function()
            return fn(self, table.unpack(args))
        end, debug.traceback))
        if not rv[1] then
            error(rv[2], 0)
        end
        return table.unpack(rv, 2, rv.n)
    end
end

rex.match = pcall_wrap(_rex.match)
rex.find = pcall_wrap(_rex.find)
rex.gsub = pcall_wrap(_rex.gsub)
rex.gmatch = pcall_wrap(_rex.gmatch)
rex.split = pcall_wrap(_rex.split)
rex.count = pcall_wrap(_rex.count)
rex.new = pcall_wrap(_rex.new, function(rv)
    ---@cast rv LrexlibPcre2Pattern
    local obj = {__wrapped = true, __regex = rv}
    obj.match = pcall_wrap_self(rv.match, rv)
    obj.find = pcall_wrap_self(rv.find, rv)
    obj.tfind = pcall_wrap_self(rv.tfind, rv)
    obj.exec = pcall_wrap_self(rv.exec, rv)
    obj.dfa_exec = pcall_wrap_self(rv.dfa_exec, rv)
    obj.jit_compile = pcall_wrap_self(rv.jit_compile, rv)
    obj.patterninfo = pcall_wrap_self(rv.patterninfo, rv)
    return obj
end)
rex.flags = pcall_wrap(_rex.flags)
rex.maketables = pcall_wrap(_rex.maketables)
rex.config = pcall_wrap(_rex.config)
rex.version = pcall_wrap(_rex.version)
rex.unsafe = _rex
rex.safe_new = pcall_wrap(_rex.new)

-- for type checker
---@class _LrexlibSafeNew : LrexlibPcre2
local _ = {}
_.safe_new = _rex.new

---@class Lrexlib : _LrexlibSafeNew
---@field unsafe LrexlibPcre2
---@cast rex Lrexlib

return rex
