local F = require 'mpv_luatest.framework'
local D = require 'elxlibs.dataclass'
local S = require 'test_dataclass.support'

F.section('dataclass initialization and freezing')

F.test('positional inputs distinguish omitted defaults, nil gaps and false', function()
    ---@class _dataclass_test.Positional
    ---@field first any
    ---@field second any
    ---@field last any
    ---@overload fun(first:any, second?:any, last?:any):self
    local Type = D.new('_dataclass_test.Positional') {
        D.field('first'), D.field('second', false), D.field('last', 'last'),
    }
    local obj = Type(nil, nil, nil)
    F.eq(obj.first, nil, 'explicit required nil accepted')
    F.eq(obj.second, nil, 'nil gap does not select default')
    F.eq(obj.last, nil, 'trailing nil preserved')
    F.eq(Type(false).first, false, 'false input retained')
    F.eq(Type(1).second, false, 'false default retained')
    F.eq(Type(1).last, 'last', 'omitted default used')
    F.eq(Type(1, D.MISSING).second, false, 'missing sentinel requests default')
    F.raises(function() S.runtime(Type)() end, 'missing required field first', 'required input missing')
    F.raises(function() S.runtime(Type)(1, 2, 3, 4) end, 'too many positional', 'extra input rejected')
end)

F.test('named inputs support nil sentinel and reject unknown or non-init fields', function()
    ---@class _dataclass_test.Named
    ---@field optional any
    ---@field required any
    ---@field computed any
    ---@overload fun(values:table):self
    local Type = D.new('_dataclass_test.Named', nil, {kw_init = true}) {
        D.field('optional', 'default'), D.field('required'),
        D.field('computed', 7, {init = false}),
    }
    local input = {optional = D.NIL, required = false}
    local obj = Type(input)
    F.eq(obj.optional, nil, 'named explicit nil')
    F.eq(obj.required, false, 'named false')
    F.eq(obj.computed, 7, 'init false default')
    F.eq(input.optional, D.NIL, 'input remains untouched')
    F.raises(function() Type {} end, 'missing required field required', 'named required')
    F.raises(function() Type {required = 1, other = 2} end, 'unknown field other', 'unknown keyword')
    F.raises(function() Type {required = 1, computed = 9} end, 'not an init field', 'init false input')
    F.raises(function() S.runtime(Type)(nil) end, 'requires a table', 'explicit nil keyword table')
    F.raises(function() S.runtime(Type)({}, {}) end, 'accepts one table', 'extra keyword table')
end)

F.test('default syntax preserves nil and separates shared values from factories', function()
    local shared = {}
    ---@class _dataclass_test.Defaults
    ---@field nil_value any
    ---@field option_nil any
    ---@field option_value string
    ---@field shared table
    ---@field fresh table
    ---@overload fun():self
    local Type = D.new('_dataclass_test.Defaults') {
        D.field('nil_value', nil), D.field('option_nil', nil, {default = D.NIL}),
        D.field('option_value', nil, {default = 'option'}), D.field('shared', shared),
        D.field('fresh', nil, {factory = function() return {} end}),
    }
    local a, b = Type(), Type()
    F.eq(a.nil_value, nil, 'explicit nil default survives schema copy')
    F.eq(a.option_nil, nil, 'options nil sentinel default survives schema copy')
    F.eq(a.option_value, 'option', 'nil placeholder with options default')
    F.eq(a.shared, shared, 'table defaults shared by reference')
    F.eq(a.shared, b.shared, 'same default on every instance')
    F.eq(rawequal(a.fresh, b.fresh), false, 'fresh factory table')
end)

