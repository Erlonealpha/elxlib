local std = require("elxlibs.std")
local class = std.class
local exceptions = require("elxlibs.asyncio.exceptions")
local futures = require("elxlibs.asyncio.futures")
local loops = require("elxlibs.asyncio.loops")


local _scheduled_tasks = {}

local function _register_task(task)
    _scheduled_tasks[task] = true
end

local function _unregister_task(task)
    _scheduled_tasks[task] = nil
end


---@generic T
---@class asyncio.Task<T> : asyncio.Future<T>
---@field _thr thread
---@field _name string
---@field _loop asyncio.EventLoop
---@field _fut_waiter? asyncio.Future<T>
---@field _num_cancels_requested integer
---@field _must_cancel boolean
---@overload fun(func: function|thread, loop: asyncio.EventLoop?, name: string?): asyncio.Task<T> --@loops.EventLoop 
local Task = class.new("asyncio.Task", {futures.Future}, {__tostring = function(self)
    return self._name
end})

---@param func function|thread
---@param loop asyncio.EventLoop?
---@param name string?
function Task:__init(func, loop, name)
    debug_msg('Task:__init', loop, name)
    std.super(Task, self):__init(loop)
    local typ = type(func)
    if typ == "function" then
        self._thr = self._wrap(func)
    elseif typ == "thread" then
        self._thr = func
    else
        error('Task func expected function type or thread type, got ' .. typ)
    end
    self._name = name or string.format("Task-(%s)", tostring(self._thr))
    self._loop:call_soon(self.__step, {self})
    self._fut_waiter = nil
    self._num_cancels_requested = 0
    self._must_cancel = false
    _register_task(self)
end

---@param func function
---@param args any[]?
function Task._wrap(func, args)
    return coroutine.create(function(fut, exc)
        if exc ~= nil then
            error(exc)
        end
        if args and #args > 0 then
            return func(table.unpack(args))
        else
            return func(fut)
        end
    end)
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
    if self._must_cancel then
        if not std.isinstance(exc, exceptions.CancelledError) then
            exc = exceptions.CancelledError()
        end
        self._must_cancel = false
    end

    local ok, result
    if exc ~= nil then
        debug_msg('Task:__step', self._name, 'resume with exc', exc)
        ok, result = coroutine.resume(self._thr, exc)
    else
        ok, result = coroutine.resume(self._thr)
    end

    debug_msg('Task:__step', self._name, ok, result)
    if not ok then
        if type(result) == "table" and std.isinstance(result, exceptions.CancelledError) then
            debug_msg('Task:__step', self._name, 'CancelledError')
            self._cancelled_exc = result
            std.super(Task, self):cancel(self._cancel_msg)
        else
            debug_msg('Task:__step', self._name, 'recv exc', result)
            std.super(Task, self):set_exception(result)
        end
        return
    end

    if coroutine.status(self._thr) == "dead" then
        debug_msg(self._name, 'dead')
        std.super(Task, self):set_result(result)
        _unregister_task(self)
        return
    end

    if result == nil then
        debug_msg('Task:__step yield empty', self._name)
        self._loop:call_soon(self.__step, {self})
    else
        if type(result) == "table" and std.isinstance(result, futures.Future) then
            if result._loop ~= self._loop then
                self._loop:call_soon(
                    self.__step, 
                    {self, std.RuntimeError("Task expected a Future in the same loop, got " .. tostring(result))})
                debug_msg('Task:__step not same loop', self._name)
            else
                if result == self then
                    debug_msg('Task:__step cannot wait for itself', self._name)
                    self._loop:call_soon(self.__step, 
                        {self, std.RuntimeError("Task cannot wait for itself")})
                else
                    debug_msg('Task:__step', self._name, 'yield future', result)
                    result:add_done_callback(function(fut)
                        self:__wakeup(fut)
                    end)
                end
            end
        else
            debug_msg('Task:__step got wrong Future', self._name)
            self._loop:call_soon(self.__step, 
                {self, std.RuntimeError("Task expected a Future, got " .. type(result))})
        end
    end
end

---@param fut asyncio.Future<T>
function Task:__wakeup(fut)
    debug_msg('Task:__wakeup', self._name, fut)
    if fut:done() then
        self._fut_waiter = nil
    end
    self._loop:call_soon(self.__step, {self})
end


---@generic T
---@param func function
---@param loop asyncio.EventLoop?
---@param name string?
---@return fun():asyncio.Task<T>
local function wrap(func, loop, name)
    return function(...)
        return Task(Task._wrap(func, {...}), loop, name)
    end
end


---@generic T
---@param func fun():T
---@param name string?
---@return asyncio.Task<T>
local function async(func, name)
    debug_msg('async create', name)
    return Task(Task._wrap(func), nil, name)
end

---@async
---@generic T
---@overload fun(fut: asyncio.Future<T>): T
---@overload fun(fut: nil): nil, any?
local function await(fut)
    if fut == nil then
        local err = coroutine.yield()
        if err then
            std.raise(err)
        end
        return
    end
    return fut:__await()
end

---@async
---@generic T
---@overload fun(fut: asyncio.Future<T>): T
---@overload fun(fut: nil): nil, any?
local function try_await(fut)
    if fut == nil then
        local err = coroutine.yield()
        return nil, err
    end
    return fut:__try_await()
end

---@param func function
---@param name? string
local function create_task(func, name)
    local loop = loops.get_running_loop()
    return loop:create_task(func, name)
end


---@class asyncio.tasks
local tasks = {
    wrap = wrap,
    async = async,
    await = await,
    try_await = try_await,
    create_task = create_task,
    Task = Task,
}

return tasks