# aiofs tests

Run `luajit test/run.lua aiofs`. **104 assertions** exercise all public operations,
lazy coroutine creation, fs identity, command flags, parsed results, transport and
tool errors, missing/malformed callback results, failed launch, cancellation,
owned-handle abort, concurrent-operation isolation and late/duplicate replies. Each case restores host/module
state, and pending-operation regressions have a watchdog. Project-root EmmyLua
reports no errors or warnings in this group or aiofs implementation.

The existing API change is included: operations return lazy
`asyncio.Coroutine<aiofsResult<T>>` values. Await them from an asyncio task;
successful mutations have `ok=true` and no result payload, existence returns a
boolean, and size/stat return parsed values. Subprocess failures return `ok=false`
with an error string; task cancellation raises CancelledError and aborts its
command. Reply parsing exceptions become failure results instead of leaving the
operation pending.

Optional Windows integration:

```sh
python test/test_aiofs/real_host.py --mpv <mpv-or-mpvnet-binary>
```

The headless fixture starts its task after the amp loop begins, uses real async
subprocess callbacks and bundled fstool, and independently checks copied bytes
through the shared fs Python helper. Real creation, existence, file/recursive
copy, size/stat, removal and failure paths passed. Cancellation timing and
duplicate replies are tested with the deterministic adapter. The binary's
[recorded limitations](../../bin/fstool.md) also apply to aiofs.
