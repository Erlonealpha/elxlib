# std.inspect

Import with `require 'elxlibs.std.inspect'`. This pure module does not load class or
mpv. `require('elxlibs.std').inspect` references the same module. `std.class`
explicitly calls `inspect.__install('std.class', capabilities)` after initializing
its core. Both import orders share the same inspect module. A
repeated installation of the same capabilities is idempotent; conflicting installations
raise an error, and incomplete installation can be retried. Hot reload is not
supported.

Before installation, `kindof`/`classof` return nil. Class-specific tools report
`std.class capabilities unavailable`; they never implicitly require the class module.
The independent dataclass does not participate in this installation.

Class installs only four internal primitives: `state_of` obtains private State,
`finish` prepares cached class policies, `getmetatable` obtains the real metatable,
and `fail` raises a class error. It does not install prepared public tools.
Inspect builds identity checks, parameter validation, information snapshots and
attribute tools from those primitives and State's cached data/read/write policies.
State stays owned by the class; the installation retains no per-class references.

| Function | Behavior |
| --- | --- |
| `kindof(obj, kind?)` | Class/instance identity query, matching `std.class.kindof` |
| `classof(obj)` | Instance's class, or nil |
| `classinfo(cls)` | Shallow snapshot: name, parent, mro, options, finished, effective storage |
| `getmembers(cls, inherited?)` | Copy of raw shared members; nearest definition wins; own-only by default |
| `getmetatable(cls_or_obj)` | Actual metatable snapshot with private State omitted |
| `getattr(obj, key)` / `setattr(obj, key, value)` | Ordinary Lua access, including custom hooks |
| `getattribute(obj, key)` / `setattribute(obj, key, value)` | Default dispatch, skipping custom hooks and retaining descriptors |
| `rawgetattr(obj, key)` / `rawsetattr(obj, key, value)` | Instance backing data only; skip hooks, descriptors and shared members |

`classinfo.storage` is nil before completion and `'direct'`/`'dict'` afterwards.
Its copied options retain declared values even when full hooks or setters cause
effective dict storage. Information queries do not complete a class;
instance dispatch/data tools require a valid instance and completed policies.
Views are shallow snapshots, with shared member values; they do not expose a
mutable private State or install per-class references. Changing a view does not
change class configuration. Raw storage/debug access remains trusted.

See [class storage, hooks and descriptors](README.md) for dispatch rules.
