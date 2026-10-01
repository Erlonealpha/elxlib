local std = require 'elxlibs.std'
local locks = require 'elxlibs.asyncio.locks'
local asyncio = require 'elxlibs.asyncio'


local async = asyncio.async
local await = asyncio.await
local try_await = asyncio.try_await
local raise = std.raise

local function table_remove(tbl, item)
    for i, it in ipairs(tbl) do
        if it == item then
            table.remove(tbl, i)
            break
        end
    end
end

---@class asyncio.QueueFull : std.Exception
---@overload fun(message:string?):self
local QueueFull = std.exception.new_exception('asyncio.QueueFull', std.Exception)

---@class asyncio.QueueEmpty : std.Exception
---@overload fun(message:string?):self
local QueueEmpty = std.exception.new_exception('asyncio.QueueEmpty', std.Exception)

---@class asyncio.Queue<T = any> : std.object
---@field _queue T[]
---@overload fun(maxsize:int?):self
local Queue = std.class.new('asyncio.Queue')
---@param maxsize int?
function Queue:__init(maxsize)
    self.maxsize = maxsize or 0
    self._queue = {}
    self._getters = {}
    self._putters = {}
    self._unfinished_tasks = 0
    self._finished = locks.Event()
    self._finished:set()
end

---@param waiters asyncio.Future<nil>[]
function Queue:_wakeup_next(waiters)
    while #waiters > 0 do
        local w = table.remove(waiters, 1)
        if not w:done() then
            w:set_result()
            break
        end
    end
end

---@param item T
function Queue:_put(item)
    table.insert(self._queue, item)
end

---@return T
function Queue:_get()
    return table.remove(self._queue, 1)
end

function Queue:__len()
    return #self._queue
end

---@return boolean
function Queue:empty()
    return #self._queue == 0
end

---@return boolean
function Queue:full()
    if self.maxsize <= 0 then
        return false
    else
        return #self._queue >= self.maxsize
    end
end

---@async
---@param item T
function Queue:put(item)
return async(function()
    while self:full() do
        local fut = asyncio.loops.get_running_loop():create_future()
        table.insert(self._putters, fut)
        local ok, err = try_await(fut)
        if not ok then
            table_remove(self._putters, fut)
            if not self:full() and not fut:cancelled() then
                self:_wakeup_next(self._putters)
            end
            raise(err, 0)
        end
    end
    self:put_nowait(item)
end)
end

---@param item T
function Queue:put_nowait(item)
    if self:full() then
        raise(QueueFull(), 1)
    end
    self:_put(item)
    self._unfinished_tasks = self._unfinished_tasks + 1
    self._finished:clear()
    self:_wakeup_next(self._getters)
end

---@async
---@return asyncio.Coroutine<T>
function Queue:get()
return async(function()
    while self:empty() do
        local fut = asyncio.loops.get_running_loop():create_future()
        table.insert(self._getters, fut)
        local ok, err = try_await(fut)
        if not ok then
            table_remove(self._getters, fut)
            if not self:empty() and not fut:cancelled() then
                self:_wakeup_next(self._getters)
            end
            raise(err, 0)
        end
    end
    return self:get_nowait()
end)
end

---@return T
function Queue:get_nowait()
    if self:empty() then
        raise(QueueEmpty(), 1)
    end
    local item = self:_get()
    self:_wakeup_next(self._putters)
    return item
end

function Queue:task_done()
    if self._unfinished_tasks <= 0 then
        raise(std.ValueError('task_done() called too many times'))
    end
    self._unfinished_tasks = self._unfinished_tasks - 1
    if self._unfinished_tasks == 0 then
        self._finished:set()
    end
end

---@async
function Queue:join()
return async(function()
    if self._unfinished_tasks > 0 then
        await(self._finished:wait())
    end
end)
end

---@class asyncio.LifoQueue : asyncio.Queue
---@overload fun(maxsize:int?):self
local LifoQueue = std.class.new('asyncio.LifoQueue', {Queue})
function LifoQueue:_get()
    return table.remove(self._queue)
end

return {
    Queue = Queue,
    LifoQueue = LifoQueue,
}
