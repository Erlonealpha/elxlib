local std = require 'elxlibs.std'
local futures = require 'elxlibs.asyncio.futures'
local exc = require 'elxlibs.asyncio.exceptions'


local type = type
local pack = table.pack
local unpack = table.unpack
local raise = std.raise
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield
local coroutine_status = coroutine.status

---@generic T
---@class asyncio.Coroutine<T> : asyncio.Awaitable<T>
---@field _coro thread
---@overload fun(func: fun(...):T):self
local Coroutine = std.class.new("asyncio.Coroutine")

---@param func fun(...):T
function Coroutine:__init(func)
    local typ = type(func)
    if typ ~= "function" then
        raise(std.ValueError("Coroutine func expected function type, got " .. typ))
    end
    self._coro = coroutine_create(func)
end

function Coroutine:__await()
    raise('cannot call coroutine.__await, use asyncio.await(coro)')
end

function Coroutine:__try_await()
    raise('cannot call coroutine.__try_await, use asyncio.try_await(coro)')
end

local co_empty = setmetatable({}, {
    __tostring = function ()
        return 'co_empty'
    end
})
local co_skip = setmetatable({}, {
    __tostring = function ()
        return 'co_skip'
    end
})

---@generic T
---@param coro asyncio.Coroutine<T>
---@return T
local function coro_await(coro)
    local co = coro._coro
    while true do
        local res = pack(coroutine_resume(co))
        local ok = res[1]
        local arg2 = res[2]
        if not ok then
            local err = exc.collect_thread_error(co, arg2)
            raise(err, 0)
        end
        if coroutine_status(co) == "dead" then
            return unpack(res, 2, res.n)
        end
        if arg2 == nil then
            -- local curr = current_task()
            -- if curr == nil then
            --     raise(std.RuntimeError("The current coroutine is not running within any active event loop."))
            -- else
            --     curr:_schedule()
            -- end
            -- coroutine_yield()
            raise(std.RuntimeError("Cannot yield nil from coroutine, use asyncio.sleep(0)."))
        elseif arg2 == co_empty then
            coroutine_yield(co_skip)
        elseif arg2 == co_skip then
            -- pass
        elseif std.isinstance(arg2, futures.Future) then
            local err = coroutine_yield(arg2)
            if err then
                raise(err, 0)
            end
        else
            raise(std.RuntimeError("Unexpected yield from coroutine: " .. tostring(res)))
        end
    end
end

---@generic T
---@param coro asyncio.Coroutine<T>
---@return_overload false, any
---@return_overload true, T...
local function coro_try_await(coro)
    local co = coro._coro
    while true do
        local res = pack(coroutine_resume(co))
        local ok = res[1]
        local arg2 = res[2]
        if not ok then
            local err = exc.collect_thread_error(co, arg2)
            return false, err
        end
        if coroutine_status(co) == "dead" then
            return true, unpack(res, 2, res.n)
        end
        if arg2 == nil then
            -- local curr = current_task()
            -- if curr == nil then
            --     raise(std.RuntimeError("The current coroutine is not running within any active event loop."))
            -- else
            --     curr:_schedule()
            -- end
            -- coroutine_yield()
            raise(std.RuntimeError("Cannot yield nil from coroutine, use asyncio.sleep(0)."))
        elseif arg2 == co_empty then
            coroutine_yield(co_skip)
        elseif arg2 == co_skip then
            -- pass
        elseif std.isinstance(arg2, futures.Future) then
            local err = coroutine_yield(arg2)
            if err then
                return false, err
            end
        else
            raise(std.RuntimeError("Unexpected yield from coroutine: " .. tostring(res)))
        end
    end
end

return {
    Coroutine = Coroutine,
    coro_await = coro_await,
    coro_try_await = coro_try_await,
    co_empty = co_empty,
    co_skip = co_skip,
}
