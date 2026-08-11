---@class std.exception
---@field new_exception fun(...:any):any
---@field BaseException std.BaseException
---@field Exception std.Exception
---@field RuntimeError std.RuntimeError
---@field TypeError std.TypeError
---@field ValueError std.ValueError
---@field IndexError std.IndexError
---@field KeyError std.KeyError
---@field AttributeError std.AttributeError
---@field NotImplementedError std.NotImplementedError
---@field AssertionError std.AssertionError
---@field EOFError std.EOFError
---@field IOError std.IOError
---@field OSError std.OSError
---@field ImportError std.ImportError
---@field MemoryError std.MemoryError
---@field TimeoutError std.TimeoutError
local M = {}

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

function M.raise(err)
    error(tostring(err))
end

function M.traceback(error)
    if error and error:find("stack traceback:") then
        return error
    end
    local result = ""
    if error then
        result = result.. error.. "\n"
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
---@return ...|T1
function M.try(block)
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
    local results = table.pack(M.trycall(try))
    local ok = results[1]
    if not ok then
        if catch then
            catch(results[2])
        end
    end
    if finally then
        finally(ok, table.unpack(results, 2, #results))
    end
    if not ok and not catch then
        M.raise(results[2])
    elseif ok then
        return table.unpack(results, 2, #results)
    end
end

---@param block { [1]: fun():{catch:function} }
function M.catch(block)
    return {catch = block[1]}
end

---@param block { [1]: fun(ok:boolean, result:any) }
function M.finally(block)
    return {finally = block[1]}
end

return M