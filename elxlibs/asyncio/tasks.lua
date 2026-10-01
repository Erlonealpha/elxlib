local std = require("elxlibs.std")
local class = std.class
local exceptions = require("elxlibs.asyncio.exceptions")
local coroutines = require("elxlibs.asyncio.coroutine")
local futures = require("elxlibs.asyncio.futures")
local loops = require("elxlibs.asyncio.loops")

local timeouts
local function get_timeouts()
    -- EmmyluaBUG for `timeouts = require(...)` timeouts => `nerver?`
    local t = require("elxlibs.asyncio.timeouts")
    timeouts = t
    return t
end


local type = type
local table = table
local string = string
local pack = table.pack
local xpcall = std.xpcall
local tostring = tostring
local unpack = table.unpack
local setmetatable  = setmetatable
local traceback = std.traceback

local raise = std.raise

local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status


local _scheduled_tasks = setmetatable({}, {__mode = 'k'})
local _current_tasks = {}

local function _register_task(task)
    _scheduled_tasks[task] = true
end

local function _unregister_task(task)
    _scheduled_tasks[task] = nil
end

local function _enter_task(loop, task)
    if _current_tasks[loop] ~= nil then
        raise(std.RuntimeError(
            string.format("Cannot enter into task %s while another task %s is being executed.",
            task, _current_tasks[loop])))
    else
        _current_tasks[loop] = task
    end
end

local function _leave_task(loop, task)
    if _current_tasks[loop] ~= task then
        raise(std.RuntimeError(
            string.format("Leaving task %s does not match the current task %s.",
            task, _current_tasks[loop])))
    else
        _current_tasks[loop] = nil
    end
end

---@param loop? asyncio.EventLoop
---@return asyncio.Task<any>?
local function current_task(loop)
    if loop == nil then
        loop = loops.get_running_loop()
    end
    return _current_tasks[loop]
end

---@generic T
---@class asyncio.Task<T> : asyncio.Future<T>
---@field _thr thread
---@field _name string
---@field _loop asyncio.EventLoop
---@field _fut_waiter? asyncio.Future<T>
---@field _num_cancels_requested integer
---@field _must_cancel boolean
---@overload fun(coro: (async fun():T)|thread|asyncio.Coroutine<T>, loop: asyncio.EventLoop?, name: string?): asyncio.Task<T> --@loops.EventLoop 
local Task = class.new("asyncio.Task", {futures.Future}, {__tostring = function(self)
    return self._name
end})

---@param coro async fun():T|thread|asyncio.Coroutine<T>
---@param loop asyncio.EventLoop?
---@param name string?
function Task:__init(coro, loop, name)
    -- debug_msg('Task:__init', loop, name)
    std.super(Task, self, futures.Future):__init(loop)
    local typ = type(coro)
    if typ == "function" then
        self._thr = coroutine_create(coro)
    elseif typ == "thread" then
        self._thr = coro
    elseif std.isinstance(coro, coroutines.Coroutine) then
        self._thr = coro._coro
    else
        raise(std.ValueError('Task coro expected function, thread or Coroutine type, got ' .. typ))
    end
    self._error_destroy_pending = true
    self._name = name or string.format("Task-(%s)", tostring(self._thr))
    self._loop:call_soon(self.__step, {self})
    self._fut_waiter = nil
    self._num_cancels_requested = 0
    self._must_cancel = false
    self._started = false
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
    raise(std.RuntimeError("Task does not support set_result()"))
end

function Task:set_exception(...)
    raise(std.RuntimeError("Task does not support set_exception()"))
end

---@param msg? string
function Task:cancel(msg)
    if self:done() then
        return false
    end
    self._num_cancels_requested = self._num_cancels_requested + 1
    if self._fut_waiter ~= nil then
        if self._fut_waiter:cancel(msg) then
            return true
        end
    end
    self._must_cancel = true
    self._cancel_msg = msg
    return true
end

