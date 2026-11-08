-- Project helpers for the elxlib asyncio test-suite.
--
-- The suite runs on a bare LuaJIT (no mpv needed): `mp` is stubbed by
-- amp_stub.lua, and every module is loaded straight from the repository with
-- plain `require` (the real init.lua is NOT involved, so no ffi / mp.utils /
-- DLL-path setup is required).

local S = {}

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

return S
