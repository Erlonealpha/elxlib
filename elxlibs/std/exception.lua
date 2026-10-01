

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

---@generic E = any, L = int
---@param err any
---@param level L?
---@param raise boolean?
---@return E, L, boolean
local function _traceback(err, level, raise)
    local typ = type(err)
    if typ == 'table' and err.__is_std_exception then
        if err.__traceback == nil and raise then
            err.__traceback = debug.traceback('', level)
        end
        return err, 0, true
    elseif typ ~= 'string' then
        err = tostring(err)
    end
    return err, level, false
end

--- `level` has the same meaning as in `error()`: it counts the frames above the
--- caller of `raise` that should be blamed for the error (0 = do not add any
--- position information).
--- NOTE: `_traceback` runs one frame deeper than `raise`, so the level that is
--- used to capture `__traceback` needs an extra +1 (keep the two apart!).
---@param err any
---@param level int?
---@param from any? 异常链的起因（异常对象或字符串描述）
---@not_return
---@return void
function M.raise(err, level, from)
    local err_level
    if level == nil then
        err_level = 2
    elseif level == 0 then
        err_level = 0
    else
        err_level = level + 1
    end
    local tb_level = (err_level == 0) and 0 or (err_level + 1)
    local _, is_exc
    err, _, is_exc = _traceback(err, tb_level, true)
    if from then
        if is_exc then
            err.__cause = from
        else
            local from_level
            from, from_level, is_exc = _traceback(from, nil, false)
            if is_exc then
                from = tostring(from)
            end
            err = from .. '\nThe above exception was the direct cause of the following exception:\n' .. err
        end
    end
    error(err, err_level)
end

---@generic T
---@param fn fun():T...
---@param err_handler? fun(err:any, level:int?):any
---@param level int?
---@return_overload true, T...
---@return_overload false, any
function M.xpcall(fn, err_handler, level)
    if level ~= nil then
        ---@diagnostic disable-next-line: return-type-mismatch
        return xpcall(fn, function(err)
            return (err_handler or M.traceback)(err, level + 1)
        end)
    end
    -- EmmyluaBUG  `(true|false)` => `boolean` EmmyLua(return-type-mismatch)
    ---@diagnostic disable-next-line: return-type-mismatch
    return xpcall(fn, err_handler or M.traceback)
end

M.pcall = pcall

--- @overload fun(): string
--- @overload fun(err?: string, level?: integer): string
--- @param thread?  thread
--- @param err? any
--- @param level? integer
--- @return string
function M.traceback(thread, err, level)
    if type(thread) ~= 'thread' then
        -- called as traceback(err[, level]); keep `thread` nil but do NOT
        -- overwrite `err` (it still holds the message/exception here)
        level = err
        err = thread
        thread = nil
    end

    level = level or 2

    if err ~= nil then
        local _, is_exc
        _, _, is_exc = _traceback(err, level + 1, true)
        if is_exc then
            return tostring(err)
        elseif err:find("stack traceback:") then
            return err
        end
    end

    local result = ""
    if err then
        result = result.. err.. "\n"
    end
    result = result.. "stack traceback:\n"
    while true do
        local info
        if thread ~= nil then
            info = debug.getinfo(thread, level, "Sln")
        else
            info = debug.getinfo(level, "Sln")
        end

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

function M.traceback1(err)
    return M.traceback(err, 2)
end

function M.traceback2(err)
    return M.traceback(err, 3)
end

function M.traceback3(err)
    return M.traceback(err, 4)
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
    local results = table.pack(M.xpcall(try))
    local ok = results[1]
    if not ok and catch then
        M.xpcall(function()
            return catch(results[2])
        end, nil, 2)
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
