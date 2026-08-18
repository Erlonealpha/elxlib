local mp = require "mp"
local mptl = require "elxlibs.mptl"

---@class elxfs
local _M = {}

local fstool_path
local plt = mp.get_property("platform")
if plt == "windows" then
    fstool_path = mp.utils.split_path(mp.get_script_directory()) .. "elxlib/bin/" .. "fstool.exe"
else
    fstool_path = mp.utils.split_path(mp.get_script_directory()) .. "elxlib/bin/" .. "fstool"
end

---@param path string
function _M._exists_cmd(path)
    local cmd = {
        fstool_path,
        "-c", "exists",
        "-p", path,
    }
    return cmd
end

---@param path string
---@param exists_ok? boolean
function _M._create_dir_cmd(path, exists_ok)
    if exists_ok == nil then
        exists_ok = true
    end
    local cmd = {
        fstool_path,
        "-c", "mkdir",
        "-p", path,
    }
    if exists_ok then
        table.insert(cmd, "-e")
    end
    return cmd
end

---@param path string
---@param recursive? boolean
function _M._remove_dir_cmd(path, recursive)
local cmd = {
    fstool_path,
    "-c", "rmdir",
    "-p", path,
    }
    if recursive then
        table.insert(cmd, "-r")
    end
    return cmd
end

---@param src string
---@param dst string
---@param recursive? boolean
function _M._copy_cmd(src, dst, recursive)
    local cmd = {
        fstool_path,
        "-c", "copy",
        "-s", src,
        "-d", dst,
        }
        if recursive then
            table.insert(cmd, "-r")
        end
        return cmd
    end

---@param path string
---@param recursive? boolean
function _M._get_size_cmd(path, recursive)
    local cmd = {
        fstool_path,
        "-c", "size",
        "-p", path,
    }
    if recursive then
        table.insert(cmd, "-r")
    end
    return cmd
end

---@param path string
---@return boolean?, string?
function _M.exists(path)
    local result, err = mptl.subprocess{
        args = _M._exists_cmd(path),
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }
    if result == nil then
        return nil, err
    end
    if result.status ~= 0 then
        return nil, 'fs.exists: ' .. result.stderr
    end
    return result.stdout:find("true") ~= nil
end

---@param path string
---@param exists_ok boolean?
---@return boolean, string?
function _M.create_dir(path, exists_ok)
    local result, err = mptl.subprocess{
        args = _M._create_dir_cmd(path, exists_ok),
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }
    if result == nil then
        return false, err
    end
    if result.status ~= 0 then
        return false, 'fs.create_dir: ' .. result.stderr
    end
    return true
end

_M.mkdir = _M.create_dir

---@param path string
---@param recursive? boolean
---@return boolean, string?
function _M.remove_dir(path, recursive)
    local result, err = mptl.subprocess{
        args = _M._remove_dir_cmd(path, recursive),
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }
    if result == nil then
        return false, err
    end
    if result.status ~= 0 then
        return false, 'fs.remove_dir: ' .. result.stderr
    end
    return true
end

---@param src string
---@param dst string
---@param recursive? boolean
---@return boolean, string?
function _M.copy(src, dst, recursive)
    local result, err = mptl.subprocess{
        args = _M._copy_cmd(src, dst, recursive),
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }
    if result == nil then
        return false, err
    end
    if result.status ~= 0 then
        return false, 'fs.copy: ' .. result.stderr
    end
    return true
end

---@param path string
---@param recursive? boolean
---@return int?, string?
function _M.get_size(path, recursive)
    local result, err = mptl.subprocess{
        args = _M._get_size_cmd(path, recursive),
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }
    if result == nil then
        return nil, err
    end
    if result.status ~= 0 then
        return nil, 'fs.get_size: ' .. result.stderr
    end
    return tonumber(result.stdout:match("%d+"))
end

return _M