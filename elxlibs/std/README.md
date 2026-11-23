# Shared-method classes

```lua
local class = require 'elxlibs.std.class'
local inspect = require 'elxlibs.std.inspect'

---@class Point : std.object
---@field x number
---@overload fun(x:number):self
local Point = class.new('Point')
function Point:__init(x)
    self.x = x
end

function Point:read()
    return self.x
end

local point = Point(3)
assert(point:read() == 3)
```

`class.new(name, parent?, members?, options?)` defines a single-inheritance class.
The parent defaults to `class.object`. Members remain shared in the class's
`__dict`; methods use ordinary Lua colon calls. Class construction forwards all
arguments, including trailing nils, to `__init`. `new_abstract` and `new_final`
accept the same arguments and force the corresponding guard.

`ClassOptions` contains `dict`, `abstract`, and `final`. Each is a boolean.
Options are copied; `dict` inherits from the parent, and an explicit `false`
overrides it. Abstract/final flags apply only to the class being defined.
Unknown options, invalid parents and non-table member dictionaries raise TypeError.

## Definition and completion

Define Lua metamethods, attribute hooks and descriptors before `class.finish(cls)`
or the first construction. Completion also finishes the parent, collects supported
Lua metamethods, snapshots hooks/descriptors and independently chooses the instance
reader, writer and allocator. Completion is idempotent. A failed definition can
be corrected and completed again.

Ordinary shared members, `__init` and `__new` remain dynamically looked up.
Changing special behavior after completion does not refresh cached instance
policies. Class and instance metatables remain protected from normal
`getmetatable`/`setmetatable`; LuaJIT table finalizers are not installed.

## Storage and attribute hooks

Instances store fields directly by default: existing reads/writes are native table
operations, `__index` searches shared members, and there is no `__newindex` handler.
An instance stores only its `__class` identity plus its data. The class holds its
private State through its own metatable; no global class/instance registry retains
objects. Structural metadata and raw/debug access follow a trusted convention,
without an anti-forgery system.

`dict=true` gives each instance a `__dict` backing table. Full attribute hooks or
descriptors with setters also select effective dict storage, without changing
the declared `dict` option. This is necessary because Lua bypasses `__index` and
`__newindex` for existing raw fields. Optional dispatch runs only in classes
that need it; ordinary attribute access never calls inspect.

| Hook | Trigger | Signature |
| --- | --- | --- |
| `__getattr` | Default lookup found neither data nor a class member/descriptor | `(self, key) -> value` |
| `__setattr` | A write has no current instance value and no class member | `(self, key, value)` |
| `__getattribute` | All ordinary business-field reads, including methods | `(self, key) -> value` |
| `__setattribute` | All ordinary business-field writes/deletions | `(self, key, value)` |

Full hooks take precedence over fallback hooks and default dispatch. Returning
nil/false from a read hook is a valid final result. Write hooks own the operation;
their return values do not signal whether a write was handled. Writing nil deletes
a value. Hooks apply to instances, and structural `__class`/`__dict` remain raw
fields outside interception. A subclass can use `false` to disable an inherited
hook before completion.

```lua
function Point:__getattribute(key)
    return inspect.getattribute(self, key) -- skips custom hooks, retains descriptors
end
function Point:__setattribute(key, value)
    inspect.setattribute(self, key, value)
end
```

Declare these before constructing Point. `inspect.getattr/setattr` perform
ordinary Lua access. `getattribute/setattribute` skip custom hooks but retain
descriptors. `rawgetattr/rawsetattr` access instance data only, skipping all
class-member/descriptor/hook behavior. Inspect validates private State on each
tool call, so full hooks or descriptors delegating through it cost more than
direct fields. Fallback hooks leave existing direct fields on native Lua paths.
See [inspect tools](inspect.md). Import with `require 'elxlibs.std.inspect'`,
or use `require('elxlibs.std').inspect`; both reference the same module.

Migration from the previous dict default: `rawget(obj, key)` and `pairs(obj)` now
see direct data, while `obj.__dict` is normally absent. Select `dict=true` for the
old instance storage layout, or use inspect data tools across both layouts.
Instances no longer duplicate `__name`; obtain the class name from
`inspect.classinfo(obj.__class).name`.
`copy.shallow_copy/deep_copy` still copy raw Lua tables; they are not class-cloning
APIs and do not preserve instance metatables.

## Lightweight descriptors

A shared class member table with `__get` or `__set` is a descriptor:

```lua
Point.__dict.twice = {
    __get = function(desc, obj, owner)
        if obj == nil then
            return desc
        end

        return obj.x * 2
    end,
    __set = function(_, obj, value)
        obj.x = value / 2
    end,
}
```

The signatures are `__get(descriptor, instance_or_nil, owner_class)` and
`__set(descriptor, instance, value)`. The owner is the accessed class, including
for inherited descriptors. A class read after completion passes nil as the
instance; before completion, class reads return the declared raw member. Methods
returned by descriptors use ordinary Lua calling conventions.

A descriptor with a setter is a data descriptor and takes precedence over
instance data. A getter-only descriptor is a non-data descriptor: an instance
value can shadow it, and deletion reveals the getter again. A getter returning
nil is still a found member and does not invoke `__getattr`. Setters receive nil
for deletion. A read-only property uses a setter that raises; getter-only does
not imply read-only. A setter-only descriptor returns its shared object when
there is no instance value.

Nearest-class definitions win: a child ordinary member can hide a parent
descriptor. No descriptor objects or method wrappers are copied into instances.
`inspect.getmembers` returns the shared descriptor object, while normal reads
evaluate it. Descriptor strategy is cached at completion.

## Parent access and identity

`class.super(cls)` returns the actual immediate parent class, with no proxy or
method wrapping. Use `class.super(Child).method(self, ...)`, or capture the known
Parent and call `Parent.method(self, ...)` directly. Supplying the third
`target_type` argument assists editor inference: `class.super(Child, nil, Parent)`.

`class.super(cls, instance, target_type?)` preserves the readonly compatibility
proxy. Both `proxy:method(...)` and `proxy.method(instance, ...)` work. Each proxy
caches its bound wrapper per method and refreshes it when that method changes.
Class-target proxies return unbound shared functions. Descriptor access through
a proxy uses the requested parent as owner and the bound instance as receiver.
Resolution starts at the declaration class's parent, preserving deep inheritance
and all returned values. Root and unrelated-hierarchy requests raise TypeError.

`kindof`, `isinstance`, `issubclass`, `isabstract`, and `isfinal` remain available
through class; the first three also retain their `std` aliases. An instance's
raw `__class` identifies its type. Valid convention-based identities may be
forged; malformed markers are rejected by reflection queries.
