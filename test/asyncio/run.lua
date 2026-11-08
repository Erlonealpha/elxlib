-- Project entry point; mpv-luatest owns discovery, assertions and reporting.
local entry = (arg and arg[0] or 'test/asyncio/run.lua'):gsub('\\', '/')
local directory = entry:match('^(.*)/[^/]+$') or '.'
local dependency = directory .. '/../vendor/mpv-luatest/src'
local available = io.open(dependency .. '/mpv_luatest/suite.lua', 'r')
if not available then
    io.stderr:write('mpv-luatest is missing; run git submodule update --init --recursive\n')
    os.exit(1)
else
    available:close()
end
package.path = dependency .. '/?.lua;' .. dependency .. '/?/init.lua;' .. package.path

local suite = require 'mpv_luatest.suite'
os.exit(suite.main(arg or {}, {
    verbose = false,
    root = directory .. '/../..',
    test_dir = 'test/asyncio',
    paths = {},
    bootstrap = 'test/asyncio/bootstrap.lua',
    suite_name = 'elxlib asyncio test-suite',
}))
