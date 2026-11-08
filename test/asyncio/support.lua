-- Project helpers for the elxlib asyncio test-suite.
--
-- The suite runs on a bare LuaJIT (no mpv needed): `mp` is stubbed by
-- amp_stub.lua, and every module is loaded straight from the repository with
-- plain `require` (the real init.lua is NOT involved, so no ffi / mp.utils /
-- DLL-path setup is required).

local S = {}

--- Deliberately invalid inputs for runtime boundary tests.
---@param value any
---@return any
function S.invalid(value) return value end

--- An EventLoop whose clock has sub-second resolution (the default loop uses
--- os.time(), which would make every timer test wait up to a second).
---@param asyncio asyncio
---@return asyncio.EventLoop
function S.real_loop(asyncio)
    local std = require("elxlibs.std")
    ---@class _asyncio_test.EventLoop : asyncio.EventLoop
    ---@overload fun():self
    local Loop = std.class.new("_asyncio_test.EventLoop", asyncio.loops.EventLoop)
    function Loop:time()
        return os.clock()
    end
    return Loop()
end

--- Drop every asyncio module (and the mp stub) so the next require() rebuilds
--- them with pristine module state. Needed by the amp loop tests: the event
--- loop, the registered finally callbacks and the "stopping" flag are all
--- module locals of elxlibs/asyncio/mp.lua and cannot be reset otherwise.
---@param stub table mp stub to install
---@return table asyncio
function S.reload_asyncio(stub)
    for name in pairs(package.loaded) do
        if name == "mp" or name:match("^elxlibs%.asyncio") then
            package.loaded[name] = nil
        end
    end
    package.preload["mp"] = function() return stub end
    return require("elxlibs.asyncio")
end

--- Run offline coroutine cases with a watchdog, including deadlock regressions.
---@param body function
function S.run(body)
    local asyncio = require 'elxlibs.asyncio'
    local loop = S.real_loop(asyncio)
    local watchdog = loop:call_later(2, function()
        error('TEST-WATCHDOG: offline task did not finish')
    end)
    loop:set_exception_handler(function(context)
        error(context.exception or context.msg, 0)
    end)
    local result = table.pack(pcall(asyncio.run, body, loop))
    watchdog:cancel()
    loop:close()
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

return S
