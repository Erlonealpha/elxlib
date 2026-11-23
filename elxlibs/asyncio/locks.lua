---@namespace asyncio

local std = require 'elxlibs.std'
local class = require 'elxlibs.std.class'
local asyncio = require'elxlibs.asyncio'
local exceptions = require'elxlibs.asyncio.exceptions'
local utils = require 'elxlibs.asyncio.utils'

local await = asyncio.await
local async = asyncio.async
local raise = std.raise

local M = {}

---@class _LoopMixin : std.object
local _LoopMixin = class.new('_LoopMixin')

---@return EventLoop
function _LoopMixin:_get_loop()
    local loop = asyncio.loops.get_running_loop()
    if self._loop == nil then
        self._loop = loop
    end
    if loop ~= self._loop then
        raise(std.RuntimeError(string.format('%s is bound to a different event loop', self)))
    end
    return loop
end

---@class Lock : _LoopMixin
---@overload fun():Lock
local Lock = class.new('Lock', _LoopMixin)

function Lock:__init()
    ---@type Future<nil>[]?
    self._waiters = nil
    self._locked = false
end

function Lock:__tostring()
    if self._locked then
        return '<Lock [locked]>'
    else
        return '<Lock [unlocked]>'
    end
end

function Lock:locked()
    return self._locked
end


---@generic T
---@param iterable T[]
---@param fn fun(it: T): boolean
local function all(iterable, fn) 
    for _, it in ipairs(iterable) do
        if not fn(it) then
            return false
        end
    end
    return true
end

---@generic T
---@param iterable T[]
---@param fn fun(it: T): boolean
local function any(iterable, fn)
    for _, it in ipairs(iterable) do
        if fn(it) then
            return true
        end
    end
    return false
end

---@async
---@return Coroutine<boolean>
function Lock:acquire()
return async(function()
    if not self._locked and (self._waiters == nil or 
        all(self._waiters, function(w) return w:cancelled() end)) then
        self._locked = true
        return true
    end

    if self._waiters == nil then
        self._waiters = {}
    end
    local fut = self:_get_loop():create_future()
    table.insert(self._waiters, fut)

    local ok, err = fut:__try_await()
    if ok then
        err = nil
    end

    for i, w in ipairs(self._waiters) do
        if fut == w then
            table.remove(self._waiters, i)
            break
        end
    end

    if type(err) == 'table' and std.isinstance(err, exceptions.CancelledError) then
        if not self._locked then
            self:_wakeup_first()
        end
    end
    if err then
        raise(err, 0)
    end

    self._locked = true
    return true
end)
end

function Lock:release()
    if self._locked then
        self._locked = false
        self:_wakeup_first()
    else
        raise('Lock is not acquired')
    end
end

function Lock:_wakeup_first()
    if self._waiters == nil or # self._waiters == 0 then
        return
    end

    for _, w in ipairs(self._waiters) do
        if not w:done() then
            w:set_result()
        end
        break
    end
end


---@class Event : _LoopMixin
---@overload fun():Event
local Event = class.new('Event', _LoopMixin)

function Event:__init()
    ---@type Future<boolean>[]
    self._waiters = {}
    self._value = false
end

function Event:is_set()
    return self._value
end

function Event:set()
    if not self._value then
        self._value = true
        for _, w in ipairs(self._waiters) do
            if not w:done() then
                w:set_result(true)
            end
        end
    end
end

function Event:clear()
    self._value = false
end

---@async
---@return Coroutine<boolean>
function Event:wait()
return async(function()
    if self._value then
        return true
    end
    local fut = self:_get_loop():create_future()
    table.insert(self._waiters, fut)

    local ok, err = fut:__try_await()
    if ok then
        err = nil
    end

    for i, w in ipairs(self._waiters) do
        if fut == w then
            table.remove(self._waiters, i)
            break
        end
    end
    if err ~= nil then
        raise(err, 0)
    end
    return true
end)
end

---@class _WithMixin : _LoopMixin
---@field acquire fun(self:self):Coroutine<boolean>
---@field release fun(self:self)
local _WithMixin = std.class.new('_WithMixin', _LoopMixin)

---@param func_or_awaitable thread | function | Future<any> | Coroutine<any>
function _WithMixin:with(func_or_awaitable)
    return utils.with(
        func_or_awaitable,
        function(_task) end,
        function(_exc)
            self:release()
        end,
        'Semaphore:with',
        function() await(self:acquire()) end
    )
end

---@class Semaphore : _WithMixin
---@field _value int
---@field _waiters (Future<boolean>[])?
---@overload fun(value:int?):self
local Semaphore = std.class.new('Semaphore', _WithMixin)
function Semaphore:__init(value)
    if value ~= nil and value < 0 then
        raise(std.ValueError('Semaphore initial value must be >= 0'))
    end
    self._value = value or 1
    self._waiters = nil
end

function Semaphore:locked()
    return self._value == 0 or (self._waiters ~= nil and
        any(self._waiters, function(w) return not w:cancelled() end))
end

---@async
function Semaphore:acquire()
return async(function()
    if not self:locked() then
        self._value = self._value - 1
        return true
    end

    if self._waiters == nil then
        self._waiters = {}
    end
    local fut = self:_get_loop():create_future()
    table.insert(self._waiters, fut)

    local ok, err = fut:__try_await()
    for i, waiter in ipairs(self._waiters) do
        if waiter == fut then
            table.remove(self._waiters, i)
            break
        end
    end
    if ok then
        err = nil
    end

    if type(err) == 'table' and std.isinstance(err, exceptions.CancelledError) then
        if fut:done() and not fut:cancelled() then
            self._value = self._value + 1
        end
    end

    while self._value > 0 do
        if not self:_wakeup_next() then
            break
        end
    end

    if not ok then
        raise(err, 0)
    end

    return true
end)
end

function Semaphore:release()
    self._value = self._value + 1
    self:_wakeup_next()
end

function Semaphore:_wakeup_next()
    if self._waiters == nil or #self._waiters <= 0 then
        return false
    end
    for _, fut in ipairs(self._waiters) do
        if not fut:done() then
            self._value = self._value - 1
            fut:set_result(true)
            return true
        end
    end
    return false
end

M.Lock = Lock
M.Event = Event
M.Semaphore = Semaphore

return M
