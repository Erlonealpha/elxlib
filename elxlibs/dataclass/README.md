# Independent dataclass

`require 'elxlibs.dataclass'` provides shared-method data classes on bare LuaJIT.
It imports no host modules or `std.class`, and its instances have their own type
identity. The API borrows field declarations and initialization behavior from
[Python attrs](https://www.attrs.org/en/stable/), with Lua-specific storage and nil rules.

```lua
local dc = require 'elxlibs.dataclass'

---@class Point
---@field x number
---@field y number
---@overload fun(values?:{x?:number, y?:number}):self
local Point = dc.new('Point', nil, {kw_init = true, order = true}) {
    dc.field('x', 0),
    dc.field('y', 0),
}

function Point:distance_squared()
    return self.x * self.x + self.y * self.y
end

dc.finish(Point) -- optional; the first Point(...) also finishes the class
local p = Point {x = 3, y = 4}
assert(p:distance_squared() == 25)
local q = dc.replace(p, {x = 6})
dc.freeze(p) -- shallow, in place; p keeps its identity
local data = dc.asdict(q)
```

`new(name, parent?, opts?)` returns a one-use definition function accepting an
ordered `Field[]`. The result is the class; subsequent class calls construct
instances. The parent must be another independent dataclass. Inherited fields
come first; a child declaration replaces a same-name field in its original
position. Parent fields and caller configuration are not modified.

Runtime fields do not generate static annotations. Declare `---@class`,
`---@field` and `---@overload` explicitly; `new` preserves the named type so
methods defined on the returned class remain discoverable. `dataclass.Object`
is an optional annotation base for initialization hooks and `__dataclass_init`.

## Fields and input

| Declaration | Meaning |
| --- | --- |
| `field('x')` or `field('x', dc.MISSING)` | Required input |
| `field('x', nil)` | Default nil |
| `field('x', false)` | Default false |
| `field('x', nil, {default = 'value'})` | Default from options |
| `field('x', nil, {default = dc.NIL})` | Default nil from options |
| `field('items', nil, {factory = function() return {} end})` | Fresh default on each construction |

Defaults are shared references; tables are not copied. `factory()` receives no
arguments. A non-nil second default conflicts with options `default` or
`factory`; `default` and `factory` also conflict with each other. Names must be
nonempty strings and cannot start with `__`, which is reserved for runtime state
and hooks. Duplicate declarations and unknown options raise Lua errors.

Field options are `default`, `factory`, `init` (default true), `eq` (true),
`order` (defaults to the field's `eq`), `repr` (true), `converter`, `validator`
and `metadata`. `converter(value)` returns the new value;
`validator(self, field, value)` raises on failure, and its return value is ignored.
Validators receive shallow descriptor copies. `metadata` is a shared table and
does not alter runtime behavior. `fields(cls)` returns ordered descriptor copies;
default values and metadata remain shallow shared references.

With `kw_init=false` (default), arguments follow declaration order, excluding
`init=false` fields. Explicit nils, including trailing nils, count as supplied
arguments. Required fields cannot follow defaults, including inherited defaults.
With `kw_init=true`, pass one named table or no arguments for an empty table.
Unknown keys and `init=false` inputs are rejected. Lua removes nil-valued keys,
so use `dc.NIL` to supply nil and `dc.MISSING` to request the default. Inputs are
not modified. An `init=false` field uses its default/factory or nil when neither
is supplied.

## Initialization and class completion

Class options default to `frozen=false`, `eq=true`, `order=false`, `repr=true`
and `kw_init=false`. `order=true` requires `eq=true`. Unknown options are rejected.

`finish(cls)` caches the constructor, hooks and supported LuaJIT metamethods.
First construction calls it automatically. Repeated finish returns the same
class without refreshing. Define hooks and metamethods before finishing.
Ordinary shared methods and inherited methods continue to resolve dynamically;
changing a metamethod after finish affects direct member calls, while operators
use the cached function. Structural `__index`/`__newindex` belong to the storage
backend. Table finalizers are not supplied.

Generated initialization runs `__pre_init(self)`, resolves and converts fields
in order, writes all fields, runs all validators, then calls `__post_init(self)`.
Exceptions propagate and skip the remaining steps. No successful instance is
returned on failure. Parent fields are initialized by the child's generated
initializer; parent `__init` is not automatically called. Hooks are inherited
normally; a child overriding a hook explicitly calls the parent when chaining
is wanted.

When `init` is omitted, an own custom `__init` is detected at finish and used.
`init=true` requests generation and conflicts with an own custom initializer;
`init=false` uses the own initializer or leaves the object uninitialized.
`__dataclass_init` always exposes generated initialization for explicit delegation:

```lua
---@class Scaled : dataclass.Object
---@field x number
---@overload fun(x:number):self
local Scaled = dc.new('Scaled', nil, {init = false}) {dc.field('x')}
function Scaled:__init(x)
    self:__dataclass_init(x * 2)
end
```

A custom `__new(cls, ...)` is an allocator only: use `dc.allocate(cls)` to
allocate an uninitialized instance with the selected storage. Class construction
then calls the selected initializer exactly once. Returning nil or an instance
of another class raises. Custom initializers own their argument contract; they
must accept the generated field arguments if they are to support `replace`.

## Storage and freezing

Mutable instances store fields directly in the instance table. Their metatable
uses the class as `__index` and has no `__newindex`; ordinary assignment does not
run converters, validators or field checks. Extra fields are allowed.
As with ordinary Lua tables, a nil field does not shadow a same-name class member;
keep data field names distinct from shared method names.

`frozen=true` allocates a shell with `__dict` backing storage. Normal writes,
including deletion and new fields, raise from allocation onward. Generated
initialization writes internally; ordinary writes in pre/post/custom init are
restricted, matching attrs' frozen behavior. A custom init can explicitly call
`__dataclass_init`. A child of a frozen parent remains frozen.

`freeze(instance)` migrates current raw data fields into backing storage and
switches the metatable, preserving identity, shared methods and nested references.
It is shallow and idempotent. `isfrozen(instance)` reports the storage mode.
`rawget` and `pairs` expose the new shell layout after freeze; use `asdict` for
declared-field traversal. There is no thaw operation.

`__class`, `__dataclass`, `__dict`, raw operations and metatables follow a trust
convention. They can bypass restrictions or forge identity; freezing is not a
security boundary. No class/instance registry or private identity token is used.

## Values and data operations

Generated equality compares selected fields with Lua `==` only for the same
concrete class. Subclasses and classes with identical names have distinct
identity. Mutable and frozen instances of the same class share the equality
function. `eq=false` disables generation; explicit/inherited custom comparison
remains available, while parent-generated equality is not inherited.

Generated ordering compares selected fields lexicographically. Different
generated dataclass types raise a same-class error; foreign tables and custom
comparators follow LuaJIT's own dispatch rules. Nil and otherwise unorderable
values raise Lua errors when comparison is required; no coercion or NaN total
order is provided. Custom `__eq` conflicts with `eq=true`; custom `__lt`/`__le`
conflict with `order=true`. Disable the corresponding generation to supply them.

`repr=true` supplies `__tostring` with selected field names/values and handles
recursive instance references. A custom `__tostring` overrides generated repr.

`replace(instance, changes?)` constructs a new instance of the same class using
retained init fields plus named changes. It reruns converters, validators and
hooks; converters therefore receive already-converted retained values.
`init=false` fields are recomputed. The source is unchanged. A manually frozen
instance of a mutable class produces a mutable replacement; a frozen class
produces a frozen replacement. Use `NIL` to clear and `MISSING` to reset a field.

`asdict(instance, keep_nil?)` shallowly exports declared fields, including
`init=false`, omitting nil by default. With `keep_nil=true`, nil is encoded as
`NIL`. Methods, extra data and runtime fields are excluded. This is not recursive
serialization or an automatic JSON encoder.

`isclass(value)`, `isinstance(value, cls)` and `issubclass(cls, parent)` use the
independent convention and single-parent chain. They do not integrate with
`std.isinstance`.

This version does not provide assignment hooks, field aliases/keyword-only
fields, `takes_self` factories, slots, hash generation or recursive export.
Constructor/value functions are shared per class and interpret its schema;
there is no runtime source generation or measured speed guarantee.
