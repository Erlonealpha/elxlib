---@author Erlone
-- This module provides an interface for working with coroutines in Lua.
-- It provides a way to create and manage coroutines, as well as a way to schedule

---@class asyncio
local M = {}

local futures = require('elxlibs.asyncio.futures')
local tasks = require('elxlibs.asyncio.tasks')
local loops = require('elxlibs.asyncio.loops')


---@generic T
---@param fn fun():T
---@param loop asyncio.EventLoop?
---@param name string?
---@return T
function M.run(fn, loop, name)
    loop = loop or loops.get_event_loop()
    return loop:run_until_complete(loop:create_task(fn, name))
end

M.async = tasks.async
M.await = tasks.await
M.try_await = tasks.try_await
M.current_task = tasks.current_task
M.create_task = tasks.create_task
M.sleep = tasks.sleep
M.wait = tasks.wait
M.wait_for = tasks.wait_for
M.gather = tasks.gather
M.shield = tasks.shield
M.futures = futures
M.tasks = tasks
M.loops = loops

return M
