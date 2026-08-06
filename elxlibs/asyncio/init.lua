---@author Erlone
-- This module provides an interface for working with coroutines in Lua.
-- It provides a way to create and manage coroutines, as well as a way to schedule

---@class asyncio
local M = {}

---@module 'std'
local std = require('elxlibs.std')
local class = std.class

local futures = require('elxlibs.asyncio.futures')
local tasks =   require('elxlibs.asyncio.tasks')

M.async = tasks.async
M.await = tasks.await
M.create_task = tasks.create_task

function M.run(fn)
end

function M.sleep(t)
    
end

function M.mp_event(name, cb)
    
end

return M