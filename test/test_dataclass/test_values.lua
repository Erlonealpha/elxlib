local F = require 'mpv_luatest.framework'
local D = require 'elxlibs.dataclass'
local S = require 'test_dataclass.support'

F.section('dataclass comparison and data operations')

F.test('equality uses exact class identity and selected fields across freeze modes', function()
    ---@class _dataclass_test.Value
    ---@field x integer
    ---@field note string
    ---@overload fun(x:integer, note?:string):self
    local Type = D.new('_dataclass_test.Value') {D.field('x'), D.field('note', '', {eq = false})}
    local a, b = Type(1, 'a'), Type(1, 'b')
    F.eq(a == b, true, 'excluded eq field')
    F.eq(a == Type(2), false, 'different value')
    D.freeze(a)
    F.eq(a == b, true, 'shared equality function across mutable/frozen metatables')
    D.freeze(b)
    F.eq(a == b, true, 'frozen equal values')
    local Child = S.runtime(D.new)('ValueChild', Type) {}
    F.eq(a == Child(1), false, 'same data in subclass not equal')
    local Other = S.runtime(D.new)('_dataclass_test.Value') {D.field('x')}
    F.eq(a == Other(1), false, 'same class name is not same class identity')
    local Identity = S.runtime(D.new)('Identity', nil, {eq = false}) {D.field('x', 1)}
    F.eq(Identity() == Identity(), false, 'eq false uses table identity without inherited custom meta')
    local IdentityChild = S.runtime(D.new)('IdentityChild', Type, {eq = false}) {}
    F.eq(IdentityChild(1) == IdentityChild(1), false, 'parent generated equality is not inherited')
    F.eq(Child(1, 'a') == Child(1, 'b'), true, 'child generates its own field comparator')
end)

F.test('ordering is lexicographic with explicit type and field boundaries', function()
    ---@class _dataclass_test.Ordered
    ---@field x integer
    ---@field y integer
    ---@field ignored integer
    ---@overload fun(x:integer, y:integer, ignored?:integer):self
    local Type = D.new('_dataclass_test.Ordered', nil, {order = true}) {
        D.field('x'), D.field('y'), D.field('ignored', 0, {eq = false}),
    }
    F.eq(Type(1, 99) < Type(2, 0), true, 'first differing field decides')
    F.eq(Type(1, 2) < Type(1, 3), true, 'second field tie break')
    F.eq(Type(1, 2) <= Type(1, 2), true, 'inclusive equality')
    F.eq(Type(1, 2) < Type(1, 2), false, 'strict equality')
    F.eq(Type(1, 2, 99) <= Type(1, 2, -99), true, 'order follows field eq default')
    F.eq(Type(2, 0) > Type(1, 99), true, 'Lua reverse comparison')
    local left, right = Type(1, 0), Type(2, 0)
    D.freeze(left)
    F.eq(left < right, true, 'ordering works across storage modes')
    local Other = S.runtime(D.new)('OtherOrdered', nil, {order = true}) {D.field('x'), D.field('y')}
    F.raises(function() local _less = left < Other(2, 0) end, 'same class', 'cross class sorting rejected')
    F.raises(function() local _less = S.runtime(Type)(nil, 0) < right end, 'compare', 'nil not coerced to orderable value')
end)

F.test('custom comparison opts avoid generation conflicts and inherit shared metas', function()
    local Type = S.runtime(D.new)('CustomCompare', nil, {eq = false}) {D.field('x', 1)}
    function Type:__eq(other) return self.x == other.x end
    F.eq(Type() == Type(), true, 'custom equality retained')
    local Child = S.runtime(D.new)('CustomCompareChild', Type, {eq = false}) {}
    F.eq(Child() == Child(), true, 'explicit parent comparator inherited')
    local Conflict = S.runtime(D.new)('CompareConflict') {}
    function Conflict.__eq() return true end
    F.raises(function() D.finish(Conflict) end, 'eq=true conflicts', 'custom eq requires disabling generation')
    local OrderConflict = S.runtime(D.new)('OrderConflict', nil, {order = true}) {}
    function OrderConflict.__lt() return true end
    F.raises(function() D.finish(OrderConflict) end, 'order=true conflicts', 'custom ordering generation conflict')
end)

