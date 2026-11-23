local F = require 'mpv_luatest.framework'
local std = require 'elxlibs.std'
local class = std.class
local S = require 'test_std.support'

F.section('std class and reflection')

F.test('classof belongs to class and kind guards return false for unknown identities', function()
    ---@class _std_test.Identity : std.object
    ---@overload fun(): self
    local Type = class.new('_std_test.Identity')
    local obj = Type()

    F.eq(std.classof, class.classof, 'aggregate shares classof')
    F.eq(class.classof(obj), Type, 'instance class identity')
    F.eq(class.classof(Type), nil, 'class is not an instance')
    F.eq(class.classof({}), nil, 'plain table has no class')
    F.eq(class.classof(S.runtime({__class = {}})), nil, 'malformed marker rejected')
    F.eq(class.classof(S.runtime({__class = Type})), Type, 'valid marker follows trust convention')
    F.eq(class.classof(false), nil, 'non-table input has no class')
    F.eq(class.kindof({}, 'object'), false, 'plain table object guard is boolean')
    F.eq(class.kindof(nil, 'class'), false, 'nil class guard is boolean')
    F.eq(class.kindof(false, 'object'), false, 'false object guard is boolean')
    F.eq(class.kindof(S.runtime({__class = {}}), 'object'), false, 'malformed identity guard is false')
    F.eq(class.kindof({}), nil, 'unfiltered unknown identity remains nil')
end)

F.test('direct inheritance initializes instances and resolves overridden members', function()
    ---@class _std_test.Base : std.object
    ---@field value integer
    ---@overload fun(value:integer):self
    local Base = class.new('_std_test.Base')
    function Base:__init(value) self.value = value end
    function Base:get() return self.value end
    ---@class _std_test.Child : _std_test.Base
    ---@overload fun(value:integer):self
    local Child = class.new('_std_test.Child', Base)
    function Child:__init(value) std.super(Child, self, Base):__init(value + 1) end
    function Child:get() return math.floor(std.super(Child, self, Base):get() * 2) end
    local first, second = Child(3), Child(7)
    F.eq(first:get(), 8, 'override uses parent method')
    F.eq(second:get(), 16, 'independent instance state')
    first.value = 20
    F.eq(second.value, 8, 'instance mutation isolated')
    F.eq(std.kindof(Base), 'class', 'class reflection')
    F.eq(std.kindof(first), 'object', 'instance reflection')
    F.eq(std.kindof({}), nil, 'plain table is not an instance')
    F.eq(std.kindof(first, 'class'), false, 'kind guard')
    F.eq(std.issubclass(Child, Base), true, 'parent relation')
    F.eq(std.issubclass(Base, Child), false, 'directional relation')
    F.eq(std.issubclass(Child, class.object), true, 'root relation')
    F.eq(std.isinstance(first, Base), true, 'base instance check')
    F.eq(std.isinstance(first, S.runtime({Base, Child})), true, 'class list check')
    F.eq(std.isinstance({}, Base), false, 'plain table rejected')
    F.contains(tostring(Base), '_std_test.Base', 'class representation')
    F.contains(tostring(first), '_std_test.Child', 'default object representation')
    F.eq(getmetatable(first), 'protected', 'instance metatable protected')
    F.eq(pcall(setmetatable, first, {}), false, 'cannot replace instance metatable')
end)

F.test('metamethods inherit and remain cached after first construction', function()
    ---@class _std_test.Printable : std.object
    ---@overload fun():self
    local Printable = class.new('_std_test.Printable')
    Printable.__dict.__tostring = function() return 'original' end
    ---@class _std_test.PrintChild : _std_test.Printable
    ---@overload fun():self
    local Child = class.new('_std_test.PrintChild', Printable)
    local first = Child()
    F.eq(tostring(first), 'original', 'inherited metamethod')
    Printable.__dict.__tostring = function() return 'changed' end
    F.eq(tostring(Child()), 'original', 'cached instance metatable is intentional')
    F.eq(first:__tostring(), 'changed', 'normal member lookup remains dynamic')
end)

F.test('final/abstract classes enforce construction and inheritance boundaries', function()
    ---@class _std_test.Abstract : std.object
    ---@overload fun():self
    local Abstract = S.runtime(class.new_abstract)('_std_test.Abstract')
    ---@class _std_test.Final : std.object
    ---@overload fun():self
    local Final = S.runtime(class.new_final)('_std_test.Final')
    F.eq(class.isabstract(Abstract), true, 'abstract flag')
    F.eq(class.isfinal(Final), true, 'final flag')
    F.raises(function() Abstract() end, 'TypeError', 'abstract cannot instantiate')
    F.raises(function() S.runtime(class.new)('ForbiddenChild', Final) end, 'TypeError', 'final cannot derive')
    ---@class _std_test.Concrete : _std_test.Abstract
    ---@overload fun():self
    local Concrete = class.new('_std_test.Concrete', Abstract)
    F.eq(class.isabstract(Concrete), false, 'derived concrete class')
    F.eq(std.isinstance(Concrete(), Abstract), true, 'concrete inherits abstract')
    F.eq(std.isinstance(Final(), Final), true, 'final can instantiate')
    F.raises(function() class.isabstract(S.runtime({})) end, 'TypeError', 'abstract guard rejects plain table')
    F.raises(function() class.isfinal(S.runtime({})) end, 'TypeError', 'final guard rejects plain table')
end)

F.test('super supports bound and explicit-self calls and rejects invalid hierarchies', function()
    ---@class _std_test.Parent : std.object
    ---@field value integer
    ---@overload fun():self
    local Parent = class.new('_std_test.Parent')
    function Parent:read() return self.value end
    ---@class _std_test.Derived : _std_test.Parent
    ---@overload fun():self
    local Derived = class.new('_std_test.Derived', Parent)
    local obj = Derived()
    obj.value = 9
    local proxy = std.super(Derived, obj, Parent)
    F.eq(proxy:read(), 9, 'bound call')
    F.eq(proxy.read(obj), 9, 'explicit self call')
    F.eq(std.super(Derived, Derived, Parent).read(obj), 9, 'class hierarchy proxy')
    F.raises(function() S.runtime(proxy).value = 1 end, 'TypeError', 'super proxy immutable')
    F.raises(function() std.super(class.object) end, 'TypeError', 'root has no parent')
    F.raises(function() std.super(S.runtime({}), obj) end, 'TypeError', 'invalid class rejected')
    F.raises(function() std.super(Derived, S.runtime({})) end, 'TypeError', 'invalid target rejected')
    F.raises(function() std.super(Derived, Parent()) end, 'TypeError', 'foreign hierarchy rejected')
    F.raises(function() std.issubclass(S.runtime({}), Parent) end, 'TypeError', 'invalid subclass rejected')
end)

F.test('reflection metadata survives collection while objects remain live', function()
    ---@class _std_test.Live : std.object
    ---@overload fun():self
    local Type = class.new('_std_test.Live')
    local object = Type()
    collectgarbage('collect')
    F.eq(std.kindof(object), 'object', 'instance metadata retained')
    F.eq(std.isinstance(object, Type), true, 'class metadata retained')
    F.eq(std.issubclass(Type, class.object), true, 'hierarchy retained')
end)
