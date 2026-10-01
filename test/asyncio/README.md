# elxlib asyncio test-suite

Smoke/regression tests for `elxlibs/asyncio` (and the `std` exception plumbing
it relies on). They run on a **bare LuaJIT** — mpv is not needed and not
required: the `mp` API is stubbed, so the tests can run in CI or from a
terminal.

## Running

```sh
luajit test/asyncio/run.lua            # whole suite
luajit test/asyncio/run.lua amp        # only matching files (test_amp_shutdown)
```

Exit code is `0` when everything passes, `1` otherwise.

## Layout

| File | Contents |
| --- | --- |
| `run.lua` | Entry point; sets up `package.path`, runs every `test_*.lua` |
| `support.lua` | Bootstrap (LuaJIT 5.2 shims, repo root, real-clock loop, module reload) |
| `framework.lua` | Tiny assertion/reporting helpers |
| `mp_stub.lua` | Scriptable `mp` stub: clock, scripted events, watchdog, `mp.msg` capture |
| `test_core.lua` | `await`/`try_await`/`gather`, `Queue`, `Lock`, `shield` |
| `test_exceptions.lua` | `raise` levels, `__cause` chaining, `traceback`, `xpcall`/`try` |
| `test_cancellation.lua` | `cancelling`/`uncancel`, cancel before the first step, cancel while awaiting |
| `test_timeouts.lua` | `wait_for`, `Timeout:with`, `TimeoutError` conversion |
| `test_amp_shutdown.lua` | amp loop shutdown + `finally` callbacks (one fresh module tree per case) |

## Notes

- **Nothing here is loaded by mpv or by `elxlib/init.lua`.** The directory lives
  outside `elxlibs/`, and there is no `main.lua`, so mpv's script auto-loader
  ignores it.
- `support.reload_asyncio(stub)` drops the `elxlibs.asyncio*` modules so each
  amp case starts from pristine state (the loop instance, `_stoping` and the
  registered `finally` callbacks are module locals of `asyncio/mp.lua`).
- The amp loop is event-pump driven, so a regression there shows up as a
  *hang*: `mp_stub` turns that into a failure via a CPU-time watchdog
  (`watchdog`, default 10s) and a hard cap on `wait_event` calls (`limit`,
  default 500).
- Tests assume a LuaJIT with the usual 5.1 API; `table.pack`/`table.unpack`
  are shimmed when the interpreter was built without `LUA52COMPAT`.
