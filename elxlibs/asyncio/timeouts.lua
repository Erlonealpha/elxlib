---@namespace asyncio

local std = require 'elxlibs.std'
local asyncio = require 'elxlibs.asyncio'
local exceptions = require 'elxlibs.asyncio.exceptions'
local utils = require 'elxlibs.asyncio.utils'

local raise = std.raise


local CREATED = 'created'
local ENTERED = 'active'
local EXPIRING = 'expiring'
local EXPIRED = 'expired'
local EXITED = 'finished'

---@alias TimeoutState
--- | 'created'
--- | 'active'
--- | 'expiring'
--- | 'expired'
--- | 'finished'

---@class Timeout : std.object
---@field _state TimeoutState
---@field _timeout_handler Handle|TimerHandle
---@field _task Task<any>
---@field _when number?
---@overload fun(when:number?):self
local Timeout = std.class.new_final('Timeout')
function Timeout:__init(when)
    self._state = CREATED
    self._timeout_handler = nil
    self._task = nil
    self._when = when
end

function Timeout:when()
    return self._when
end

---@param when number?
function Timeout:reschedule(when)
    if self._state ~= ENTERED then
        if self._state == CREATED then
            raise(std.RuntimeError('Timeout has not been entered'))
        end
        raise(std.RuntimeError(string.format('Cannot change state of %s Timeout', self._state)))
    end

    self._when = when

    if self._timeout_handler ~= nil then
        self._timeout_handler:cancel()
    end

    if when == nil then
        self._timeout_handler = nil
    else
        local loop = asyncio.loops.get_running_loop()
        -- handles are called as plain functions here, so `self` has to be
        -- passed explicitly as the callback argument
        if when <= loop:time() then
            self._timeout_handler = loop:call_soon(self._on_timeout, {self})
        else
            self._timeout_handler = loop:call_at(when, self._on_timeout, {self})
        end
    end
end

function Timeout:expired()
    return self._state == EXPIRING or self._state == EXPIRED
end

function Timeout:__tostring()
    local info = ''
    if self._state == ENTERED then
        info = info .. (
            self._when ~= nil and
            string.format(' when=%.2f', self._when) or
            ' when=nil')
    end
    return string.format('<Timeout [%s]>%s', self._state, info)
end

---@async
---@param func_or_awaitable thread | function | Future<any> | Coroutine<any>
function Timeout:with(func_or_awaitable)
    return utils.with(
        func_or_awaitable,
        function(task)
            self:__enter(task)
        end,
        function(exc)
            self:__exit(exc)
        end,
        'Timeout:with'
    )
end

function Timeout:__enter(task)
    if self._state ~= CREATED then
        raise(std.RuntimeError('Timeout has already been entered'), 2)
    end

    self._state = ENTERED
    self._task = task
    self._cancelling = self._task:cancelling()
    self:reschedule(self._when)
end

function Timeout:__exit(exc)
    if self._timeout_handler ~= nil then
        self._timeout_handler:cancel()
        self._timeout_handler = nil
    end
    if self._state == EXPIRING then
        self._state = EXPIRED

        if self._task:uncancel() <= self._cancelling and exc ~= nil then
            if std.isinstance(exc, exceptions.CancelledError) then
                -- raise an instance (not the class), so __cause/__traceback are
                -- stored on the error object instead of the shared class
                raise(std.TimeoutError(), 2, exc)
            end
        end
    elseif self._state == ENTERED then
        self._state = EXITED
    end
end

function Timeout:_on_timeout()
    self._task:cancel()
    self._state = EXPIRING
    self._timeout_handler = nil
end

local M = {Timeout = Timeout}

---@param delay number?
---@return Timeout
function M.timeout(delay)
    local loop = asyncio.loops.get_running_loop()
    return Timeout(delay and loop:time() + delay or nil)
end

---@param when number?
---@return Timeout
function M.timeout_at(when)
    return Timeout(when)
end

return M
