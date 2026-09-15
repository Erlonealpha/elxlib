---@meta

---@generic T
---@interface asyncio.Awaitable<T> : std.object
---@field __await async fun(s: self):T
---@field __try_await async fun(s: self):nil, any
---@field __try_await async fun(s: self):T
