local F = require 'mpv_luatest.framework'
local class = require 'elxlibs.std.class'
local S = require 'test_std.support'

F.section('parent access without default proxy allocations')

F.test('unbound parent access and bound compatibility preserve nils and dynamic methods', function()
    ---@class _std_super.Parent : std.object
    ---@field value integer
    ---@overload fun():self
    local Parent = class.new('_std_super.Parent')
    function Parent:read(...)
        return self.value, ..., nil
    end
    ---@class _std_super.Child : _std_super.Parent
    ---@overload fun():self
    local Child = class.new('_std_super.Child', Parent)
    function Child.read(_self)
        return 99
    end
    local obj = Child()
    obj.value = 7
    F.eq(class.super(Child, nil, Parent), Parent, 'no-receiver returns actual parent')
    local unbound = table.pack(class.super(Child, nil, Parent).read(obj, false))
    F.eq(unbound.n, 3, 'unbound trailing nil retained')
    F.eq(unbound[1], 7, 'unbound uses requested parent')
    F.eq(unbound[2], false, 'false return retained')
    local proxy = class.super(Child, obj, Parent)
    F.eq(proxy.read, proxy.read, 'wrapper reused')
    local bound = table.pack(proxy:read(false))
    F.eq(bound.n, 3, 'bound trailing nil retained')
    F.eq(bound[1], 7, 'bound receiver retained')
    local first = proxy.read
    Parent.__dict.read = function(self)
        return self.value + 1
    end
    F.eq(proxy:read(), 8, 'updated method resolves dynamically')
    local updated = proxy.read
    F.eq(updated == first, false, 'wrapper updates only when method changes')
    F.eq(class.super(Child, Child, Parent).read, Parent.read, 'class target returns shared function')
    F.raises(function()
        S.runtime(proxy).value = 3
    end, 'TypeError', 'proxy remains readonly')
end)

F.test('deep hierarchies resolve from declaration class rather than most-derived override', function()
    ---@class _std_super.Base : std.object
    ---@overload fun():self
    local Base = class.new('_std_super.Base')
    function Base.level(_self)
        return 'base'
    end
    ---@class _std_super.Middle : _std_super.Base
    ---@overload fun():self
    local Middle = class.new('_std_super.Middle', Base)
    function Middle:level()
        return class.super(Middle, self, Base):level() .. ':middle'
    end
    ---@class _std_super.Leaf : _std_super.Middle
    ---@overload fun():self
    local Leaf = class.new('_std_super.Leaf', Middle)
    F.eq(Leaf():level(), 'base:middle', 'declaration owner prevents recursion')
end)
