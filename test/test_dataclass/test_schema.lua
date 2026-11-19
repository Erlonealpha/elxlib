local F = require 'mpv_luatest.framework'
local D = require 'elxlibs.dataclass'
local S = require 'test_dataclass.support'

F.section('dataclass definitions and shared methods')

F.test('standalone module imports without class or host dependencies', function()
    local loader = assert(loadfile(assert(debug.getinfo(D.field, 'S')).source:sub(2)))
    local required = {}
    setfenv(loader, setmetatable({require = function(name)
        required[#required + 1] = name
        error('unexpected dependency ' .. name)
    end}, {__index = _G}))
    local module = loader()
    local Type = module.new('Independent') {module.field('x', 3)}
    F.eq(Type().x, 3, 'loaded module constructs without production entry')
    F.eq(#required, 0, 'no require calls including std.class or mp')
end)

F.test('builder snapshots fields and options without mutating caller input', function()
    local config = {kw_init = true}
    local metadata = {unit = 'px'}
    local options = {default = 10, metadata = metadata}
    local first = D.field('x', nil, options)
    local declarations = {first, D.field('y')}
    local builder = D.new('_dataclass_test.Schema', nil, config)
    ---@class _dataclass_test.Schema
    ---@field x integer
    ---@field y integer
    ---@overload fun(values:table):self
    local Type = builder(declarations)
    first.default, config.kw_init = 99, false
    declarations[2] = D.field('different', 0)
    local obj = Type {y = 7}
    F.eq(obj.x, 10, 'field snapshot')
    F.eq(obj.y, 7, 'schema array snapshot and option snapshot')
    F.eq(options.default, 10, 'caller options unchanged')
    F.eq(options.init, nil, 'no default injection into caller options')
    local fields = D.fields(Type)
    F.eq(assert(fields[1]).metadata, metadata, 'metadata shallow shared')
    assert(fields[1]).default = -1
    F.eq(Type {y = 8}.x, 10, 'returned descriptors do not mutate schema')
    F.raises(function() builder({}) end, 'already been used', 'builder completes once')
end)

F.test('mutable objects use raw fields and dynamic shared methods', function()
    ---@class _dataclass_test.Direct
    ---@field x integer
    ---@overload fun(x:integer):self
    local Type = D.new('_dataclass_test.Direct') {D.field('x')}
    function Type:get() return self.x end
    local first, second = Type(2), Type(3)
    F.eq(rawget(first, 'x'), 2, 'baseline stores field directly')
    F.eq(rawget(first, '__dict'), nil, 'baseline has no backing dict')
    F.eq(getmetatable(first).__index, Type, 'direct shared class lookup')
    F.eq(getmetatable(first).__newindex, nil, 'baseline has no setter')
    F.eq(first.get, second.get, 'shared method identity')
    first.x = 9
    S.runtime(first).extra = 'extra'
    F.eq(second.x, 3, 'instance independence')
    F.eq(S.runtime(first).extra, 'extra', 'additional fields allowed')
    Type.get = function(self) return self.x * 2 end
    F.eq(first:get(), 18, 'ordinary methods remain dynamic after finish')
    F.eq(second:get(), 6, 'existing instances see shared method replacement')
end)

F.test('finish and first construction collect metamethods once', function()
    ---@class _dataclass_test.Printable
    ---@field x integer
    ---@overload fun():self
    local Type = D.new('_dataclass_test.Printable') {D.field('x', 1)}
    function Type.__tostring() return 'first' end
    F.eq(D.finish(Type), Type, 'explicit finish returns same class')
    Type.__tostring = function() return 'later' end
    F.eq(tostring(Type()), 'first', 'operator uses cached function')
    F.eq(Type():__tostring(), 'later', 'normal method lookup remains dynamic')
    F.eq(D.finish(Type), Type, 'finish is idempotent')
    F.eq(tostring(Type()), 'first', 'repeated finish does not refresh')
    ---@class _dataclass_test.Implicit
    ---@overload fun():self
    local Implicit = D.new('_dataclass_test.Implicit') {}
    function Implicit.__tostring() return 'implicit' end
    F.eq(tostring(Implicit()), 'implicit', 'first construction finishes class')
end)

F.test('single inheritance merges fields and inherits methods dynamically', function()
    ---@class _dataclass_test.Parent
    ---@field x integer
    ---@field y integer
    ---@overload fun():self
    local Parent = D.new('_dataclass_test.Parent') {D.field('x', 1), D.field('y', 2)}
    function Parent:get() return self.x end
    ---@class _dataclass_test.Child : _dataclass_test.Parent
    ---@field z integer
    ---@overload fun():self
    local Child = D.new('_dataclass_test.Child', Parent) {D.field('x', 8), D.field('z', 3)}
    local obj = Child()
    F.eq(obj:get(), 8, 'overridden field with inherited method')
    F.eq(obj.y, 2, 'inherited field default')
    F.eq(obj.z, 3, 'new field')
    F.eq(assert(D.fields(Child)[1]).name, 'x', 'override preserves declaration position')
    F.eq(assert(D.fields(Child)[2]).name, 'y', 'inherited field order')
    F.eq(Parent().x, 1, 'parent schema unchanged')
    Parent.get = function(self) return self.x + 1 end
    F.eq(obj:get(), 9, 'parent method replacement stays dynamic')
    F.eq(D.isclass(Child), true, 'class convention')
    F.eq(D.isclass({}), false, 'plain table not class')
    F.eq(D.isinstance(obj, Parent), true, 'parent instance relation')
    F.eq(D.isinstance(Parent(), Child), false, 'directional inheritance')
    F.eq(D.isinstance({}, Child), false, 'plain instance rejected')
    F.eq(D.issubclass(Child, Parent), true, 'subclass relation')
    F.eq(D.issubclass(Parent, Child), false, 'reverse subclass false')
end)

F.test('definition rejects malformed fields and unsupported options', function()
    local field = S.runtime(D.field)
    local new = S.runtime(D.new)
    F.raises(function() field('') end, 'field name', 'empty field')
    F.raises(function() field('__class') end, 'field name', 'reserved system prefix')
    F.raises(function() field('x', 1, {default = 2}) end, 'duplicate default', 'conflicting defaults')
    F.raises(function() field('x', nil, {default = 1, factory = function() end}) end,
        'default and factory conflict', 'factory and default conflict')
    F.raises(function() field('x', nil, {factory = 1}) end, 'must be a function', 'invalid factory')
    F.raises(function() field('x', nil, {init = 1}) end, 'must be a boolean', 'invalid field flag')
    F.raises(function() field('x', nil, false) end, 'options must be a table', 'false field options')
    F.raises(function() field('x', nil, {alias = 'z'}) end, 'unknown option', 'deferred field option')
    F.raises(function() new('Bad', nil, {slots = true}) end, 'unknown option', 'deferred class option')
    F.raises(function() new('Bad', nil, false) end, 'options must be a table', 'false class options')
    F.raises(function() new('', nil) end, 'class name', 'empty class name')
    F.raises(function() new('Bad', {}) end, 'expected a dataclass class', 'foreign parent')
    F.raises(function() new('Bad') {D.field('x'), D.field('x')} end, 'duplicate field', 'duplicate schema')
    F.raises(function() new('Bad') {{name = 'x'}} end, 'Field declarations', 'plain field table')
    F.raises(function() new('Bad') {[1] = D.field('x'), [3] = D.field('z')} end,
        'dense ordered array', 'sparse schema')
    F.raises(function() new('Bad') {D.field('x', 1), D.field('y')} end,
        'required field follows default', 'positional required ordering')
    F.raises(function() new('Bad', nil, {order = true, eq = false}) end,
        'order requires', 'order option dependency')
    F.raises(function() D.fields(S.runtime({})) end, 'expected a dataclass class', 'fields class check')
    F.raises(function() D.issubclass({}, {}) end, 'expected a dataclass class', 'subclass guard')
    F.raises(function() D.isinstance({}, {}) end, 'expected a dataclass class', 'instance class guard')
    local malformed = D.field('x', 1)
    malformed.init = S.runtime('invalid')
    F.raises(function() new('Malformed') {malformed} end, 'must be a boolean', 'changed descriptor revalidated')
    local conflict = D.field('items', nil, {factory = function() return {} end})
    conflict.default = 1
    F.raises(function() new('FieldConflict') {conflict} end, 'default and factory conflict',
        'modified factory descriptor does not silently discard default')
    local InvalidMeta = new('InvalidMeta') {}
    InvalidMeta.__add = true
    F.raises(function() D.finish(InvalidMeta) end, '__add must be a function', 'metamethod validation')
    InvalidMeta.__add = nil
    F.eq(D.isclass(D.finish(InvalidMeta)), true, 'failed finish can be corrected before construction')
end)

F.test('class and instance cycles are collectible without global registries', function()
    local weak = setmetatable({}, {__mode = 'v'})
    do
        local Type = S.runtime(D.new)('Collectible', nil, {frozen = true}) {D.field('x', 1)}
        local obj = Type()
        weak[1], weak[2] = Type, obj
    end
    collectgarbage('collect')
    collectgarbage('collect')
    F.eq(weak[1], nil, 'class released with owner-held schema')
    F.eq(weak[2], nil, 'instance released with backing storage')
end)

F.test('live instances own their class metadata and failed initialization is collectible', function()
    local weak = setmetatable({}, {__mode = 'v'})
    local live
    do
        local Type = S.runtime(D.new)('Owned') {D.field('x', 1)}
        live = Type()
        weak[1] = Type
    end
    collectgarbage('collect')
    F.eq(weak[1], live.__class, 'live instance retains its class')
    F.eq(live.x, 1, 'live data remains available after collection')
    local Failed = S.runtime(D.new)('Failed', nil, {frozen = true}) {D.field('x', 1)}
    function Failed:__post_init()
        weak[2] = self
        error('post failed')
    end
    F.raises(function() Failed() end, 'post failed', 'initialization failure propagated')
    collectgarbage('collect')
    collectgarbage('collect')
    F.eq(weak[2], nil, 'failed object has no registry owner')
end)
