---@diagnostic disable: unresolved-require
package.cpath = package.cpath .. string.format(';%s/lib/?.dll', _G._elxlib_path)

---@type LrexlibPcre2
local _rex = require "rex_pcre2"
local rex = {}

local function pcall_wrap(fn, rv_wrap)
    return function (...)
        local rv = table.pack(pcall(fn, ...))
        if not rv[1] then
            error(rv[2])
        end
        if rv_wrap ~= nil then
            return rv_wrap(rv[2])
        end
        return table.unpack(rv, 2, #rv)
    end
end

local function pcall_wrap_self(fn, self)
    return function (s, ...)
        local rv = table.pack(pcall(fn, self, ...))
        if not rv[1] then
            error(rv[2])
        end
        return table.unpack(rv, 2, #rv)
    end
end

rex.match = pcall_wrap(_rex.match)
rex.find = pcall_wrap(_rex.find)
rex.gsub = pcall_wrap(_rex.gsub)
rex.gmatch = pcall_wrap(_rex.gmatch)
rex.new = pcall_wrap(_rex.new, function(rv)
    local obj = {}
    obj.match = pcall_wrap_self(rv.match, rv)
    obj.find = pcall_wrap_self(rv.find, rv)
    obj.gmatch = pcall_wrap_self(rv.gmatch, rv)
    return obj
end)
rex.version = pcall_wrap(_rex.version)
rex.flags = pcall_wrap(_rex.flags)
rex.unsafe = _rex

---@cast rex LrexlibPcre2
return rex
