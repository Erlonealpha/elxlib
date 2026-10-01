-- Entry point for the elxlib asyncio test-suite.
--
--   luajit test/asyncio/run.lua            # everything
--   luajit test/asyncio/run.lua amp        # only files whose name matches
--
-- Runs on a bare LuaJIT (mpv is not required; `mp` is stubbed).

local this = (arg and arg[0] or "test/asyncio/run.lua"):gsub("\\", "/")
local dir = this:gsub("/[^/]*$", "")
package.path = table.concat({ dir .. "/?.lua", dir .. "/?/init.lua", package.path }, ";")

local support = require("support")
local framework = require("framework")
local mp_stub = require("mp_stub")

support.bootstrap(support.repo_root(this))

-- a default stub so plain `require("mp")` works for the non-amp tests
package.preload["mp"] = function() return mp_stub.new() end

local filter = (arg and arg[1]) or nil

local files = {
    "test_core",
    "test_exceptions",
    "test_cancellation",
    "test_timeouts",
    "test_amp_shutdown",
}

print("elxlib asyncio test-suite (lua " .. _VERSION .. ", " ..
    (jit and jit.version or "no jit") .. ")")

local ran = 0
for _, name in ipairs(files) do
    if not filter or name:find(filter, 1, true) then
        ran = ran + 1
        local path = dir .. "/" .. name .. ".lua"
        local ok, err = pcall(dofile, path)
        if not ok then
            framework.fail(name .. " crashed: " .. tostring(err):gsub("\n", " | "))
        end
    end
end

if ran == 0 then
    framework.fail("no test file matched filter '" .. tostring(filter) .. "'")
end

local all_good = framework.summary()
os.exit(all_good and 0 or 1)
