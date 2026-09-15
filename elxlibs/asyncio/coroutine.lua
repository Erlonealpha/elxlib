local std = require 'elxlibs.std'
local futures = require 'elxlibs.asyncio.futures'


local type = type
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

---@generic T
---@param coro asyncio.Coroutine<T>
---@return T
local function coro_await(coro)
    local co = coro._coro
    while true do
        local ok, res = coroutine_resume(co)
        if not ok then
            raise(res, 0)
        end
        if coroutine_status(co) == "dead" then
            return res
        end
        if res == nil then
            -- local curr = current_task()
            -- if curr == nil then
            --     raise(std.RuntimeError("The current coroutine is not running within any active event loop."))
            -- else
            --     curr:_schedule()
            -- end
            -- coroutine_yield()
            raise(std.RuntimeError("Cannot yield nil from coroutine, use asyncio.sleep(0)."))
        elseif std.isinstance(res, futures.Future) then
            local err = coroutine_yield(res)
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
---@return_overload T
---@return_overload nil, any
local function coro_try_await(coro)
    local co = coro._coro
    while true do
        local ok, res = coroutine_resume(co)
        if not ok then
            return nil, res
        end
        if coroutine_status(co) == "dead" then
            return res
        end
        if res == nil then
            -- local curr = current_task()
            -- if curr == nil then
            --     raise(std.RuntimeError("The current coroutine is not running within any active event loop."))
            -- else
            --     curr:_schedule()
            -- end
            -- coroutine_yield()
            raise(std.RuntimeError("Cannot yield nil from coroutine, use asyncio.sleep(0)."))
        elseif std.isinstance(res, futures.Future) then
            local err = coroutine_yield(res)
            if err then
                return nil, err
            end
        else
            raise(std.RuntimeError("Unexpected yield from coroutine: " .. tostring(res)))
        end
    end
end

return {
    Coroutine = Coroutine,
    coro_await = coro_await,
    coro_try_await = coro_try_await
}
