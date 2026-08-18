local std = require("elxlibs.std")
local class = require("elxlibs.std.class")
local asyncio = require("elxlibs.asyncio")
local exceptions = require("elxlibs.asyncio.exceptions")

local M = {}

---@class asyncio._LoopMixin : std.object
local _LoopMixin = class.new('asyncio._LoopMixin')

---@return asyncio.EventLoop
function _LoopMixin:_get_loop()
    local loop = asyncio.loops.get_running_loop()
    if self._loop == nil then
        self._loop = loop
    end
    if loop ~= self._loop then
        std.raise(std.RuntimeError(string.format('%s is bound to a different event loop', self)))
    end
    return loop
end

---@class asyncio.Lock : asyncio._LoopMixin
---@overload fun():asyncio.Lock
local Lock = class.new('asyncio.Lock', {_LoopMixin})

function Lock:__init()
    ---@type asyncio.Future<nil>[]?
    self._waiters = nil
    self._locked = false
end

function Lock:__tostring()
    if self._locked then
        return string.format('<asyncio.Lock(%s) [locked]>', self)
    else
        return string.format('<asyncio.Lock(%s) [unlocked]>', self)
    end
end

function Lock:locked()
    return self._locked
end


---@generic T
---@param iterable T[]
---@param fn fun(T):boolean
local function all(iterable, fn) 
    for _, it in ipairs(iterable) do
        if not fn(it) then
            return false
        end
    end
    return true
end

---@async
---@return asyncio.Task<boolean>
function Lock:acquire()
    return asyncio.async(function()
        if not self._locked and (self._waiters == nil or 
            all(self._waiters, function(w) return w.cancelled() end)) then
            self._locked = true
            return true
        end

        if self._waiters == nil then
            self._waiters = {}
        end
        local fut = self:_get_loop():create_future()
        table.insert(self._waiters, fut)

        local _, err = fut:__try_await()

        for i, w in ipairs(self._waiters) do
            if fut == w then
                table.remove(self._waiters, i)
                break
            end
        end

        if type(err) == "table" and std.isinstance(err, exceptions.CancelledError) then
            if not self._locked then
                self:_wakeup_first()
            end
            error(err)
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
        error('Lock is not acquired')
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


---@class asyncio.Event : asyncio._LoopMixin
---@overload fun():asyncio.Event
local Event = class.new('asyncio.Event', {_LoopMixin})

function Event:__init()
    ---@type asyncio.Future<boolean>[]
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
---@return asyncio.Future<boolean>
function Event:wait()
    return asyncio.async(function()
        if self._value then
            return true
        end
        local fut = self:_get_loop():create_future()
        table.insert(self._waiters, fut)

        local _, err = fut:__try_await()

        for i, w in ipairs(self._waiters) do
            if fut == w then
                table.remove(self._waiters, i)
                break
            end
        end
        if err ~= nil then
            std.raise(err)
        end
        return true
    end)
end


M.Lock = Lock
M.Event = Event

return M