---@return integer 未完成（pending）的取消请求数量，语义同 CPython 的 Task.cancelling()
function Task:cancelling()
    return self._num_cancels_requested
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
        raise(exceptions.InvalidStateError("Task:__step() Task already done"))
    end
    -- A coroutine that has not started yet cannot receive an exception through
    -- coroutine.resume(co, exc): a value passed to the first resume becomes the
    -- coroutine body's argument and is dropped for a zero-argument body. So a
    -- cancel requested before the first step must be delivered at the first
    -- suspension point instead (see below).
    local first_step = not self._started
    self._started = true
    if self._must_cancel and not first_step and coroutine_status(self._thr) ~= "dead" then
        if not std.isinstance(exc, exceptions.CancelledError) then
            exc = self:_make_cancelled_error()
        end
        self._must_cancel = false
    end
    self._fut_waiter = nil

    _enter_task(self._loop, self)
    local _ok, _err = xpcall(function()
        local res
        if exc ~= nil then
            -- debug_msg('Task:__step', self._name, 'resume with exc', exc)
            res = pack(coroutine_resume(self._thr, exc))
        else
            res = pack(coroutine_resume(self._thr))
        end
        local ok = res[1]
        local arg1 = res[2]

        -- debug_msg('Task:__step', self._name, ok, arg1)
        if not ok then
            if std.isinstance(arg1, exceptions.CancelledError) then
                -- debug_msg('Task:__step', self._name, 'CancelledError')
                self._cancelled_exc = arg1
                std.super(Task, self, futures.Future):cancel(self._cancel_msg)
            else
                local err
                if arg1.__is_std_exception then
                    if arg1.__traceback == nil then
                        arg1.__traceback = traceback(self._thr, tostring(arg1), 0)
                    end
                    err = arg1
                else
                    if type(arg1) ~= "string" then
                        arg1 = tostring(arg1)
                    end
                    if not arg1:find('stack traceback') then
                        err = traceback(self._thr, arg1, 0)
                    else
                        err = arg1
                    end
                end
                -- debug_msg('Task:__step', self._name, 'recv err:', err)
                std.super(Task, self, futures.Future):set_exception(err)
            end
            _unregister_task(self)
            return
        end

        if self._must_cancel then
            if coroutine_status(self._thr) == "dead" then
                -- finished without ever awaiting: cancel the task outright
                self._must_cancel = false
                self._cancelled_exc = self:_make_cancelled_error()
                std.super(Task, self, futures.Future):cancel(self._cancel_msg)
                _unregister_task(self)
                return
            elseif std.isinstance(arg1, futures.Future) then
                -- cancellation requested before the first resume: hand it to the
                -- future the coroutine just suspended on, so it is delivered as
                -- a CancelledError at that await point
                if arg1:cancel(self._cancel_msg) then
                    self._must_cancel = false
                end
            end
            -- else: still suspended without a future, keep _must_cancel set so
            -- that it is delivered at the next suspension point
        end

        if coroutine_status(self._thr) == "dead" then
            -- debug_msg(self._name, 'dead')
            std.super(Task, self):set_result(unpack(res, 2, res.n))
            _unregister_task(self)
            return
        end

        if arg1 == nil or arg1 == coroutines.co_empty or arg1 == coroutines.co_skip then
            -- debug_msg('Task:__step yield empty', self._name)
            self._loop:call_soon(self.__step, {self})
        else
            if std.isinstance(arg1, futures.Future) then
                if arg1._loop ~= self._loop then
                    self._loop:call_soon(
                        self.__step, 
                        {self, std.RuntimeError("Task expected a Future in the same loop, got " .. tostring(arg1))})
                    -- debug_msg('Task:__step not same loop', self._name)
                else
                    if arg1 == self then
                        -- debug_msg('Task:__step cannot wait for itself', self._name)
                        self._loop:call_soon(self.__step, 
                            {self, std.RuntimeError("Task cannot wait for itself")})
                    else
                        -- debug_msg('Task:__step', self._name, 'yield future', arg1)
                        self._fut_waiter = arg1
                        arg1:add_done_callback(function(fut)
                            self:__wakeup(fut)
                        end)
                    end
                end
            else
                -- debug_msg('Task:__step got wrong Future', self._name)
                self._loop:call_soon(self.__step, 
                    {self, std.RuntimeError("Task expected a Future, got " .. type(arg1))})
            end
        end
    end)
    _leave_task(self._loop, self)
    if not _ok then
        raise(_err, 0)
    end
end

---@param fut asyncio.Future<T>
function Task:__wakeup(fut)
    -- debug_msg('Task:__wakeup', self._name, fut)
    if fut:done() then
        self._fut_waiter = nil
    end
    self._loop:call_soon(self.__step, {self})
end

function Task:__gc()
    if self._state == futures.PENDING and self._error_destroy_pending then
        self._loop:call_exception_handler{
            task = self,
            msg = 'Task was destroyed but it is pending'
        }
    end
