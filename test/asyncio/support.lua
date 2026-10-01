-- Shared bootstrap for the elxlib asyncio test-suite.
--
-- The suite runs on a bare LuaJIT (no mpv needed): `mp` is stubbed by
-- mp_stub.lua, and every module is loaded straight from the repository with
-- plain `require` (the real init.lua is NOT involved, so no ffi / mp.utils /
-- DLL-path setup is required).

local S = {}

--- Root of the repository, derived from the path of this file.
---@param from? string path of the running chunk (`arg[0]`)
---@return string
function S.repo_root(from)
    local here = (from or (arg and arg[0]) or "."):gsub("\\", "/")
    local root = here:gsub("/test/asyncio/[^/]*$", "")
    if root == here then
        -- fall back: assume we were started from the repository root
        root = "."
    end
    return root
end

--- Make `elxlibs.*` (and the test modules themselves) require-able.
---@param root string
function S.bootstrap(root)
    local test_dir
    do
        local here = (arg and arg[0] or ""):gsub("\\", "/")
        test_dir = here:gsub("/[^/]*$", "")
    end
    package.path = table.concat({
        test_dir .. "/?.lua",
        root .. "/?.lua",
        root .. "/?/init.lua",
        package.path,
    }, ";")

    -- LuaJIT built without LUA52COMPAT has neither of these, while the
    -- library uses them (multi-value plumbing in coroutine/task helpers).
    if not table.pack then
        table.pack = function(...) return { n = select("#", ...), ... } end
    end
    if not table.unpack then
        table.unpack = unpack
    end

    -- normally defined by init.lua
    _G.debug_msg = _G.debug_msg or function() end
    return root
end

--- An EventLoop whose clock has sub-second resolution (the default loop uses
--- os.time(), which would make every timer test wait up to a second).
---@param asyncio table
function S.real_loop(asyncio)
    local std = require("elxlibs.std")
    local Loop = std.class.new("test.EventLoop", {asyncio.loops.EventLoop})
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
