local asyncio = require 'elxlibs.asyncio'
local amp = require 'elxlibs.asyncio.mp'
local fs = require 'elxlibs.fs'
local std = require 'elxlibs.std'

---@class aiofs
local M = {version = '0.2.0'}

---@alias aiofsResult<T> { ok: boolean, result: T?, error: string? }

---@generic T
---@param args string[]
---@param get_result fun(result: table):aiofsResult<T>
---@return asyncio.Coroutine<aiofsResult<T>>
local function amp_subprocess(args, get_result)
    return asyncio.async(function()
        ---@type asyncio.Future<aiofsResult<T>>
        local fut = asyncio.loops.get_running_loop():create_future()
        local handle, launch_error = amp.command_native_async({
            name = 'subprocess',
            args = args,
            playback_only = false,
            capture_stdout = true,
            capture_stderr = true,
        }, function(success, result, err)
            -- Cancellation and duplicate/late host replies must not settle twice.
            if fut:done() then return end
            if not success or type(result) ~= 'table' or result.status ~= 0 then
                local message = err or (type(result) == 'table' and result.stderr)
                fut:set_result({ok = false, error = message and message ~= '' and message or 'subprocess failed'})
                return
            end
            local ok, value = pcall(get_result, result)
            if ok then
                fut:set_result(value)
            else
                fut:set_result({ok = false, error = tostring(value)})
            end
        end)
        if not handle and not fut:done() then
            fut:set_result({ok = false, error = launch_error or 'subprocess could not start'})
        end
        local ok, result = asyncio.try_await(fut)
        if not ok then
            if handle then amp.abort_async_command(handle) end
            std.raise(result, 0)
        end
        return result
    end)
end

---@async
---@param path string
---@return asyncio.Coroutine<aiofsResult<boolean>>
function M.exists(path)
    local cmd = fs._exists_cmd(path)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=result.stdout:find('true') ~= nil}
    end)
end

---@async
---@param path string
---@param exists_ok? boolean
---@return asyncio.Coroutine<aiofsResult<nil>>
function M.create_dir(path, exists_ok)
    local cmd = fs._create_dir_cmd(path, exists_ok)
    return amp_subprocess(cmd, function()
        return {ok=true, result=nil}
    end)
end

---@async
---@param path string
---@param recursive? boolean
---@return asyncio.Coroutine<aiofsResult<nil>>
function M.remove_dir(path, recursive)
    local cmd = fs._remove_dir_cmd(path, recursive)
    return amp_subprocess(cmd, function()
        return {ok=true, result=nil}
    end)
end

---@async
---@param src string
---@param dst string
---@param recursive? boolean
---@return asyncio.Coroutine<aiofsResult<nil>>
function M.copy(src, dst, recursive)
    local cmd = fs._copy_cmd(src, dst, recursive)
    return amp_subprocess(cmd, function()
        return {ok=true, result=nil}
    end)
end

---@async
---@param path string
---@param recursive? boolean
---@return asyncio.Coroutine<aiofsResult<number>>
function M.get_size(path, recursive)
    local cmd = fs._get_size_cmd(path, recursive)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=tonumber(result.stdout:match('%d+'))}
    end)
end

---@async
---@param path string
---@return asyncio.Coroutine<aiofsResult<elxfs.StatResult>>
function M.get_stat(path)
    local cmd = fs._get_stat_cmd(path)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=fs.parse_stat_string(result.stdout)}
    end)
end

M.fs = fs

return M
