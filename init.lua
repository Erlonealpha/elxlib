---@module 'elxlib'
---@author Erlone

local script_name = ...

local mp = require("mp")
mp.utils = require 'mp.utils'


---@class elxlib
---@field asyncio asyncio
---@field aiofs aiofs
---@field copy elxcopy
---@field fs elxfs
---@field hashlib hashlib
---@field json json
-----@field cjson cjson
---@field std elxstd
---@field mptl mptl
---@field rex LrexlibPcre2
---@field lockfile elxlockfile
---@field lxp LuaExpat
---@field fun FunLib

local debug = false
if not _G.debug_msg then
    function debug_msg(arg0, ...)
        if debug then
            if type(arg0) == 'function' then
                mp.msg.info('DEBUG', arg0(...))
            else
                mp.msg.info('DEBUG', arg0, ...)
            end
        end
    end
end

local scripts_dir = mp.command_native({"expand-path", "~~/scripts"})
_G._elxlib_path = scripts_dir .. '/' .. script_name
_G._mpv_path = mp.command_native({"expand-path", "~~exe_dir/"})
package.path = package.path .. ";" .. scripts_dir .. "/?.lua"
package.path = package.path .. ";" .. scripts_dir .. "/?/init.lua"
package.cpath = package.cpath .. ";" .. scripts_dir .. "/?.dll"
package.cpath = package.cpath .. string.format(';%s/bin/?.dll', _G._elxlib_path)
local lib_prefix = script_name .. '.'


local function add_bin_dllpath()
    local ffi = require("ffi")

    local function to_wchar(lua_str)
        local CP_UTF8 = 65001
        -- Find required buffer size
        local len = ffi.C.MultiByteToWideChar(CP_UTF8, 0, lua_str, -1, nil, 0)
        if len == 0 then return nil end
        
        -- Allocate and fill the wchar_t array
        local buf = ffi.new("wchar_t[?]", len)
        ffi.C.MultiByteToWideChar(CP_UTF8, 0, lua_str, -1, buf, len)
        return buf
    end

    ffi.cdef[[
        typedef uint16_t wchar_t;
        int MultiByteToWideChar(
            unsigned int CodePage, 
            unsigned long dwFlags, 
            const char* lpMultiByteStr, 
            int cbMultiByte, 
            wchar_t* lpWideCharStr, 
            int cchWideChar
        );
        int _wputenv(const wchar_t* envstring);
    ]]

    local msvcrt = ffi.load("msvcrt")

    local env_path = os.getenv("PATH") or ""
    local bin_dir = string.format("%s\\bin", _G._elxlib_path)
    bin_dir = bin_dir:gsub("[\\/]$", ""):gsub("/", "\\")
    local new_env_path = string.format("PATH=%s;%s", bin_dir, env_path)

    local wdir = to_wchar(new_env_path)

    local result = msvcrt._wputenv(wdir)
    if result ~= 0 then
        print("Warning: Add dll path to env failed.")
    end
end

---@param str string
---@param pattern string
---@param maxsplit? number
---@return string[]
local function str_split(str, pattern, maxsplit)
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

---@param modname string
local function loader2(modname)
    debug_msg('loading2', modname)
    return require(lib_prefix..modname)
end

---@param modname string
local function loader3(modname)
    debug_msg('loading3', modname)
    local m = str_split(modname, '.')
    return require(lib_prefix.."elxlibs."..m[2])
end

---@param module string
---@param dir boolean
---@return string[]?
local function list_module_dir(module, dir)
    module = module:gsub('%.', '/')
    local filter = dir and "dirs" or "files"
    local files, err = mp.utils.readdir(scripts_dir .. '/elxlib/elxlibs/' .. module, filter)
    if err then
        error('elxlib load failed to search submodule ' .. module .. ' err: ' .. err)
    end
    if files == nil or #files == 0 then
        return
    end
    debug_msg(module, ':', mp.utils.format_table(files))
    return files
end

---@param path string
local function strip_ext(path)
    return path:gsub("%.[^%.]+$", "")
end

---@param module string
---@return string[]
local function find_sub_modules(module)
    local dirs = list_module_dir(module, true)
    local files = list_module_dir(module, false)
    local sub_modules = {}
    if dirs ~= nil then
        for _, dir in ipairs(dirs) do
            if dir ~= "meta" then
                local module_ = table.concat({module, dir}, '.')
                for _, module__ in ipairs(find_sub_modules(module_)) do
                    table.insert(sub_modules, module__)
                end
            end
        end
    end
    if files ~= nil then
        for _, file in ipairs(files) do
            local f = strip_ext(file)
            if f == "init" or f == "meta" then
                -- continue
            else
                table.insert(sub_modules, table.concat({module, f}, '.'))
            end
        end
    end
    return sub_modules
end

local module_names = list_module_dir("", true)
if module_names == nil then
    error('elxlib load failed to search submodules')
end
for _, modname in ipairs(module_names) do
    if not modname:match("^%.") then
        package.preload['elxlibs.' .. modname] = loader2
        package.preload[lib_prefix .. modname] = loader3
        local sub_modules = find_sub_modules(modname)
        -- if #sub_modules > 0 then
        --     mp.msg.info('sub_modules:', mp.utils.format_table(sub_modules))
        -- end
        for _, sub in ipairs(sub_modules) do
            package.preload['elxlibs.' .. sub] = loader2
            package.preload[lib_prefix .. sub] = loader3
        end
    end
end

---@type elxlib
local t = setmetatable({}, {
    ---@param self self
    ---@param name string
    __index = function (self, name)
        debug_msg('loading', name)
        local backend = require(lib_prefix..name)
        ---@diagnostic disable-next-line: inject-field
        self[name] = backend
        return backend
    end
})

add_bin_dllpath()

return t