F.test('replace reconstructs, converts and validates without changing the source', function()
    local conversions, validations, posts = 0, 0, 0
    ---@class _dataclass_test.Replace
    ---@field x integer
    ---@field nil_value any
    ---@field computed integer
    ---@overload fun(values:table):self
    local Type = D.new('_dataclass_test.Replace', nil, {kw_init = true}) {
        D.field('x', 1, {converter = function(v)
            conversions = conversions + 1
            return v + 1
        end, validator = function(_, _, v)
            validations = validations + 1
            assert(v > 0, 'x must be positive')
        end}), D.field('nil_value', 'default'), D.field('computed', 0, {init = false}),
    }
    function Type:__post_init()
        posts = posts + 1
        self.computed = self.x * 2
    end
    local original = Type {x = 2}
    original.computed = -1
    local changes = {nil_value = D.NIL}
    local new = D.replace(original, changes)
    F.eq(new.x, 4, 'converter reruns on retained converted value')
    F.eq(new.nil_value, nil, 'replace clears with NIL sentinel')
    F.eq(new.computed, 8, 'init false field recomputed')
    F.eq(original.x, 3, 'source value unchanged')
    F.eq(original.nil_value, 'default', 'source optional unchanged')
    F.eq(original.computed, -1, 'source computed unchanged')
    F.eq(changes.nil_value, D.NIL, 'changes table unchanged')
    F.eq(conversions, 2, 'conversion every construction')
    F.eq(validations, 2, 'validation every construction')
    F.eq(posts, 2, 'post every construction')
    F.raises(function() D.replace(original, {x = -9}) end, 'x must be positive', 'replacement failure')
    F.eq(original.x, 3, 'failed replacement leaves source untouched')
    F.raises(function() D.replace(original, {computed = 7}) end, 'not an init field', 'computed replacement rejected')
    F.raises(function() D.replace(original, {other = 7}) end, 'unknown field', 'unknown replacement rejected')
    F.raises(function() D.replace(original, S.runtime(false)) end, 'requires a table', 'invalid changes')
end)

F.test('positional replace preserves nil and follows class frozen policy', function()
    ---@class _dataclass_test.ReplacePos
    ---@field first any
    ---@field last any
    ---@overload fun(first:any, last?:any):self
    local Type = D.new('_dataclass_test.ReplacePos') {D.field('first'), D.field('last', 'last')}
    local source = Type(nil, nil)
    D.freeze(source)
    local new = D.replace(source)
    F.eq(new.first, nil, 'retained required nil')
    F.eq(new.last, nil, 'retained trailing nil')
    F.eq(D.isfrozen(new), false, 'explicit instance freeze does not propagate')
    F.eq(rawequal(new, source), false, 'new instance identity')
    local Frozen = S.runtime(D.new)('ReplaceFrozen', nil, {frozen = true}) {D.field('x', 1)}
    F.eq(D.isfrozen(D.replace(Frozen(), {x = 2})), true, 'frozen class replacement remains frozen')
    F.eq(D.replace(Type(1), {last = D.MISSING}).last, 'last', 'MISSING replacement requests default')
    F.raises(function() D.replace({}) end, 'expected a dataclass instance', 'replacement instance guard')
end)

F.test('export is shallow, declared-only, and optionally retains nil sentinels', function()
    local nested = {}
    ---@class _dataclass_test.Export
    ---@field x any
    ---@field flag boolean
    ---@field nested table
    ---@overload fun(values?:table):self
    local Type = D.new('_dataclass_test.Export', nil, {kw_init = true}) {
        D.field('x', nil), D.field('flag', false), D.field('nested', nested),
    }
    local obj = Type()
    S.runtime(obj).extra = 7
    local dict = D.asdict(obj)
    F.eq(dict.x, nil, 'default export omits nil')
    F.eq(dict.flag, false, 'false exported')
    F.eq(dict.nested, nested, 'shallow export retains nested identity')
    F.eq(dict.extra, nil, 'only declared fields')
    F.eq(dict.__class, nil, 'no system identity exported')
    local explicit = D.asdict(obj, true)
    F.eq(explicit.x, D.NIL, 'sentinel preserves nil field presence')
    F.eq(Type(explicit) == obj, true, 'init field export can round trip')
    D.freeze(obj)
    F.eq(D.asdict(obj, true).x, D.NIL, 'frozen export identical contract')
    F.contains(tostring(obj), 'flag=false', 'default repr contains visible false')
    F.raises(function() D.asdict(S.runtime({})) end, 'expected a dataclass instance', 'export guard')
end)

F.test('repr supports exclusion, disabled generation, recursion and error recovery', function()
    local Type = S.runtime(D.new)('Repr') {D.field('x', nil), D.field('hidden', 'secret', {repr = false})}
    local obj = Type()
    F.eq(tostring(obj), 'Repr(x=nil)', 'repr shows nil but excludes hidden fields')
    obj.x = obj
    F.eq(tostring(obj), 'Repr(x=...)', 'self reference does not recurse forever')
    local broken = setmetatable({}, {__tostring = function() error('broken tostring') end})
    obj.x = broken
    F.raises(function() tostring(obj) end, 'broken tostring', 'nested tostring failure propagates')
    obj.x = 3
    F.eq(tostring(obj), 'Repr(x=3)', 'failed repr releases active instance guard')
    local Disabled = S.runtime(D.new)('NoRepr', nil, {repr = false}) {}
    F.contains(tostring(Disabled()), 'table:', 'repr false keeps Lua table repr')
end)
