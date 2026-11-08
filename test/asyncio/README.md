# elxlib asyncio test-suite

Smoke/regression tests for `elxlibs/asyncio` and its `std` exception plumbing.
They use [mpv-luatest](../vendor/mpv-luatest) for discovery, assertions and
reporting, and run on **bare LuaJIT** with a project-specific `mp` stub.

## Running

```sh
git submodule update --init --recursive
luajit test/asyncio/run.lua            # whole suite
luajit test/asyncio/run.lua amp        # only matching files (test_amp_shutdown)
luajit test/asyncio/run.lua -v         # include files, sections and successful tests
luajit test/asyncio/run.lua exceptions # std exception tests
```

The entry resolves the project and dependency relative to itself, so an absolute
path to `run.lua` also works from another working directory. Exit code is `0`
when everything passes or help is requested, and `1` for failures, invalid
arguments or an empty filter match. The default output shows failures and totals.

The dependency is pinned as a Git submodule at `test/vendor/mpv-luatest`. After
cloning elxlib, initialize it with the command above, or use
`git clone --recurse-submodules`. To invoke the dependency's CLI directly:

```sh
luajit test/vendor/mpv-luatest/run.lua --test-dir test/asyncio --bootstrap test/asyncio/bootstrap.lua
```

## Layout

| File | Contents |
| --- | --- |
| `run.lua` | Adapter to `mpv_luatest.suite.main`; keeps the existing entry command |
| `bootstrap.lua` | LuaJIT 5.2 shims, project globals and default host stub |
| `support.lua` | Real-clock loop and asyncio module reload helpers |
| `amp_stub.lua` | Project `mp` stub: scripted `wait_event`, clock, watchdog and `mp.msg` capture |
| `test_core.lua` | `await`/`try_await`/`gather`, `Queue`, `Lock`, `shield` |
| `test_exceptions.lua` | `raise` levels, `__cause` chaining, `traceback`, `xpcall`/`try` |
| `test_cancellation.lua` | `cancelling`/`uncancel`, cancel before the first step, cancel while awaiting |
| `test_timeouts.lua` | `wait_for`, `Timeout:with`, `TimeoutError` conversion |
| `test_amp_shutdown.lua` | amp loop shutdown + `finally` callbacks (one fresh module tree per case) |

## Notes

- **Nothing here is loaded by mpv or by `elxlib/init.lua`.** The directory lives
  outside `elxlibs/`, and there is no `main.lua`, so mpv's script auto-loader
  ignores it.
- Tests import `mpv_luatest.framework` directly. `F.contains` replaces the old
  string-based `F.is_error` helper; exception names follow the current runtime.
- `test_*.lua` files are discovered in sorted order. Nested directories must
  start with `test`; the dependency's own tests under `test/vendor` are excluded.
- `support.reload_asyncio(stub)` drops the `elxlibs.asyncio*` modules so each
  amp case starts from pristine state (the loop instance, `_stoping` and the
  registered `finally` callbacks are module locals of `asyncio/mp.lua`).
- The amp loop is event-pump driven, so a regression there shows up as a
  *hang*: `amp_stub` turns that into a failure via a CPU-time watchdog
  (`watchdog`, default 10s) and a hard cap on `wait_event` calls (`limit`,
  default 500).
- Tests assume a LuaJIT with the usual 5.1 API; `table.pack`/`table.unpack`
  are shimmed when the interpreter was built without `LUA52COMPAT`.
- The general `mpv_luatest.mp_stub` remains available for future host tests.
  It does not implement the scripted `wait_event` pump required by amp cases,
  so those use `amp_stub.new()` and fresh asyncio modules instead.

## Development checks and baseline

Follow the root [AGENTS.md](../../AGENTS.md): inspect existing changes, implement
in the owning module, run focused checks while iterating, then verify the entire
suite and static diagnostics before reviewing and staging explicit commit paths.
Run from the project root:

```sh
git submodule update --init --recursive
luajit test/asyncio/run.lua
emmylua_check .
git diff --check
git diff --cached --check
```

When the entry, bootstrap or submodule integration changes, also run the direct
CLI above, `-v exceptions` and `--help`. Check an absolute entry from another
working directory, empty/invalid filters and arguments returning 1, and a copied
entry with no dependency showing the initialization command. Keep fixtures in a
temporary directory. Verify a new gitlink independently:

```sh
luajit test/vendor/mpv-luatest/run.lua --root test/vendor/mpv-luatest --test-dir tests
luajit test/vendor/mpv-luatest/run.lua --root test/vendor/mpv-luatest/examples/project
```

Validated on 2026-11-08 with Windows and LuaJIT 2.1.1748459687:

- Both project and direct dependency entries: **107 assertions passed**.
- Exception filter: **25 assertions passed**; help, absolute/local entry paths,
  empty matches, invalid options and missing dependency diagnostics passed.
- Pinned framework `66e921ca2da4ae79cf7b2c88eb43621ebd417830`: **41 assertions
  passed**, standalone example **2 assertions passed**; dependency checkout clean.
- EmmyLua project-root analysis: **0 errors**, **0 warnings in `test/asyncio`**,
  **56 existing warnings elsewhere**. This is not a zero-diagnostic project run.
- Test/docs/staged whitespace checks pass. The complete worktree check reports
  one pre-existing trailing space in `elxlibs/asyncio/tasks.lua`, outside this
  test/development-guide commit.

One later full run intermittently failed two assertions in the amp case
`handler error ends the loop even with a finally registered`; a direct full run
and the amp filter passed afterward. An isolated GC probe reproduces the loss:
collecting after `wait_event` lets the loop return successfully without
`unhandled-boom`, while disabling GC preserves the error. Production
`asyncio/mp.lua` stores event tasks in a weak-value table and retains only IDs
until finally completes. This unresolved production ownership issue is outside
the test commit; the passing counts above do not establish GC-stable amp behavior.

These results use the current worktree's uncommitted asyncio implementation,
including its direct-parent migration, `utils.lua`, timeout/amp changes and
the corrected compound assignment in `locks.lua`. Those production changes
are outside this test/development-guide commit. This baseline does not claim
that the committed tree, without those changes, passes the complete suite.
The suite does not validate native DLL loading or a real mpv process.
