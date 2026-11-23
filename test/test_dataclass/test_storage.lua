local F = require 'mpv_luatest.framework'
local D = require 'elxlibs.dataclass'
local S = require 'test_dataclass.support'

F.section('dataclass storage options and identity boundaries')

F.test('mutable dict storage supports field writes, shared methods and shallow freeze', function()
    ---@class _dataclass_test.DictStorage : dataclass.Object
    ---@field x integer
    ---@field flag boolean
    ---@field optional any
    ---@overload fun(values?:table):self
    local Type = D.new('_dataclass_test.DictStorage', nil, {dict = true, kw_init = true}) {
        D.field('x', 1), D.field('flag', false), D.field('optional', nil),
    }
    function Type:get() return self.x end
    local a, b = Type(), Type()
    local backing = assert(rawget(a, '__dict'))
    F.eq(rawget(a, 'x'), nil, 'dict fields live outside the shell')
    F.eq(backing.x, 1, 'backing table receives generated defaults')
    F.eq(a.flag, false, 'false does not fall through to class lookup')
    F.eq(a.optional, nil, 'nil default retained')
    F.eq(a.get, b.get, 'dict instances share class methods')
    F.eq(D.isfrozen(a), false, 'dict storage alone is mutable')
    a.x = 2
    S.runtime(a).extra = false
    F.eq(backing.x, 2, 'existing write updates dict')
    F.eq(backing.extra, false, 'new false field updates dict')
    F.eq(b.x, 1, 'other instance data unchanged')
    a.optional = 'set'
    a.optional = nil
    F.eq(backing.optional, nil, 'deletion updates dict')
    Type.get = function(self) return self.x * 2 end
    F.eq(a:get(), 4, 'method lookup remains dynamic')
    F.eq(D.asdict(a).x, 2, 'export reads dict values')
    F.eq(rawequal(D.freeze(a), a), true, 'dict freeze keeps identity')
    F.eq(rawget(a, '__dict'), backing, 'dict freeze reuses backing table')
    F.eq(D.isfrozen(a), true, 'instance reports actual frozen state')
    F.eq(D.isfrozen(b), false, 'other dict instance stays mutable')
    F.raises(function() a.x = 7 end, 'cannot assign frozen', 'existing frozen dict write rejected')
    F.raises(function() a.x = nil end, 'cannot assign frozen', 'frozen dict deletion rejected')
    F.raises(function() S.runtime(a).new_field = 7 end, 'cannot assign frozen', 'new frozen dict field rejected')
    F.eq(D.freeze(a), a, 'repeated dict freeze idempotent')
    local replacement = D.replace(a, {x = 3})
    F.eq(D.isfrozen(replacement), false, 'replacement follows mutable class policy')
    F.eq(assert(rawget(replacement, '__dict')).x, 3, 'replacement follows dict class policy')
end)

F.test('frozen selects dict storage without rewriting caller or stored options', function()
    for _, explicit_dict in ipairs({false, true}) do
        local options = {frozen = true, dict = explicit_dict}
        local Type = S.runtime(D.new)('EffectiveDict' .. tostring(explicit_dict), nil, options) {
            D.field('x', 1), D.field('flag', false),
        }
        local obj = Type()
        F.eq(options.dict, explicit_dict, 'caller dict option preserved')
        F.eq(options.frozen, true, 'caller frozen option preserved')
        F.eq(Type.__dataclass.opts.dict, explicit_dict, 'stored dict option preserved')
        F.eq(rawget(obj, 'x'), nil, 'effective backend uses dict even with dict=false')
        F.eq(rawget(obj, '__dict').x, 1, 'generated writer initializes effective backend')
        F.eq(D.isfrozen(obj), true, 'allocated object is frozen')
        F.raises(function() obj.flag = true end, 'cannot assign frozen', 'existing false field is frozen')
        F.eq(Type().x, 1, 'later allocations use same frozen backend')
        local replacement = D.replace(obj, {x = 3})
        F.eq(D.isfrozen(replacement), true, 'replacement follows frozen class policy')
        F.eq(rawget(replacement, 'x'), nil, 'replacement also uses effective dict backend')
    end
    local options = {frozen = true}
    local Type = S.runtime(D.new)('ImplicitEffectiveDict', nil, options) {D.field('x', 1)}
    Type()
    F.eq(options.dict, nil, 'omitted caller option is not injected')
    F.eq(Type.__dataclass.opts.dict, false, 'omitted dict option keeps its default')
    local Child = S.runtime(D.new)('InheritedEffectiveDict', Type, {dict = false}) {D.field('y', 2)}
    local obj = Child()
    F.eq(obj.x + obj.y, 3, 'frozen child merges inherited fields')
    F.eq(Child.__dataclass.opts.dict, false, 'frozen child preserves its dict choice')
    F.eq(D.isfrozen(obj), true, 'inherited frozen policy uses effective dict storage')
    F.raises(function() obj.y = 4 end, 'cannot assign frozen', 'child field is frozen')
end)

