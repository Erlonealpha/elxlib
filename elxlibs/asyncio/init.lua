---@author Erlone
-- This module provides an interface for working with coroutines in Lua.
-- It provides a way to create and manage coroutines, as well as a way to schedule

---@class asyncio
local M = {}

local futures = require('elxlibs.asyncio.futures')
local tasks = require('elxlibs.asyncio.tasks')
local loops = require('elxlibs.asyncio.loops')


function M.run(fn)
    local loop = loops.get_running_loop()
    loop:run_until_complete(loop:create_task(fn))
end

function M.sleep(t)

end

function M.mp_event(name, cb)

end

M.async = tasks.async
M.await = tasks.await
M.create_task = tasks.create_task
M.futures = futures
M.tasks = tasks
M.loops = loops

return M