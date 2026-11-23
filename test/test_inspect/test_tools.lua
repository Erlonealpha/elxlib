local F = require 'mpv_luatest.framework'
local inspect = require 'elxlibs.std.inspect'
local class = require 'elxlibs.std.class'
local S = require 'test_std.support'

F.section('inspect capabilities and attribute tools')

F.test('tools preserve module identity and return isolated shallow views', function()
    ---@class _inspect_tools.Record : std.object
    ---@field value any
    ---@overload fun():self
    local Record = class.new('_inspect_tools.Record', nil, {value = false})
    local obj = Record()
    -- Reimport is intentional here: module identity is the behavior under test.
    ---@diagnostic disable-next-line: duplicate-require
    F.eq(require('elxlibs.std.inspect'), inspect, 'stable inspect identity')
    F.eq(require('elxlibs.std').inspect, inspect, 'std aggregate shares inspect module')
    F.eq(rawget(inspect, 'kindof'), nil, 'inspect does not export kind query')
    F.eq(rawget(inspect, 'classof'), nil, 'inspect does not export class query')
    F.eq(inspect.getattr(obj, 'value'), false, 'ordinary read')
    inspect.setattr(obj, 'value', 2)
    F.eq(inspect.getattribute(obj, 'value'), 2, 'default read')
    F.eq(inspect.rawgetattr(obj, 'value'), 2, 'raw read')
    inspect.setattribute(obj, 'value', nil)
    F.eq(inspect.getattr(obj, 'value'), false, 'delete reveals class value')
    local members = inspect.getmembers(Record)
    members.value = 9
    F.eq(Record.__dict.value, false, 'members view isolated')
    F.eq(inspect.getmembers(Record, true).__init, class.object.__init, 'inherited member query')
    F.eq(inspect.getmembers(Record).__init, nil, 'own-only member query')
    F.raises(function()
        inspect.classinfo(S.runtime({}))
    end, 'TypeError', 'invalid class')
    F.raises(function()
        inspect.getattribute(S.runtime({}), 'x')
    end, 'TypeError', 'invalid instance')
    F.raises(function()
        inspect.getmetatable(S.runtime({}))
    end, 'TypeError', 'invalid metatable query')
end)

F.test('tools are built from raw capabilities and installation can retry safely', function()
    local loader = assert(loadfile(assert(debug.getinfo(inspect.__install, 'S')).source:sub(2)))
    local isolated = loader()
    F.eq(rawget(isolated, 'kindof'), nil, 'uninstalled inspect has no kind query')
    F.eq(rawget(isolated, 'classof'), nil, 'uninstalled inspect has no class query')
    F.raises(function()
        isolated.classinfo(class.object)
    end, 'unavailable', 'uninstalled class tool')
    F.raises(function()
        isolated.__install('std.class', S.runtime({}))
    end, 'missing capability', 'partial installer rejected')

    local fake_class = {
        __name = 'PrimitiveClass',
        __dict = {shared = false},
        __mro = {},
    }
    fake_class.__mro[1] = fake_class

    local state = {
        cls = fake_class,
        opts = {dict = false, abstract = false, final = false},
        finished = false,
        dict = true,
        data = function(obj)
            return obj.__dict
        end,
        read = function(obj, key)
            return obj.__dict[key]
        end,
        write = function(obj, key, value)
            obj.__dict[key] = value
        end,
    }
    local finish_calls = 0
    local actual_mt = {__class_state = state, __metatable = 'protected'}
    local access = {
        state_of = function(cls)
            if cls == fake_class then
                return state
            end
        end,
        finish = function(cls)
            F.eq(cls, fake_class, 'finish gets raw class identity')
            finish_calls = finish_calls + 1
            state.finished = true
            return state
        end,
        getmetatable = function()
            return actual_mt
        end,
        fail = function(message)
            error('TypeError: ' .. message)
        end,
    }

    isolated.__install('std.class', S.runtime(access))
    F.raises(function()
        isolated.__install('std.class', S.runtime(access))
    end, 'already installed', 'same capabilities cannot install twice')

    F.eq(isolated.classinfo(S.runtime(fake_class)).name, 'PrimitiveClass', 'snapshot built from raw state')
    F.eq(isolated.classinfo(S.runtime(fake_class)).storage, nil, 'information query keeps class open')
    F.eq(finish_calls, 0, 'queries do not complete class')

    local obj = S.runtime({__class = fake_class, __dict = {value = false}})
    F.eq(isolated.getattribute(obj, 'value'), false, 'cached read primitive used')
    F.eq(finish_calls, 1, 'unfinished state completed once')
    isolated.setattribute(obj, 'value', 3)
    F.eq(isolated.rawgetattr(obj, 'value'), 3, 'raw data primitive used')
    isolated.rawsetattr(obj, 'value', nil)
    F.eq(isolated.getattribute(obj, 'value'), nil, 'raw deletion visible to reader')
    F.eq(finish_calls, 1, 'finished access reuses state')

    local info = isolated.classinfo(S.runtime(fake_class))
    F.eq(info.storage, 'dict', 'effective storage read from state')
    info.options.dict = true
    F.eq(state.opts.dict, false, 'inspect copies raw options')
    F.eq(isolated.getmembers(S.runtime(fake_class)).shared, false, 'inspect reads raw members')

    local mt = isolated.getmetatable(obj)
    F.eq(mt.__class_state, nil, 'private state excluded from returned view')
    mt.__metatable = 'changed'
    F.eq(actual_mt.__metatable, 'protected', 'inspect copies actual metatable')

    F.raises(function()
        isolated.__install('std.class', S.runtime({}))
    end, 'already installed', 'conflict rejected')
    F.eq(isolated.classinfo(S.runtime(fake_class)).name, 'PrimitiveClass', 'failed conflict retains capabilities')
end)