F.test('generated lifecycle converts first, then validates all fields, then post', function()
    local events = {}
    ---@class _dataclass_test.Lifecycle : dataclass.Object
    ---@field x integer
    ---@field y integer
    ---@field total integer
    ---@overload fun(x:string|number):self
    local Type = D.new('_dataclass_test.Lifecycle') {
        D.field('x', D.MISSING, {converter = function(v)
            events[#events + 1] = 'convert'
            return assert(tonumber(v))
        end, validator = function(self, field, value)
            ---@cast self _dataclass_test.Lifecycle
            events[#events + 1] = 'validate'
            assert(self.y == 2 and field.name == 'x' and value > 0, 'invalid x')
        end}), D.field('y', 2), D.field('total', nil, {init = false}),
    }
    function Type.__pre_init() events[#events + 1] = 'pre' end
    function Type:__post_init()
        events[#events + 1] = 'post'
        self.total = self.x + self.y
    end
    local obj = Type('3')
    F.eq(table.concat(events, ','), 'pre,convert,validate,post', 'lifecycle order')
    F.eq(obj.total, 5, 'post can use all converted fields')
    events = {}
    obj.x = -7
    F.eq(#events, 0, 'ordinary mutable assignment does not run hooks')
    F.raises(function() Type(-1) end, 'invalid x', 'validator failure propagates')
    F.eq(table.concat(events, ','), 'pre,convert,validate', 'post skipped on failure')
end)

F.test('custom init can delegate once to generated init and custom new only allocates', function()
    local init_count, pre_count, allocation_count = 0, 0, 0
    ---@class _dataclass_test.CustomInit : dataclass.Object
    ---@field x integer
    ---@overload fun(x:integer):self
    local Type = D.new('_dataclass_test.CustomInit', nil, {init = false}) {D.field('x')}
    function Type.__pre_init() pre_count = pre_count + 1 end
    function Type:__new()
        allocation_count = allocation_count + 1
        return D.allocate(self)
    end
    function Type:__init(x)
        init_count = init_count + 1
        self:__dataclass_init(x * 2)
    end
    local obj = Type(3)
    F.eq(obj.x, 6, 'custom init delegates to generated initializer')
    F.eq(init_count, 1, 'custom initializer called once')
    F.eq(pre_count, 1, 'generated hooks called once')
    F.eq(allocation_count, 1, 'allocator called once')
    F.eq(obj.__class, Type, 'allocated object class convention')
    Type.__init = function(self) self.x = 99 end
    F.eq(Type(4).x, 8, 'initializer cached at finish')
    local Auto = S.runtime(D.new)('Auto') {D.field('x')}
    function Auto:__init(x) self:__dataclass_init(x + 1) end
    F.eq(Auto(4).x, 5, 'own custom init detected when init option omitted')
    local Disabled = S.runtime(D.new)('Disabled', nil, {init = false}) {D.field('x', 1)}
    F.eq(Disabled().x, nil, 'init false without custom init does not initialize')
    local Conflict = S.runtime(D.new)('Conflict', nil, {init = true}) {}
    function Conflict.__init() end
    F.raises(function() D.finish(Conflict) end, 'init=true conflicts', 'explicit generation conflict')
    local BadNew = S.runtime(D.new)('BadNew') {}
    function BadNew.__new() return nil end
    F.raises(function() BadNew() end, '__new must return an instance', 'allocator nil is not default allocation')
    local Foreign = S.runtime(D.new)('ForeignNew') {}
    local WrongNew = S.runtime(D.new)('WrongNew') {}
    function WrongNew.__new() return Foreign() end
    F.raises(function() WrongNew() end, '__new must return an instance', 'allocator foreign class rejected')
end)

F.test('parent fields initialize once and parent hooks require explicit chaining', function()
    local parent_inits, parent_posts = 0, 0
    local Parent = S.runtime(D.new)('InitParent') {D.field('x', 2)}
    function Parent.__init() parent_inits = parent_inits + 1 end
    function Parent.__post_init() parent_posts = parent_posts + 1 end
    local Child = S.runtime(D.new)('InitChild', Parent) {D.field('y', 3)}
    function Child:__post_init() Parent.__post_init(self) end
    local obj = Child()
    F.eq(obj.x + obj.y, 5, 'merged field initializer')
    F.eq(parent_inits, 0, 'parent custom init not implicitly invoked')
    F.eq(parent_posts, 1, 'post explicitly chained once')
end)

F.test('frozen classes restrict hooks and ordinary writes from allocation onward', function()
    ---@class _dataclass_test.Frozen
    ---@field x integer
    ---@field nested table
    ---@overload fun():self
    local Type = D.new('_dataclass_test.Frozen', nil, {frozen = true}) {
        D.field('x', 1), D.field('nested', nil, {factory = function() return {} end}),
    }
    local obj = Type()
    F.eq(obj.x, 1, 'generated internal writer initializes frozen fields')
    F.eq(rawget(obj, 'x'), nil, 'frozen data stored separately')
    F.eq(D.isfrozen(obj), true, 'frozen class instance')
    F.raises(function() obj.x = 2 end, 'cannot assign frozen', 'existing field write')
    F.raises(function() obj.x = nil end, 'cannot assign frozen', 'existing field deletion')
    F.raises(function() S.runtime(obj).extra = 1 end, 'cannot assign frozen', 'new field write')
    obj.nested.key = 3
    F.eq(obj.nested.key, 3, 'shallow freeze allows nested mutation')
    for _, hook in ipairs({'__pre_init', '__post_init', '__init'}) do
        local Restricted = S.runtime(D.new)('Restricted' .. hook, nil, {frozen = true}) {D.field('x', 1)}
        Restricted[hook] = function(self) self.x = 2 end
        F.raises(function() Restricted() end, 'cannot assign frozen', hook .. ' ordinary assignment restricted')
    end
    local Child = S.runtime(D.new)('FrozenChild', Type, {frozen = false}) {}
    F.eq(D.isfrozen(Child()), true, 'frozen parent cannot be unfrozen by subclass option')
    local Custom = S.runtime(D.new)('FrozenCustom', nil, {frozen = true, init = false}) {D.field('x')}
    function Custom:__init(x) self:__dataclass_init(x) end
    F.eq(Custom(8).x, 8, 'frozen custom init explicitly delegates to internal writer')
    rawset(obj, 'x', 9)
    F.eq(obj.x, 9, 'rawset is a trusted escape, not a security boundary')
end)

F.test('explicit freeze migrates fields in place without freezing nested objects', function()
    ---@class _dataclass_test.Freeze
    ---@field x integer
    ---@field nested table
    ---@overload fun():self
    local Type = D.new('_dataclass_test.Freeze') {D.field('x', 1), D.field('nested', {})}
    function Type:get() return self.x end
    local obj = Type()
    S.runtime(obj).extra = false
    local alias, nested = obj, obj.nested
    F.eq(D.isfrozen(obj), false, 'initially mutable')
    F.eq(rawequal(D.freeze(obj), alias), true, 'freeze preserves identity')
    F.eq(D.isfrozen(alias), true, 'aliases see frozen mode')
    F.eq(alias:get(), 1, 'shared methods retained')
    F.eq(S.runtime(alias).extra, false, 'extra false field migrated')
    F.eq(alias.nested, nested, 'nested reference preserved')
    F.eq(rawget(alias, 'x'), nil, 'raw data layout changes on freeze')
    F.eq(D.freeze(alias), alias, 'freeze idempotent')
    F.raises(function() alias.x = 9 end, 'cannot assign frozen', 'alias mutation denied')
    F.eq(D.isfrozen(Type()), false, 'class default remains mutable')
    F.raises(function() D.freeze({}) end, 'expected a dataclass instance', 'freeze requires instance')
    F.raises(function() D.isfrozen(S.runtime({})) end, 'expected a dataclass instance', 'isfrozen guard')
end)

F.test('cached constructors keep each class allocator and initialization independent', function()
    local Mutable = S.runtime(D.new)('CachedMutable') {D.field('x', 1)}
    local Frozen = S.runtime(D.new)('CachedFrozen', nil, {frozen = true}) {D.field('x', 2)}
    local Named = S.runtime(D.new)('CachedNamed', nil, {kw_init = true}) {D.field('x', 3)}
    local Child = S.runtime(D.new)('CachedChild', Mutable) {D.field('y', 4)}
    D.finish(Frozen)
    D.finish(Child)
    for _ = 1, 2 do
        local a, b, c, d = Mutable(), Frozen(), Named {x = 9}, Child()
        F.eq(a.x, 1, 'mutable default remains distinct')
        F.eq(b.x, 2, 'frozen default remains distinct')
        F.eq(c.x, 9, 'named constructor remains distinct')
        F.eq(d.x + d.y, 5, 'subclass merges its own fields')
        F.eq(D.isfrozen(a), false, 'mutable allocator remains direct')
        F.eq(D.isfrozen(b), true, 'frozen allocator remains constrained')
        F.eq(D.isinstance(d, Child), true, 'subclass allocates its own identity')
        F.eq(D.isinstance(a, Child), false, 'parent allocator remains independent')
    end
end)

F.test('custom allocation preserves argument nils and initialization adapts to a pre-hook freeze', function()
    local args = {n = 0}
    local Type = S.runtime(D.new)('AllocationArgs') {D.field('x'), D.field('y', 5)}
    function Type:__new(...)
        args = {n = select('#', ...), ...}
        return D.allocate(self)
    end
    function Type:__pre_init() D.freeze(self) end
    local first = Type(false, nil)
    F.eq(args.n, 2, 'custom allocator receives trailing nil')
    F.eq(args[1], false, 'custom allocator receives false')
    F.eq(first.x, false, 'generated writer runs after pre-hook chooses frozen storage')
    F.eq(first.y, nil, 'generated writer preserves trailing nil')
    F.eq(D.isfrozen(first), true, 'pre-hook froze allocated instance')
    F.eq(rawget(first, 'x'), nil, 'initializer writes backing data after pre-hook')
    F.raises(function() first.x = 1 end, 'cannot assign frozen', 'pre-hook freeze remains effective')
    local second = Type(2)
    F.eq(args.n, 1, 'cached custom allocation keeps actual argument count')
    F.eq(second.y, 5, 'omitted input still selects default')
    F.eq(rawequal(first, second), false, 'cached allocator always returns new instance')
end)

F.test('validators see every initialized field even across non-init declarations', function()
    local events = {}
    local Type = S.runtime(D.new)('ValidatorPlan', nil, {kw_init = true}) {
        D.field('first', 1), D.field('computed', nil, {init = false}),
        D.field('last', nil, {validator = function(self, field, value)
            events[#events + 1] = 'last'
            assert(S.runtime(self).first == 1 and value == nil, 'all fields initialized')
            field.name = 'changed only in copy'
        end}),
    }
    function Type:__post_init() self.computed = 7 end
    local first, second = Type(), Type()
    F.eq(table.concat(events, ','), 'last,last', 'only participating validators run in declaration order')
    F.eq(first.computed, 7, 'post follows complete validation')
    F.eq(second.last, nil, 'validator descriptor mutation does not alter schema')
    F.eq(assert(D.fields(Type)[3]).name, 'last', 'validator received a fresh descriptor')
end)
