---@namespace asyncio

local std = require 'elxlibs.std'
local asyncio = require 'elxlibs.asyncio'
local coroutines = require 'elxlibs.asyncio.coroutine'
local await = asyncio.await
local raise = std.raise
local M = {}

---@async
---@param func_or_awaitable thread | function | Future<any> | Coroutine<any>
---@param enter fun(task:Task<any>)
---@param exit fun(exc:any)
---@param funcname string
---@param prepare? async fun() Acquire resources before scheduling a new body.
function M.with(func_or_awaitable, enter, exit, funcname, prepare)
return asyncio.async(function()
    local is_task = std.isinstance(func_or_awaitable, asyncio.tasks.Task)
    local typ = type(func_or_awaitable)
    if not std.isinstance(func_or_awaitable, asyncio.futures.Future) and
        typ ~= 'function' and typ ~= 'thread' and
        not std.isinstance(func_or_awaitable, coroutines.Coroutine) then
        raise(std.ValueError(string.format('%s got invalid type', funcname)))
    end
    if prepare then prepare() end
    local entered = prepare ~= nil
    local start
    local res = table.pack(pcall(function()
        ---@type Task<any>
        local task
        if is_task then
            ---@cast func_or_awaitable Task<any>
            task = func_or_awaitable
        else
            -- Task checks this gate before resuming the original body. Keep
            -- raw thread and Coroutine scheduling identical to create_task.
            start = asyncio.loops.get_running_loop():create_future()
            if std.isinstance(func_or_awaitable, asyncio.futures.Future) then
                ---@cast func_or_awaitable Future<any>
                task = asyncio.create_task(function() return await(func_or_awaitable) end)
            else
                task = asyncio.create_task(func_or_awaitable)
            end
            task._start_gate = start
        end
        -- EmmyLua treats inferred Task<unknown> as incompatible with Task<any>.
        ---@diagnostic disable-next-line: param-type-mismatch
        enter(task)
        entered = true
        if start then start:set_result() end
        return await(task)
    end))
    local ok = res[1]
    local err
    if not ok then err = res[2] end
    if not ok and start and not start:done() then start:cancel() end
    if entered then exit(err) end
    if not ok then raise(err, 0) end
    ---@diagnostic disable-next-line: redundant-return-value
    return table.unpack(res, 2, res.n)
end)
end

return M