end

-- META
---@generic T
---@nodiscard
---@param func fun():T
---@return asyncio.Coroutine<T>
local function async(func)
    return coroutines.Coroutine(func)
end

local _async = coroutines.Coroutine

---@async
---@generic T
---@param awaitable asyncio.Awaitable<T>?
---@return T?
---@overload fun(awaitable: asyncio.Awaitable<T>): T
---@overload fun(awaitable: nil): nil
local function await(awaitable)
    if awaitable == nil then
        local err = coroutine_yield(coroutines.co_empty)
        if err then
            raise(err, 0)
        end
        return
    end
    if std.isinstance(awaitable, _async) then
        ---@cast awaitable asyncio.Coroutine<T>
        return coroutines.coro_await(awaitable)
    end
    return awaitable:__await()
end

---@async
---@generic T
---@param awaitable asyncio.Awaitable<T>?
---@return T?, any?
---@overload fun(awaitable: asyncio.Awaitable<T>): true, T...
---@overload fun(awaitable: nil): false, any
local function try_await(awaitable)
    if awaitable == nil then
        local err = coroutine_yield(coroutines.co_empty)
        return nil, err
    end
    if std.isinstance(awaitable, _async) then
        ---@diagnostic disable-next-line: redundant-return-value
        ---@cast awaitable asyncio.Coroutine<T>
        return coroutines.coro_try_await(awaitable)
    end
    return awaitable:__try_await()
end

---@generic T
---@param func_or_coro (async fun():T)|thread|asyncio.Coroutine<T>
---@param name? string
---@return asyncio.Task<T>
local function create_task(func_or_coro, name)
    local loop = loops.get_running_loop()
    return loop:create_task(func_or_coro, name)
end

---@async
---@param delay number
---@return asyncio.Coroutine<nil>
local function sleep(delay)
return _async(function()
    if delay <= 0 then
        -- skip one event_loop run cycle
        return await()
    end
    local loop = loops.get_running_loop()
    local fut = loop:create_future()
    local handle = loop:call_later(delay, function()
        fut:set_result()
    end)
    local ok, err = try_await(fut)
    handle:cancel()
    if not ok then
        raise(err, 0)
    end
end)
end

---@async
---@param fs asyncio.Future<any>[]
---@param timeout? number
---@param return_when? "all_done" | "first_done" | "first_error"
local function wait(fs, timeout, return_when)
return _async(function()
    local loop = loops.get_running_loop()
    local waiter = loop:create_future()

    local timeout_handle
    if timeout ~= nil then
        timeout_handle = loop:call_later(timeout, function()
            if not waiter:done() then
                waiter:set_result()
            end
        end)
    end
    local c = #fs

    ---@param f asyncio.Future<any>
    local on_complete = function (f)
        c = c - 1
        if c <= 0 or 
            return_when == "first_done" or
            return_when == "first_error" and
            (not f:cancelled() and f:exception() ~= nil) then
            if timeout_handle ~= nil then
                timeout_handle:cancel()
            end
            if not waiter:done() then
                waiter:set_result()
            end
        end
    end

    for _, f in ipairs(fs) do
        f.add_done_callback(on_complete)
    end

    local ok, err = try_await(waiter)
    if timeout_handle ~= nil then
        timeout_handle:cancel()
    end
    for _, f in ipairs(fs) do
        f.remove_done_callback(on_complete)
    end
    if not ok then
        raise(err, 0)
    end
end)
end

---@async
---@param fut asyncio.Future<any>
---@param timeout? number
local function wait_for(fut, timeout)
return _async(function()
    if timeout and timeout <= 0 then
        if fut:done() then
            return fut:result()
        end
        local waiter = loops.get_running_loop():create_future()
        local cb = function()
            if not waiter:done() then
                waiter:set_result()
            end
        end
        fut:add_done_callback(cb)
        fut:cancel()
        local ok, err = try_await(waiter)
        fut:remove_done_callback(cb)
        if not ok then
            raise(err, 0)
        end
        -- the future was still pending when its deadline had already passed:
        -- it cannot make it any more, so report the timeout (like CPython)
        raise(std.TimeoutError(), nil, fut:_make_cancelled_error())
    end
    return await((timeouts or get_timeouts()).timeout(timeout):with(fut))
end)
end

