# elxlib asyncio test-suite

Functional and regression tests for `elxlibs/asyncio`. The separate
[std group](../test_std/README.md) owns exception plumbing tests.
They use [mpv-luatest](../vendor/mpv-luatest) for discovery, assertions and
reporting, and run on **bare LuaJIT** with a project-specific `mp` stub.

## Running

```sh
git submodule update --init --recursive
luajit test/run.lua            # all groups
luajit test/run.lua asyncio    # this group
luajit test/run.lua asyncio/locks # this group's lock tests
luajit test/run.lua amp        # amp adapters and shutdown tests
luajit test/run.lua -v         # include files, sections and successful tests
luajit test/run.lua std/exceptions # std exception tests
```

The shared entry in `test/run.lua` resolves the project and dependency relative to itself, so an absolute
path to `run.lua` also works from another working directory. Exit code is `0`
when everything passes or help is requested, and `1` for failures, invalid
arguments or an empty filter match. The default output shows failures and totals.

The dependency is pinned as a Git submodule at `test/vendor/mpv-luatest`. After
cloning elxlib, initialize it with the command above, or use
`git clone --recurse-submodules`. To invoke the dependency's CLI directly:

```sh
luajit test/vendor/mpv-luatest/run.lua --test-dir test --bootstrap test/bootstrap.lua asyncio
```

## Layout

| File | Contents |
| --- | --- |
| `../run.lua` | Shared adapter to `mpv_luatest.suite.main`, discovers all groups |
| `../bootstrap.lua` | Shared LuaJIT shims and project globals |
| `bootstrap.lua` | Asyncio host stub setup, loaded by `test_asyncio.support` |
| `support.lua` | Real-clock loop, bounded task runner and module reload helpers |
| `amp_stub.lua` | Project `mp` stub: scripted event payloads, raw API call recording, clock, watchdog and logs |
| `test_core.lua` | `await`/`try_await`/`gather`, `Queue`, `Lock`, `shield` |
| `test_cancellation.lua` | `cancelling`/`uncancel`, cancel before the first step, cancel while awaiting |
| `test_timeouts.lua` | `wait_for`, `Timeout:with`, `TimeoutError` conversion |
| `test_amp_shutdown.lua` | amp loop shutdown + `finally` callbacks (one fresh module tree per case) |
| `test_api.lua` | Export identity; Future lifecycle/callbacks; coroutine/task inputs, results and errors; `wait`/`gather`/`shield`; generic `with` |
| `test_loops.lua` | Loop lookup/run/stop/close, callback and timer ordering/cancellation, exception handlers |
| `test_locks.lua` | Lock fairness, Event broadcast/clear, Semaphore capacity/FIFO/cancellation and `with` lifecycle |
| `test_queues.lua` | Queue/LifoQueue boundaries/order, unfinished work, join and producer/consumer cancellation |
| `test_amp_api.lua` | Events, messages, properties, bindings, timers, idle, hooks, async commands and forced-GC error retention |
| `real_host.py`, `real_host/smoke.lua` | Optional isolated headless mpv/mpv.net integration smoke test |

## Coverage and public contracts

Every current exported asyncio operation has functional coverage across the files
above. Cases cover normal results, invalid inputs, typed errors, cancellation,
ordering, cleanup and module identity. This is an API coverage inventory, not a
claim of complete line/branch coverage or every possible interleaving.

- `wait` completes without returning a result list. It supports `all_done`
  (default), `first_done`, `first_error`, a deadline and wrapper cancellation;
  it does not cancel the supplied futures. Empty inputs and unknown modes fail.
- `gather` preserves input positions, including nil results. With
  `return_exceptions=true`, successful/failed children produce records and
  cancelled children produce `CancelledError` objects.
- `Semaphore:with(function/thread/Coroutine)` acquires before scheduling the body
  and releases after success, failure or cancellation. A Task or Future supplied
  by the caller can already be running; use a fresh callable/Coroutine when the
  semaphore must control the start of an operation.
