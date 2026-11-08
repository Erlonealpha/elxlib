-- Project entry point; mpv-luatest owns discovery, assertions and reporting.
local entry = (arg and arg[0] or 'test/run.lua'):gsub('\\', '/')
local directory = entry:match('^(.*)/[^/]+$') or '.'
local dependency = directory .. '/vendor/mpv-luatest/src'
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
    root = directory .. '/..',
    test_dir = 'test',
    paths = {},
    bootstrap = 'test/bootstrap.lua',
    suite_name = 'elxlib test-suite',
}))