F.test('explicit freeze changes only instance storage and preserves shared metas', function()
    local options = {dict = false, frozen = false, order = true}
    local Type = S.runtime(D.new)('StorageMigration', nil, options) {D.field('x', 1)}
    local a, b = Type(), Type()
    F.eq(a == b, true, 'equal values before freeze')
    D.freeze(a)
    F.eq(D.isfrozen(a), true, 'frozen alias reports true')
    F.eq(D.isfrozen(b), false, 'unfrozen peer reports false')
    F.eq(Type.__dataclass.opts.frozen, false, 'class frozen option unchanged')
    F.eq(Type.__dataclass.opts.dict, false, 'class dict option unchanged')
    F.eq(options.frozen, false, 'caller frozen option unchanged')
    F.eq(options.dict, false, 'caller dict option unchanged')
    F.eq(a == b, true, 'equality function identity preserved across metas')
    F.eq(a <= b, true, 'ordering function identity preserved across metas')
    F.eq(rawget(a, 'x'), nil, 'direct field migrated out of shell')
    F.eq(rawget(b, 'x'), 1, 'peer remains direct')
end)

F.test('generated initialization uses the backend returned by a custom allocator', function()
    ---@class _dataclass_test.CustomDict : dataclass.Object
    ---@field x integer
    ---@overload fun(x:integer):self
    local Type = D.new('_dataclass_test.CustomDict', nil, {init = false}) {D.field('x')}
    function Type:__new()
        return setmetatable({__class = self, __dict = {}}, {
            __index = function(obj, key)
                local value = rawget(obj, '__dict')[key]
                if value ~= nil then return value end
                return self[key]
            end,
        })
    end
    function Type:__init(x) self:__dataclass_init(x) end
    local obj = Type(7)
    F.eq(obj.x, 7, 'custom dict lookup sees initialized value')
    F.eq(rawget(obj, 'x'), nil, 'initializer did not write into the shell')
    F.eq(assert(rawget(obj, '__dict')).x, 7, 'initializer used actual backing storage')
end)

F.test('fields_set exposes shared ordered names including inherited and non-init fields', function()
    local options = {fields_set = true}
    local Parent = S.runtime(D.new)('FieldNamesParent', nil, options) {
        D.field('x', 1), D.field('computed', nil, {init = false}),
    }
    F.eq(rawget(Parent, '__fields_set'), nil, 'field names are collected at finish')
    D.finish(Parent)
    local names = Parent.__fields_set
    F.eq(#names, 2, 'all declared fields included')
    F.eq(names[1], 'x', 'declaration order retained')
    F.eq(names[2], 'computed', 'non-init field included')
    F.eq(Parent().__fields_set, names, 'instances share class field names')
    F.eq(rawget(Parent(), '__fields_set'), nil, 'no per-instance field array')
    F.eq(options.fields_set, true, 'caller option preserved')
    local Child = S.runtime(D.new)('FieldNamesChild', Parent, {fields_set = true, frozen = true}) {
        D.field('x', 9), D.field('y', 3),
    }
    local child = Child()
    F.eq(#child.__fields_set, 3, 'child includes inherited fields and new field')
    F.eq(child.__fields_set[1], 'x', 'override keeps parent position')
    F.eq(child.__fields_set[3], 'y', 'new field appended')
    F.eq(#names, 2, 'child field list does not mutate parent list')
    local Default = S.runtime(D.new)('NoFieldNames') {}
    F.eq(Default().__fields_set, nil, 'disabled by default')
    local Empty = S.runtime(D.new)('EmptyFieldNames', nil, {fields_set = true}) {}
    F.eq(#Empty().__fields_set, 0, 'empty schema produces empty list')
    local Conflict = S.runtime(D.new)('FailedFieldNames', nil, {fields_set = true, init = true}) {}
    function Conflict.__init() end
    F.raises(function() D.finish(Conflict) end, 'init=true conflicts', 'failed finish propagates error')
    F.eq(rawget(Conflict, '__fields_set'), nil, 'failed finish does not publish partial field names')
end)

F.test('new option types and public class or instance boundaries reject invalid values', function()
    local new = S.runtime(D.new)
    F.raises(function() new('BadDict', nil, {dict = 1}) end, 'dict must be a boolean', 'dict option type')
    F.raises(function() new('BadFieldNames', nil, {fields_set = 1}) end,
        'fields_set must be a boolean', 'fields_set option type')
    local Type = new('IdentityShape') {}
    for _, invalid_class in ipairs({false, 1, 'class', {}, {__dataclass = true, __name = 'Bad'}}) do
        F.eq(D.isinstance({__class = invalid_class}, Type), false, 'invalid identity marker is not an instance')
    end
    F.eq(D.isinstance({__class = Type}, Type), true, 'valid convention can be forged without registration')
    for _, invalid in ipairs({false, 1, 'class', {}}) do
        F.raises(function() D.fields(S.runtime(invalid)) end, 'expected a dataclass class', 'class boundary')
    end
    F.raises(function() D.freeze({__class = false}) end, 'expected a dataclass instance', 'freeze identity boundary')
    F.raises(function() D.isfrozen(S.runtime({__class = {}})) end,
        'expected a dataclass instance', 'isfrozen identity boundary')
end)
