-- Run in a fresh LuaJIT process from the project root; not a discovered test file.
local mode = assert(arg[1])
package.path = './?.lua;./?/init.lua;' .. package.path
dofile('test/bootstrap.lua')

if mode == 'inspect' then
    local inspect = require 'elxlibs.std.inspect'
    assert(package.loaded['elxlibs.std.class'] == nil)
    assert(package.loaded['elxlibs.std.exception'] == nil)
    assert(package.loaded.mp == nil)
    assert(rawget(inspect, 'kindof') == nil)
    assert(rawget(inspect, 'classof') == nil)
    ---@return any
    local function invalid_value()
        return {}
    end
    assert(not pcall(inspect.classinfo, invalid_value()))
    require 'elxlibs.std'
    -- Reimport verifies that installation preserves the original module object.
    ---@diagnostic disable-next-line: duplicate-require
    assert(inspect == require 'elxlibs.std.inspect')
elseif mode == 'class' then
    require 'elxlibs.std.class'
    require 'elxlibs.std'
elseif mode == 'exception' then
    require 'elxlibs.std.exception'
    require 'elxlibs.std.exception_init'
    require 'elxlibs.std'
elseif mode == 'capabilities' then
    ---@type std.InspectCapabilities?
    local access
    package.loaded['elxlibs.std.inspect'] = {
        __install = function(name, installed)
            assert(name == 'std.class')
            access = installed
        end,
    }

    local class = require 'elxlibs.std.class'
    assert(access)
    ---@cast access std.InspectCapabilities
    local keys = {state_of = true, finish = true, getmetatable = true, fail = true}
    local count = 0

    for key, value in pairs(access) do
        assert(keys[key] and type(value) == 'function')
        count = count + 1
    end

    assert(count == 4)
    assert(access.getmetatable == debug.getmetatable)

    local state = access.state_of(class.object)
    local mt = assert(debug.getmetatable(class.object))
    assert(state == mt.__class_state)
    assert(access.finish(class.object) == state)

    package.loaded['elxlibs.std.inspect'] = nil
    local inspect = require 'elxlibs.std.inspect'
    inspect.__install('std.class', access)
    require 'elxlibs.std'
elseif mode == 'dataclass' then
    require 'elxlibs.dataclass'
    assert(package.loaded['elxlibs.std.class'] == nil)
    assert(package.loaded['elxlibs.std.inspect'] == nil)
    return
else
    error('unknown import order')
end

local inspect = require 'elxlibs.std.inspect'
local std = require 'elxlibs.std'
assert(std.inspect == inspect)
assert(std.classof(std.TypeError('test')) == std.TypeError)
assert(std.classof == std.class.classof)
assert(std.isinstance(std.TypeError('test'), std.Exception))
assert(std.class == require 'elxlibs.std.class')
assert(package.loaded.mp == nil)
print('import order passed: ' .. mode)
