local asyncio = require("elxlibs.asyncio")
local amp = require('elxlibs.asyncio.mp')
local fs = require("elxlibs.fs")


---@class aiofs
local M = {version = "0.1.0"}

---@alias aiofsResult<T> { ok: boolean, result: T?, error: string? }

---@generic T
---@param args string[]
---@param get_result fun(result: table):aiofsResult<T>
---@return asyncio.Future<aiofsResult<T>>
local function amp_subprocess(args, get_result)
    ---@type asyncio.Future<aiofsResult<T>>
    local fut = asyncio.loops.get_running_loop():create_future()

    amp.command_native_async({
        name = 'subprocess',
        args = args,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, result, error)
        if not success or result == nil or result.status ~= 0 then
            fut:set_result({ok=false, error=error})
            return
        end
        fut:set_result(get_result(result))
        return
    end)

    return fut
end

---@async
---@param path string
---@return asyncio.Future<aiofsResult<boolean>>
function M.exists(path)
    local cmd = fs._exists_cmd(path)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=result.stdout:find('true') ~= nil}
    end)
end

---@async
---@param path string
---@param exists_ok boolean
---@return asyncio.Future<aiofsResult<nil>>
function M.create_dir(path, exists_ok)
    local cmd = fs._create_dir_cmd(path, exists_ok)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=nil}
    end)
end

---@async
---@param path string
---@param recursive boolean
---@return asyncio.Future<aiofsResult<nil>>
function M.remove_dir(path, recursive)
    local cmd = fs._remove_dir_cmd(path, recursive)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=nil}
    end)
end

---@async
---@param src string
---@param dst string
---@param recursive boolean
---@return asyncio.Future<aiofsResult<nil>>
function M.copy(src, dst, recursive)
    local cmd = fs._copy_cmd(src, dst, recursive)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=nil}
    end)
end

---@async
---@param path string
---@param recursive boolean
---@return asyncio.Future<aiofsResult<number>>
function M.get_size(path, recursive)
    local cmd = fs._get_size_cmd(path, recursive)
    return amp_subprocess(cmd, function(result)
        return {ok=true, result=tonumber(result.stdout:match('%d+'))}
    end)
end

M.fs = fs

return M