---@meta
---@namespace asyncio

---@generic T
---@interface Awaitable<T> : std.object
---@field __await async fun(s: self):T...
---@field __try_await async fun(s: self):true, T...
---@field __try_await async fun(s: self):false, any
