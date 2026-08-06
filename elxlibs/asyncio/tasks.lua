local std = require("elxlibs.std")
local class = std.class
local loops = require("elxlibs.asyncio.loops")
local exceptions = require("elxlibs.asyncio.exceptions")
local futures = require("elxlibs.asyncio.futures")

local _scheduled_tasks = {}

local function _register_task(task)
    _scheduled_tasks[task] = true
end

local function _unregister_task(task)
    _scheduled_tasks[task] = nil
end



---@class asyncio.Task : asyncio.Future
---@field _thr thread
---@field _name string
---@field _loop asyncio.EventLoop
---@field _fut_waiter? asyncio.Future
---@field _num_cancels_requested integer
---@field _must_cancel boolean
---@overload fun(func: function, loop: asyncio.EventLoop?, name: string?): asyncio.Task --@loops.EventLoop 
local Task = class.new("asyncio.Task", {futures.Future})

---@param func function
---@param loop asyncio.EventLoop?
---@param name string?
function Task:__init(func, loop, name)
    std.super(Task, self):__init(loop)
    self._thr = coroutine.create(func)
    self._name = name or string.format("Task(%s)", tostring(self._thr))
    self._loop:call_soon(self.__step)
    self._fut_waiter = nil
    self._num_cancels_requested = 0
    self._must_cancel = false
    _register_task(self)
end

---@param name? string
function Task:set_name(name)
    if name == nil then
        self._name = string.format("Task(%s)", tostring(self._thr))
    else
        self._name = name
    end
end

function Task:set_result(...)
    std.raise(std.RuntimeError("Task does not support set_result()"))
end

function Task:set_exception(...)
    std.raise(std.RuntimeError("Task does not support set_exception()"))
end

---@param msg? string
function Task:cancel(msg)
    if self:done() then
        return false
    end
    self._num_cancels_requested = self._num_cancels_requested + 1
    if self._fut_waiter ~= nil then
        self._fut_waiter:cancel(msg)
        return true
    end
    self._must_cancel = true
    self._cancel_msg = msg
    return true
end

function Task:cancelling()
    return self._num_cancels_requested > 0
end

function Task:uncancel()
    if self._num_cancels_requested > 0 then
        self._num_cancels_requested = self._num_cancels_requested - 1
        if self._num_cancels_requested == 0 then
            self._must_cancel = false
        end
    end
    return self._num_cancels_requested
end

---@param exc any?
function Task:__step(exc)
    if self:done() then
        std.raise(exceptions.InvalidStateError("__step(): Task already done"))
    end
    local ok, result
    if exc ~= nil then
        ok, result = coroutine.resume(self._thr, exc)
    else
        ok, result = coroutine.resume(self._thr)
    end
    if not ok then
        if std.isinstance(result, exceptions.CancelledError) then
            self._cancelled_exc = result
            std.super(Task, self):cancel(self._cancel_msg)
        else
            std.super(Task, self):set_exception(result)
        end
        return
    end
    if coroutine.status(self._thr) == "dead" then
        std.super(Task, self):set_result(result)
        _unregister_task(self)
        return
    end
    if result == nil then
        self._loop:call_soon(self.__step)
    else
        if type(result) == "table" and std.isinstance(result, futures.Future) then
            if result._loop ~= self._loop then
                self._loop:call_soon(self.__step, 
                    std.RuntimeError("Task expected a Future in the same loop, got " .. tostring(result)))
            else
                if result == self then
                    self._loop:call_soon(self.__step, 
                        std.RuntimeError("Task cannot wait for itself"))
                else
                    result:add_done_callback(self.__wakeup)
                end
            end
        else
            self._loop:call_soon(self.__step, 
                std.RuntimeError("Task expected a Future, got " .. type(result)))
        end
    end
end

function Task:__wakeup(fut)
    fut:result()
end


---@param func function
---@param loop asyncio.EventLoop?
---@param name string?
local function wrap(func, loop, name)
    return function(...)
        return Task(func, loop, name)
    end
end

---@param func function
---@return function
local function async(func)
    return function(...)
        return wrap(func)(...)
    end
end

---@async
---@param fut asyncio.Future
local function await(fut)
    local rv = coroutine.yield(fut)
    if rv ~= nil then
        if std.isinstance(rv, std.BaseException) then
            std.raise(rv)
        else
            
        end
    end
end


local function create_task(thr, name)
    local loop = loops.get_running_loop()
    return loop:create_task(thr, name)
end


---@class asyncio.tasks
local tasks = {
    async = async,
    await = await,
    create_task = create_task,
    Task = Task,
}

return tasks