local mp = require 'mp'

local _M = {}

local fstool_path
local plt = mp.get_property("platform")
if plt == "windows" then
    fstool_path = mp.utils.split_path(mp.get_script_directory()) .. "elxlib/bin/" .. "fstool.exe"
else
    fstool_path = mp.utils.split_path(mp.get_script_directory()) .. "elxlib/bin/" .. "fstool"
end

---@param path string
---@param cb fun(exists:boolean, err:string)
function _M.exists(path, cb)
    local args = {
        fstool_path,
        "-c", "exists",
        "-p", path,
    }
    Utils.call_cmd_async(args, function (ok, res, err)
        if not ok then
            cb(false, err)
        else
            cb(true, res:find("true") ~= nil)
        end
    end)
end

---@param path string
---@param recursive boolean?
---@param exists_ok boolean?
---@param cb fun(ok:boolean, err:string)
function _M.create_dir(path, recursive, exists_ok, cb)
    if exists_ok == nil then
        exists_ok = true
    end
    local args = {
        fstool_path,
        "-c", "mkdir",
        "-p", path,
    }
    if recursive then
        table.insert(args, "-r")
    end
    if exists_ok then
        table.insert(args, "-e")
    end
    Utils.call_cmd_async(args, function (ok, res, err)
        cb(ok, err)
    end)
end

function _M.remove_dir(path, recursive, cb)
    local args = {
        fstool_path,
        "-c", "rmdir",
        "-p", path,
    }
    if recursive then
        table.insert(args, "-r")
    end
    Utils.call_cmd_async(args, function (ok, res, err)
        cb(ok, err)
    end)
end

function _M.copy(src, dst, recursive, cb)
    local args = {
        fstool_path,
        "-c", "copy",
        "-s", src,
        "-d", dst,
    }
    if recursive then
        table.insert(args, "-r")
    end
    Utils.call_cmd_async(args, function (ok, res, err)
        cb(ok, err)
    end)
end

function _M.get_size(path, recursive, cb)
    local args = {
        fstool_path,
        "-c", "size",
        "-p", path,
    }
    if recursive then
        table.insert(args, "-r")
    end
    Utils.call_cmd_async(args, function (ok, res, err)
        if not ok then
            cb(false, err)
            return
        end
        local size = tonumber(res:match("%d+"))
        cb(true, size)
    end)
end

function _M.read_stream(path, cb)
    
end

return _M