local F = require 'mpv_luatest.framework'
local class = require 'elxlibs.std.class'
local inspect = require 'elxlibs.std.inspect'
local S = require 'test_std.support'

F.section('shared class descriptors')

F.test('getter-only descriptors use direct storage and allow data shadowing', function()
    local owners, receivers = {}, {}
    local descriptor = {
        __get = function(_, obj, owner)
            owners[#owners + 1] = owner
            receivers[#receivers + 1] = obj or false
            return false
        end,
    }
    ---@class _std_desc.Getter : std.object
    ---@field value any
    ---@overload fun():self
    local Type = class.new('_std_desc.Getter', nil, {value = descriptor})
    class.finish(Type)
    local first, second = Type(), Type()
    F.eq(Type.value, false, 'class descriptor access')
    F.eq(receivers[1], false, 'class access receiver nil')
    F.eq(first.value, false, 'getter false is found')
    F.eq(owners[2], Type, 'access class is owner')
    F.eq(receivers[2], first, 'receiver is instance')
    F.eq(inspect.getmetatable(first).__newindex, nil, 'get-only adds no writer')
    F.eq(rawget(first, '__dict'), nil, 'get-only retains direct backend')
    first.value = 3
    F.eq(first.value, 3, 'instance data shadows getter')
    F.eq(second.value, false, 'other instance still uses shared descriptor')
    first.value = nil
    F.eq(first.value, false, 'deletion reveals getter')
    F.eq(inspect.getmembers(Type).value, descriptor, 'inspect returns descriptor object')
end)

F.test('a descriptor returning nil remains found and never invokes missing-read fallback', function()
    local calls = 0
    ---@class _std_desc.Nil : std.object
    ---@field value any
    ---@overload fun():self
    local descriptor = {
        __get = function()
            return nil
        end,
    }
    local Type = class.new('_std_desc.Nil', nil, {value = descriptor})
    function Type.__getattr(_self, _key)
        calls = calls + 1
        return 'fallback'
    end
    local obj = Type()
    F.eq(obj.value, nil, 'descriptor nil is authoritative')
    F.eq(calls, 0, 'missing fallback not invoked')
    F.eq(select('#', inspect.getattribute(obj, 'value')), 1, 'found marker stays private')
end)

F.test('data descriptors override backing values and setter receives nil deletion', function()
    local set_values = {}
    local descriptor = {
        __get = function(_, obj)
            return obj and inspect.rawgetattr(obj, '_value')
        end,
        __set = function(_, obj, value)
            set_values[#set_values + 1] = value == nil and 'deleted' or value
            inspect.rawsetattr(obj, '_value', value)
        end,
    }
    ---@class _std_desc.Data : std.object
    ---@field value any
    ---@overload fun():self
    local Type = class.new('_std_desc.Data', nil, {value = descriptor}, {dict = false})
    local obj = Type()
    F.eq(inspect.classinfo(Type).storage, 'dict', 'setter activates dict')
    F.eq(inspect.classinfo(Type).options.dict, false, 'option remains false')
    inspect.rawsetattr(obj, 'value', 'shadow')
    obj.value = false
    F.eq(obj.value, false, 'data getter takes precedence over dict')
    obj.value = 8
    F.eq(obj.value, 8, 'existing property assignment reaches setter')
    obj.value = nil
    F.eq(obj.value, nil, 'getter nil remains authoritative')
    F.eq(set_values[1], false, 'setter sees false')
    F.eq(set_values[3], 'deleted', 'deletion is setter nil')
    F.eq(inspect.rawgetattr(obj, 'value'), 'shadow', 'raw data bypass remains trusted')
end)

F.test('full hooks delegate to descriptors and inheritance resolves the requested owner', function()
    local log = {}
    local desc = {
        __get = function(_, obj, owner)
            log[#log + 1] = owner
            return obj and inspect.rawgetattr(obj, '_value')
        end,
        __set = function(_, obj, value)
            inspect.rawsetattr(obj, '_value', value)
        end,
    }
    ---@class _std_desc.Parent : std.object
    ---@field value any
    ---@overload fun():self
    local Parent = class.new('_std_desc.Parent', nil, {value = desc})
    ---@class _std_desc.Child : _std_desc.Parent
    ---@overload fun():self
    local Child = class.new('_std_desc.Child', Parent)
    function Child:__getattribute(key)
        return inspect.getattribute(self, key)
    end
    function Child:__setattribute(key, value)
        inspect.setattribute(self, key, value)
    end
    local obj = Child()
    obj.value = 5
    F.eq(obj.value, 5, 'hooks delegate through descriptor')
    F.eq(log[#log], Child, 'inherited descriptor sees derived access class')
    F.eq(class.super(Child, obj, Parent).value, 5, 'super invokes parent descriptor')
    F.eq(log[#log], Parent, 'super access owner is parent')
    ---@class _std_desc.Override : _std_desc.Parent
    ---@overload fun():self
    local Override = class.new('_std_desc.Override', Parent, {value = false})
    local override = Override()
    F.eq(override.value, false, 'plain override hides parent descriptor')
    F.eq(rawget(override, '__dict'), nil, 'overridden descriptor does not force dict')
end)

F.test('readonly setters reject all assignments and descriptor errors preserve identity', function()
    local boom = {}
    local desc = {
        __get = function()
            return 4
        end,
        __set = function()
            error(boom)
        end,
    }
    ---@class _std_desc.Readonly : std.object
    ---@field value any
    ---@overload fun():self
    local Type = class.new('_std_desc.Readonly', nil, {value = desc})
    local obj = Type()
    F.eq(select(2, pcall(function()
        obj.value = 1
    end)), boom, 'readonly error identity')
    F.eq(select(2, pcall(function()
        obj.value = nil
    end)), boom, 'delete also rejected')
    F.eq(obj.value, 4, 'value retained')
    desc.__get = function()
        return 9
    end
    F.eq(obj.value, 4, 'getter strategy cached at finish')
    ---@class _std_desc.Invalid : std.object
    local Invalid = class.new('_std_desc.Invalid', nil, {value = {__get = 1}})
    F.raises(function()
        class.finish(Invalid)
    end, 'TypeError', 'invalid descriptor rejected')
    F.eq(inspect.classinfo(Invalid).finished, false, 'failed finish remains retryable')
    S.runtime(Invalid).__dict.value = desc
    class.finish(Invalid)
    F.eq(inspect.classinfo(Invalid).finished, true, 'corrected descriptor can finish')
end)
