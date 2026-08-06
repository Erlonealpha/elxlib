---@diagnostic disable: unresolved-require
---@module 'libsElx'
---@author Erlone

local mp = require("mp")

local scripts_dir = mp.command_native({"expand-path", "~~/scripts"})
package.path = package.path .. ";" .. scripts_dir .. "/?.lua"
package.path = package.path .. ";" .. scripts_dir .. "/?/init.lua"

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
    mp.msg.info('loading2', modname)
    return require("elxlib."..modname)
end

---@param modname string
local function loader3(modname)
    mp.msg.info('loading3', modname)
    local m = str_split(modname, '.')
    return require("elxlib.elxlibs."..m[2])
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
    -- mp.msg.info(module, ':', mp.utils.format_table(files))
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
            local module_ = table.concat({module, dir}, '.')
            for _, module__ in ipairs(find_sub_modules(module_)) do
                table.insert(sub_modules, module__)
            end
        end
    end
    if files ~= nil then
        for _, file in ipairs(files) do
            local f = strip_ext(file)
            if f ~= "init" then
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
        package.preload['elxlib.' .. modname] = loader3
        local sub_modules = find_sub_modules(modname)
        -- if #sub_modules > 0 then
        --     mp.msg.info('sub_modules:', mp.utils.format_table(sub_modules))
        -- end
        for _, sub in ipairs(sub_modules) do
            package.preload['elxlibs.' .. sub] = loader2
            package.preload['elxlib.' .. sub] = loader3
        end
    end
end

---@type elxlib
local t = setmetatable({}, {
    ---@param self self
    ---@param name string
    __index = function (self, name)
        mp.msg.info('loading', name)
        local backend = require("elxlib."..name)
        ---@diagnostic disable-next-line: inject-field
        self[name] = backend
        return backend
    end
})

return t