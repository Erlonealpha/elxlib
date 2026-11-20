# Dataclass tests

Run `luajit test/run.lua dataclass` through the shared offline entry.
No host setup is needed. The owning API is documented in
[elxlibs/dataclass/README.md](../../elxlibs/dataclass/README.md).

- `test_schema.lua`: standalone import, caller snapshots, default direct storage,
  shared/dynamic methods, explicit/implicit finish, inheritance and identity,
  invalid definitions/options, failed finish recovery and class/instance GC.
- `test_initialization.lua`: positional/named nil and false, factories/shared
  defaults, converter/validator/hooks order and failures, custom init/new,
  parent initialization, frozen hooks and identity-preserving shallow freeze.
  Also covers constructor isolation, trailing nils through custom allocation,
  pre-hook freezing and validator descriptor isolation.
- `test_values.lua`: same-type equality, lexicographic order and custom conflicts,
  replacement lifecycle/source preservation, class frozen policy, shallow export
  and nil round trips, recursive repr and repr error recovery.

The suite checks behavior rather than performance. Its import probe blocks all
requires in the module chunk; production-entry aliasing and native helpers are
outside this pure module's scope. Follow the root AGENTS.md for full regression
and project-root static analysis before committing.

Validation baseline: 225 assertions on LuaJIT 2.1; the combined suite passes
1190 assertions. Project-root EmmyLua reports no diagnostics in the dataclass
module/tests or changed entry annotation; existing diagnostics elsewhere remain.