- `Timeout:with` retains existing target-task semantics. An immediate deadline
  cancels at the next scheduling/suspension point; a synchronous body can finish
  before cancellation. Returned values keep trailing nils.
- Failed amp event/timer/idle tasks stay owned until their errors are reported
  after finally callbacks. Forced collection is part of the regression suite.
- Table finalizers are not promised by the LuaJIT Lua 5.1 runtime. The suite does
  not claim automatic `Future`/`Task` finalizer diagnostics.

Optional real-host validation (Python 3.8+ and a mpv executable on PATH):

```sh
python test/test_asyncio/real_host.py
python test/test_asyncio/real_host.py --mpv /path/to/mpv
```

`ELXLIB_MPV_BINARY` can select the executable. The runner uses a temporary config,
disables user-script loading and visible windows, and only cleans its own process
tree. It verifies actual message/property/async-command delivery, timers and
shutdown/finally. It does not validate video rendering, native DLL loading,
physical key input or playback hooks.

## Notes

- **Nothing here is loaded by mpv or by `elxlib/init.lua`.** The directory lives
  outside `elxlibs/`, and there is no `main.lua`, so mpv's script auto-loader
  ignores it.
- Tests import `mpv_luatest.framework` directly. `F.contains` replaces the old
  string-based `F.is_error` helper; exception names follow the current runtime.
- `test_*.lua` files are discovered in sorted order. Nested directories must
  start with `test`; the dependency's own tests under `test/vendor` are excluded.
- Helpers are imported as `test_asyncio.support` and `test_asyncio.amp_stub`;
  new groups can have their own helpers without sharing those module names.
- `support.reload_asyncio(stub)` drops the `elxlibs.asyncio*` modules so each
  amp case starts from pristine state (the loop instance, `_stoping` and the
  registered `finally` callbacks are module locals of `asyncio/mp.lua`).
- The amp loop is event-pump driven, so a regression there shows up as a
  *hang*: `amp_stub` turns that into a failure via a CPU-time watchdog
  (`watchdog`, default 10s) and a hard cap on `wait_event` calls (`limit`,
  default 500).
- `support.run` bounds offline task cases with a two-second watchdog and closes
  their loop afterward; failures cannot leave a test hung indefinitely.
- Tests assume a LuaJIT with the usual 5.1 API; `table.pack`/`table.unpack`
  are shimmed when the interpreter was built without `LUA52COMPAT`.
- The general `mpv_luatest.mp_stub` remains available for future host tests.
  It does not implement the scripted `wait_event` pump required by amp cases,
  so those use `amp_stub.new()` and fresh asyncio modules instead.

## Development checks and baseline

Follow the shared [test guide](../README.md) and root [AGENTS.md](../../AGENTS.md): inspect existing changes, implement
in the owning module, run focused checks while iterating, then verify the entire
suite and static diagnostics before reviewing and staging explicit commit paths.
Run from the project root:

```sh
git submodule update --init --recursive
luajit test/run.lua
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

- Asyncio group through both entries: **454 assertions passed**.
- Exception filter: **25 assertions passed**; help, absolute/local entry paths,
  empty matches, invalid options and missing dependency diagnostics passed.
- Pinned framework `66e921ca2da4ae79cf7b2c88eb43621ebd417830`: **41 assertions
  passed**, standalone example **2 assertions passed**; dependency checkout clean.
- EmmyLua project-root analysis: **0 errors**, **0 warnings in `test/test_asyncio`**,
  **55 existing warnings elsewhere**. This is not a zero-diagnostic project run.
- Forced-GC event/timer/idle error regressions pass.
- Optional headless mpv.net 7.1.2 smoke: message, property, async command, timer
  and shutdown/finally delivery passed.
- Whole-worktree and staged whitespace checks pass.

The asyncio implementation and expanded tests are committed together. Validation
loads asyncio/std directly and does not depend on unrelated worktree changes in
fs/aiofs/json/fun/websocket or the tracked filesystem binary.
