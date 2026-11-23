# elxlib Repository Guide

## 1. Purpose and source of truth

elxlib provides reusable LuaJIT utilities and mpv/mpv.net integration under
`elxlibs.*`. The production entry configures module aliases and native-library
paths for Windows; offline tests load library modules directly without that
entry or a real mpv process.

Before changing code, read:

1. `README.md` or `README_CN.md` for supported modules and platform limits.
2. The source and public annotations of the module being changed.
3. `test/README.md` for test setup and group layout; the owning group's README
   (currently `test/test_asyncio/README.md`) for coverage and validation baseline.
4. This guide for development and commit requirements.

There is no separate current design-document tree. Keep documentation beside
the implementation or in the existing READMEs; do not describe a planned API as
implemented. Update both root READMEs when their shared public instructions change.

## 2. Repository map and dependency ownership

| Path | Responsibility |
| --- | --- |
| `init.lua`, `main.lua`, `version.lua` | mpv entry, lazy loader, aliases and version |
| `elxlibs/std/` | Classes, reflection, exceptions and basic helpers |
| `elxlibs/asyncio/` | Coroutines, futures/tasks, queues, locks, timeouts and amp |
| `elxlibs/json/`, `copy/`, `hashlib/`, `fun/` | Reusable Lua utilities |
| `elxlibs/fs/`, `aiofs/`, `mptl/`, `lockfile/` | Filesystem, subprocess and host helpers |
| `elxlibs/cjson/`, `rex/`, `lxp/`, `socket/`, `websocket/` | Native wrappers and network helpers |
| `bin/` | Tracked executables and DLLs required by supported modules |
| `test/run.lua`, `test/bootstrap.lua` | Shared test entry and LuaJIT setup |
| `test/test_asyncio/` | Asyncio tests, group setup and scripted amp host |
| `test/vendor/mpv-luatest/` | Pinned test-framework Git submodule |

Use `require 'elxlibs.module'` inside the library. Keep production alias setup in
`init.lua`; offline test bootstrap must not duplicate the native DLL setup.
Avoid new require cycles. Aggregates and aliases should expose the same objects
as direct imports.

Keep pure utilities usable without a host. Existing asyncio logging uses `mp.msg`,
so its offline tests install the host stub before loading asyncio. The amp module
owns mpv event-loop overrides; pure modules must not start an event pump or load
native helpers merely because they are imported.

Shared discovery, assertion and general fake-host implementations belong to
mpv-luatest. Project globals, LuaJIT shims and scripted `wait_event` behavior belong
to `test/bootstrap.lua` and the owning group's helpers. Asyncio's host setup lives
in `test/test_asyncio/bootstrap.lua`, `support.lua` and `amp_stub.lua`. Do not copy the
shared framework back into this repository or modify the submodule implicitly.

## 3. Runtime and public contracts

- Target LuaJIT's Lua 5.1 syntax. Do not use compound assignments, Lua 5.3
  operators or table finalizers without runtime support. Offline bootstrap
  supplies `table.pack` and `table.unpack` when the interpreter omits them.
- `std.class.new(name, parent, members, options)` accepts a direct single parent.
  Instances default to direct storage; full attribute hooks and data descriptors
  select dict storage without changing caller options. Define special behavior
  before `class.finish` or the first instance; policies are cached. Preserve
  final/abstract checks, reflection and protected metatables; see `elxlibs/std/README.md`.
- Reflection tools belong to `std.inspect`. Class explicitly installs private
  primitives; inspect must not require class or receive prepared public tools.
- Preserve all values, including trailing nils, through coroutine/task wrappers.
  `try_await` reports success and returned values, or failure and the error.
- Keep exception identity, default messages, `__cause` and traceback locations
  meaningful. Test actual types where appropriate; a substring in a cause is
  not sufficient evidence of the outer exception's type.
- Amp shutdown and error paths must continue pumping host events while finally
  callbacks are pending. Keep deadlines/watchdogs around deadlock regressions.
- Preserve native-library and subprocess boundaries. Use isolated temporary
  paths for filesystem tests; do not load real user configuration or operate
  on user files during offline tests.

## 4. Coding style and annotations

- Follow [codestyle.md](codestyle.md) for formatting, imports and type examples.
  `---@namespace` and `---@using` are optional; type names must resolve clearly.