---@generic T
---@class asyncio._GatheringFuture<T> : asyncio.Future<T>
---@overload fun(children: asyncio.Future<any>[], loop: asyncio.EventLoop):self
local _GatheringFuture = class.new('asyncio._GatheringFuture', {futures.Future})
---@param children asyncio.Future<any>[]
---@param loop asyncio.EventLoop
function _GatheringFuture:__init(children, loop)
    std.super(_GatheringFuture, self, futures.Future):__init(loop)
    self._children = children
    self._cancel_requested = false
end

function _GatheringFuture:cancel(msg)
    if self:done() then
        return false
    end
    local rv = false
    for _, child in ipairs(self._children) do
        if child:cancel(msg) then
            rv = true
        end
    end
    if rv then
        self._cancel_requested = true
    end
    return rv
end

---@async
---@generic T
---@param fs asyncio.Future<T>[]
---@param return_exceptions boolean?
---@return asyncio.Future<T[]>
---@overload fun(fs:asyncio.Future<T>[], return_exceptions:true):asyncio.Future<{result:T, exception:any}[]>
local function gather(fs, return_exceptions)
    if #fs <= 0 then
        local loop = loops.get_running_loop()
        local outer = loop:create_future()
        outer:set_result({})
        return outer
    end

    local futs = 0
    local finished = 0
    local done_futs = {}
    ---@type asyncio.Future<any>[]
    local children = {}
    local loop
    ---@type asyncio._GatheringFuture<any[]>?
    local outer

    ---@param fut asyncio.Future<any>
    local function done_cb(fut)
        finished = finished + 1
        if outer == nil or outer:done() then
            if not fut:cancelled() then
                fut:exception()
            end
            return
        end

        if not return_exceptions then
            if fut:cancelled() then
                outer:set_exception(fut:_make_cancelled_error())
                return
            else
                local exc = fut:exception()
                if exc ~= nil then
                    outer:set_exception(exc)
                    return
                end
            end
        end

        if finished == futs then
            local results = {}

            for _, fu in ipairs(children) do
                local res
                if fu:cancelled() then
                    res = exceptions.CancelledError(fu._cancel_msg or '')
                else
                    local exc = fu:exception()
                    if exc == nil then
                        res = fu:result()
                    end
                    if return_exceptions then
                        res = {result = res, exception = exc}
                    end
                end
                table.insert(results, res)
            end

            if outer._cancel_requested then
                outer:set_exception(outer._make_cancelled_error())
            else
                outer:set_result(results)
            end
        end
    end

    for _, fut in ipairs(fs) do
        if loop == nil then
            loop = fut._loop
        elseif fut._loop ~= loop then
            raise(std.ValueError(
                'The future belongs to a different loop than the one specified as the loop argument'))
        end
        futs = futs + 1
        if fut:done() then
            table.insert(done_futs, fut)
        else
            fut:add_done_callback(done_cb)
        end
        table.insert(children, fut)
    end

    ---@cast loop asyncio.EventLoop
    outer = _GatheringFuture(children, loop)
    -- children that were already done when gather() was called never received a
    -- done callback, so they must be accounted for explicitly -- otherwise
    -- `finished` never reaches `futs` and the gathering future never completes
    for _, fut in ipairs(done_futs) do
        done_cb(fut)
    end
    return outer
end

---@generic T
---@param fut asyncio.Future<T>
---@return asyncio.Future<T>
local function shield(fut)
    if fut:done() then
        return fut
    end
    ---@type asyncio.EventLoop !Emmylua BUG
    local loop = fut:_get_loop()
    local inner = fut
    local outer = loop:create_future()

    local _inner_done_callback = function()
        if outer:cancelled() then
            if not inner:cancelled() then
                inner:exception()
            end
        end
        if inner:cancelled() then
            outer:cancel()
        else
            local exc = inner:exception()
            if exc ~= nil then
                outer:set_exception(exc)
            else
                outer:set_result(inner:result())
            end
        end
    end

    inner:add_done_callback(_inner_done_callback)
    outer:add_done_callback(function()
        if not inner:done() then
            inner:remove_done_callback(_inner_done_callback)
        end
    end)
    return outer
end

---@class asyncio.tasks
local tasks = {
    current_task = current_task,
    async = async,
    await = await,
    try_await = try_await,
    create_task = create_task,
    sleep = sleep,
    wait = wait,
    wait_for = wait_for,
    gather = gather,
    shield = shield,
    Task = Task,
}

if 1 then
    tasks.async = _async
end

return tasks
