

---@class std.exception : std._exception
local M = {}

local type = type
local error = error
local debug = debug
local table = table
local pairs = pairs
local xpcall = xpcall
local string = string
local tostring = tostring

-- following will setup later by exception_exception_init.lua
-- M.new_exception = nil
-- M.BaseException = nil
-- M.Exception = nil
-- M.RuntimeError = nil
-- M.TypeError = nil
-- M.ValueError = nil
-- M.IndexError = nil
-- M.KeyError = nil
-- M.AttributeError = nil
-- M.NotImplementedError = nil
-- M.AssertionError = nil
-- M.EOFError = nil
-- M.IOError = nil
-- M.OSError = nil
-- M.ImportError = nil
-- M.MemoryError = nil
-- M.TimeoutError = nil

---@param err any
---@param level int?
---@not_return
---@return void
function M.raise(err, level)
    if level ~= nil then
        if level ~= 0 then
            level = level + 1
        end
    else
        level = 2
    end
    local typ = type(err)
    if typ == "table" and err.__is_std_exception then
        if err.__traceback ~= nil then
            err.__traceback = debug.traceback(err.__traceback, level)
        else
            err.__traceback = debug.traceback('', level)
        end
        if level == 0 then
            error(tostring(err), level)
        else
            error(err, level)
        end
    elseif typ ~= "string" then
        err = tostring(err)
    end
    error(err, level)
end

function M.traceback(err)
    if err and err:find("stack traceback:") then
        return err
    end
    local result = ""
    if err then
        result = result.. err.. "\n"
    end
    result = result.. "stack traceback:\n"
    local level = 2
    while true do
        local info = debug.getinfo(level, "Sln")

        if not info or (info.name and (info.name == "xpcall" or info.name == "pcall")) then
            break
        end

        if info.what == "C" then
            result = result .. string.format("    [C]: in function '%s'\n", info.name)
        elseif info.name then
            result = result .. string.format("    [%s:%d]: in function '%s'\n", info.short_src, info.currentline, info.name)
        elseif info.what == "main" then
            result = result .. string.format("    [%s:%d]: in main chunk\n", info.short_src, info.currentline)
            break
        else
            result = result .. string.format("    [%s:%d]:\n", info.short_src, info.currentline)
        end
        level = level + 1
    end
    return result
end

function M.trycall(fn, traceback, ...)
    return xpcall(fn, function (errors)
        traceback = traceback or debug.traceback
        return traceback(errors)
    end, ...)
end


-- ---@alias block_main<T...> {[1]: fun(...:any):T...}
-- ---@alias block_catch<T..., N> {[N]: {catch:fun(err:T):any}}
-- ---@alias block_finally<T..., N> {finally:fun(ok:boolean, result:T):any}
-- ---@generic T1, T2, T3
-- ---@param block block_main<T1>&block_catch<T2, 2>&block_finally<T3, 3>
-- ---@overload fun(block: block_main<T1>&block_catch<T2, 2>)
-- ---@overload fun(block: block_main<T1>&block_finally<T3, 2>)

--[[
try{
    function () end,
    catch{
        function (err) end,
    },
    finally{ 
        function (ok, err_or_result) end
    }
}
]]
---@generic T1, T2, T3
---@param block {
--- [1]:  fun(...:any),
--- [2]?: {catch:fun(err:T2):any},
--- [3]?: {finally:fun(ok:boolean, result:T3):any}|any,
---}
function M.try(block)
    ---@type fun(...:any):T1...
    local try = block[1]
    ---@type { catch: fun(err)?, finally: fun(ok:boolean, result:any)? }
    local fnmap = {}
    for i = 2, #block do
        for k, v in pairs(block[i]) do
            fnmap[k] = v
        end
    end
    local catch = fnmap.catch
    local finally = fnmap.finally
    local results = table.pack(xpcall(try, debug.traceback))
    local ok = results[1]
    if not ok and catch then
        xpcall(function()
            return catch(results[2])
        end, debug.traceback)
    end
    if finally then
        finally(ok, table.unpack(results, 2, results.n))
    end
    if not ok and not catch then
        M.raise(results[2], 2)
    elseif ok then
        return table.unpack(results, 2, results.n)
    end
end

---@param block { [1]: fun(err:any) }
---@return {catch: fun(err:any)}
function M.catch(block)
    return {catch = block[1]}
end

---@param block { [1]: fun(ok:boolean, result:any) }
---@return {finally: fun(ok:boolean, result:any)}
function M.finally(block)
    return {finally = block[1]}
end

return M