- Use four spaces and readable local module names. Prefer single-quoted project
  strings in new code; avoid unrelated formatting churn in existing modules.
- Define instance classes, fields, reusable Options types and constructor
  `---@overload` signatures explicitly. Namespace annotations describe types;
  they do not change runtime class names.
- Use named aliases for reused closed string unions. Do not append `| string`
  or widen types to `any` solely to silence a diagnostic.
- Do not mutate caller-owned configuration tables while applying defaults.
- Fix missing type information locally. Do not introduce file-wide diagnostic
  suppression in production or modify global analyzer settings to hide issues.
  A narrow suppression requires a documented analyzer/third-party limitation.
- Keep changed lines free of trailing whitespace and files terminated by a newline.

## 5. Development workflow

1. Inspect `git status --short`, relevant diffs, documentation and dependencies.
   Treat existing worktree changes as intentional until inspected.
2. Make the smallest coherent change in the owning module. Update public
   documentation when a signature, behavior or development entry changes.
3. Add or update tests for affected public behavior, invalid boundaries,
   lifecycle and module identity where needed. Assert failures as well as success;
   avoid tests that only repeat implementation details.
4. Run focused tests during iteration, then all required checks below before
   committing. Report failures and known warnings accurately; a temporary patch
   or changed in-memory assertion does not count as an unmodified suite passing.
5. Inspect `git diff --check`, `git diff --stat` and `git status --short`. Stage
   explicit paths, review the staged diff, then create a scoped commit.
6. Verify the commit's file list and remaining worktree. If verification relied
   on uncommitted production changes, say so; do not claim the committed tree was
   independently verified or silently include those changes.

## 6. Required checks

Run from the repository root. Resolve LuaJIT and EmmyLua on `PATH`, or use local
executable paths without committing machine-specific settings. Keep temporary
diagnostic JSON, local environments and validation fixtures outside tracked files.

```sh
git submodule update --init --recursive
luajit test/run.lua
emmylua_check .
git diff --check
git diff --cached --check
```

Lua assertions describe checks, not test-case counts. Exit code 0 is required for
the suite and analyzer. EmmyLua can return 0 with warnings: inspect its output,
fix new warnings in changed code, and report existing limitations rather than
claiming zero diagnostics. Use project-root analysis so library types resolve.

For runner/bootstrap or dependency integration changes, also run:

```sh
luajit test/vendor/mpv-luatest/run.lua --test-dir test --bootstrap test/bootstrap.lua
luajit test/run.lua -v exceptions
luajit test/run.lua --help
```

Verify an absolute entry from another working directory, an empty filter and
invalid arguments returning 1, and a missing dependency reporting the submodule
initialization command. Use isolated fixture directories for these checks.

For a new or updated framework gitlink, verify the pinned dependency independently:

```sh
luajit test/vendor/mpv-luatest/run.lua --root test/vendor/mpv-luatest --test-dir tests
luajit test/vendor/mpv-luatest/run.lua --root test/vendor/mpv-luatest/examples/project
```

If shared framework code itself changes, run its documented Python CLI regressions
and static checks in that repository, publish the dependency commit before relying
on its gitlink elsewhere, then rerun this project's checks. Do not automatically
push or publish without user authorization.

The default suite is offline. Asyncio has an optional headless real-host smoke
test; it does not validate native DLL loading or real mpv input/rendering.
Add isolated real-host coverage when changing those
boundaries; own and terminate only fixture-created processes, never mpv by image name.

## 7. Test layout and commits

Use the shared `test/run.lua` entry. The dependency discovers `test_*.lua` under
`test/test_<group>/` and nested directories beginning with `test`; fixtures and
dependency tests are excluded. New groups need no runner registration. Import
group helpers by their `test_<group>.*` names to avoid module-name collisions.
Keep shared bootstrap host-independent and put group-specific setup in that
group's helpers. Update `test/README.md` and the owning group's README when
coverage, counts or setup intentionally change.

Use conventional commits such as `test(asyncio):`, `fix(std):`, `refactor(asyncio):`
and `docs:`. Stage related code, documentation, `.gitmodules` and gitlinks by
coherent purpose. Do not commit unrelated worktree edits, local analyzer settings,
credentials or generated artifacts. Changes to tracked `bin/` artifacts need
their own explained source/build provenance and appropriate validation.
