# elxlib tests

The shared `run.lua` entry discovers Lua tests through the pinned
[mpv-luatest](vendor/mpv-luatest) submodule. Run from the repository root:

```sh
git submodule update --init --recursive
luajit test/run.lua                 # all groups
luajit test/run.lua asyncio         # one group
luajit test/run.lua asyncio/locks   # one file within a group
luajit test/run.lua -v              # detailed output
luajit test/run.lua --help
```

An absolute entry works from another working directory. Filters match literal
substrings of group/file components, ignoring `test_` prefixes and `.lua` suffixes.
Exit code is 0 for success/help and 1 for test failures, invalid arguments or an
empty match. The dependency CLI also works:

```sh
luajit test/vendor/mpv-luatest/run.lua --test-dir test --bootstrap test/bootstrap.lua
```

## Layout and new groups

```text
test/
  run.lua                   shared entry
  bootstrap.lua             shared LuaJIT shims and project globals
  test_asyncio/
    test_*.lua              discovered test files
    bootstrap.lua           group host setup
    support.lua             group helpers
    amp_stub.lua            scripted host fixture
    real_host.py            optional integration entry
    real_host/smoke.lua      integration fixture, excluded from discovery
    README.md               group coverage and validation
  vendor/mpv-luatest/        pinned framework, excluded from discovery
```

To add a suite, create `test/test_<group>/test_<feature>.lua`. No registration in
the runner is required. Import assertions with `require 'mpv_luatest.framework'`,
then define cases with `F.test` and assertions such as `F.eq`, `F.ok`, `F.raises`.

Import group helpers as `require 'test_<group>.support'` or another name within
the group. The test root is on the module search path; short imports such as
`require 'support'` can conflict with helpers from other groups. Only shared
runtime setup belongs in `test/bootstrap.lua`. Install a host stub from a group's
setup/helper when it is needed, before importing host-dependent modules.

All test files run in one Lua process. Groups that change module/global state
must restore it or establish the state they require; namespaced helpers avoid
name collisions but do not isolate `package.loaded` or host globals.

Discovery is sorted and recursive only through directories beginning with
`test`; filenames must match `test_*.lua`. Store nondiscovered fixtures in
directories such as `fixtures` or `real_host`. Tests under `vendor` are excluded.

Current groups:

| Group | Coverage | Assertions |
| --- | --- | --- |
| [std](test_std/README.md) | Utilities, classes, reflection and exceptions | 124 |
| [json](test_json/README.md) | Codec round trips, null placeholders and malformed input | 64 |
| [hashlib](test_hashlib/README.md) | Digest vectors, streaming, HMAC, BLAKE and Base64 | 145 |
| [fs](test_fs/README.md) | Subprocess operations, flags, failures and stat parsing | 83 |
| [asyncio](test_asyncio/README.md) | Scheduling, synchronization and amp | 454 |

Asyncio also provides an optional
headless real-host check:

```sh
python test/test_asyncio/real_host.py
```

## Validation

Follow [AGENTS.md](../AGENTS.md). Run the full suite, project-root EmmyLua analysis
and whitespace checks. For entry/bootstrap/discovery changes, also verify the
direct dependency CLI, group/file filters, help, an absolute entry from another
directory, invalid/empty filters and missing-dependency diagnostics. Use isolated
fixtures to confirm that a new group is discovered and fixtures/vendor are skipped.

Run `luajit test/run.lua` for the current combined assertion total. Each group
records its validation baseline in its README. The dependency gitlink is unchanged.
