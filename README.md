# elxlib for MPV

A Lua script integration library for MPV / mpv.net. elxlib collects common Lua utilities, mpv helpers, and several binary-backed modules under the unified `elxlibs.*` namespace so other scripts can reuse them directly.

[中文文档](README_CN.md)

## Features

- Configures `package.path` / `package.cpath` and adds the bundled `bin` directory to the runtime DLL search path.
- Supports loading bundled modules through either `elxlibs.{module}` or `elxlib.{module}`.
- Provides JSON (pure Lua and `cjson`), hashing/Base64, regex, XML, LuaSocket, WebSocket, and functional iterator utilities.
- Provides mpv-oriented helpers for subprocess calls, sync/async filesystem operations, coroutine scheduling, and lock files.
- Ships a coroutine-based `asyncio` layer with tasks, `await`/`try_await`, `Queue`, `Timeout`/`wait_for`, cancellation and a mpv-oriented event loop.
- Includes EmmyLua/LuaLS annotations for editor completion and type hints.
- Includes a standalone test-suite (`test/asyncio`) that runs on plain LuaJIT without mpv.

## Requirements And Limits

- Current hard requirement: Windows / `win32` and LuaJIT.
- The main target environment is MPV / mpv.net scripting. The entry module depends on `mp` and `mp.utils`.
- When using `mpv.net`, make sure `libmpv` dynamically links Lua. Builds with statically linked Lua may crash when C extensions are loaded. Dynamic-link builds are available from [Releases](https://github.com/Erlonealpha/elxlib/releases).
- `fs` / `aiofs` depend on `bin/fstool.exe`; modules such as `rex`, `lxp` and `cjson` depend on the DLLs bundled in `bin` (`bin/` is not part of the repository, see Releases).

## Installation

Place this repository in MPV's script directory and keep the folder name as `elxlib`:

```text
~~/scripts/elxlib/
```

In mpv, `~~/scripts` usually resolves to the `scripts` folder under the mpv configuration directory. mpv.net users can place it in the portable config `scripts` directory.

## Quick Start

Because of Lua's package loading rules, scripts should first add the script directory to `package.path`, then require elxlib:

```lua
local scripts_dir = mp.command_native({"expand-path", "~~/scripts"})
package.path = package.path .. ";" .. scripts_dir .. "/?/init.lua"

local elxlib = require "elxlib"
```

After that, modules can be imported through either namespace:

```lua
local elxlib = require "elxlib"
local std = require "elxlibs.std"
local json = require "elxlib.json"

print(elxlib.version) -- v0.1.0
print(std.version)    -- 0.1.0
print(json.dumps({name = "elxlib", ok = true}, 2))
```

The entry object also lazy-loads modules:

```lua
local elxlib = require "elxlib"
local fs = elxlib.fs

local ok, err = fs.create_dir("cache", true)
if not ok then
    mp.msg.error(err)
end
```

## Modules

| Module | Description |
| --- | --- |
| `std` | Basic utilities, class helpers, and exception helpers. Includes `round`, `clamp`, `split`, `trim`, `class`, `raise`/`traceback`/`xpcall`, `try/catch/finally`, and exception chaining via `__cause`. |
| `json` | JSON encode/decode helpers: `dumps`, `loads`, and `json.null`. `dumps` accepts a custom encoder (see `json.IEncoder` / `json.IDecoder`) and a `fallback` for unsupported values. |
| `hashlib` | Pure Lua hashing helpers (including chunked/partial hashing via `hashlib.partial`) plus `base64_encode` / `base64_decode`. |
| `cjson` | Thin entry modules for Lua CJSON: `cjson` and `cjson.safe` (requires `bin/cjson.dll`). |
| `copy` | `deep_copy` and `shallow_copy`. |
| `fs` | Synchronous filesystem helpers backed by `fstool`: `exists`, `create_dir` / `mkdir`, `remove_dir`, `copy`, `get_size`. |
| `aiofs` | Async filesystem helpers built on `asyncio` and mpv async commands. |
| `asyncio` | Coroutine-based async helpers: `run`, `async`, `await`, `try_await`, `create_task`, `sleep`, `wait`, `wait_for`, `gather`, `shield`, plus the mpv-backed `amp` event loop (`register_event`, `observe_property`, `add_finally`, ...). `require "elxlibs.asyncio.queues"` adds `Queue`/`LifoQueue` and `require "elxlibs.asyncio.timeouts"` adds `Timeout`/`timeout`/`timeout_at`. |
| `mptl` | mpv tool layer. Currently wraps `mp.command_native` subprocess and async subprocess calls. |
| `lockfile` | Cross-process lock file wrapper. Loads a platform implementation; the Windows backend uses the Win32 API. |
| `socket` | LuaSocket entry module. |
| `websocket` | Synchronous WebSocket client/server entry module. |
| `rex` | lrexlib PCRE2 wrapper with safe wrappers and an `unsafe` raw entry. |
| `lxp` | LuaExpat XML SAX parser entry module. |
| `fun` | Lua Fun functional iterator library with an additional `str_concat` helper. |
| `urlparse` | Reserved URL parsing module entry. |

## Examples

JSON:

```lua
local json = require "elxlibs.json"

local text = json.dumps({items = {1, 2, 3}, empty = json.null}, 2)
local data = json.loads(text)
```

subprocess:

```lua
local mptl = require "elxlibs.mptl"

local result, err = mptl.subprocess({
    args = {"cmd", "/c", "echo", "hello"},
    playback_only = false,
    capture_stdout = true,
    capture_stderr = true,
})

if result and result.status == 0 then
    mp.msg.info(result.stdout)
else
    mp.msg.error(err or result.stderr)
end
```

Async task:

```lua
local asyncio = require "elxlibs.asyncio"

asyncio.run(asyncio.async(function()
    mp.msg.info("before")
    asyncio.await(asyncio.sleep(1))
    mp.msg.info("after")
end))
```

Async task with a timeout (`try_await` reports `false, err` instead of raising):

```lua
local asyncio = require "elxlibs.asyncio"

asyncio.run(asyncio.async(function()
    local task = asyncio.create_task(asyncio.async(function()
        asyncio.await(asyncio.sleep(10))
        return "done"
    end))

    local ok, err = asyncio.try_await(asyncio.wait_for(task, 0.5))
    if not ok then
        mp.msg.error(err) -- std.TimeoutError (with the cancellation as __cause)
    end
end))
```

## Tests

`test/asyncio` contains a standalone suite for the asyncio core (tasks, cancellation, `Queue`, `Timeout`, the amp shutdown/`finally` path) and the `std` exception plumbing. It runs on a bare LuaJIT — mpv is not required, `mp` is stubbed:

```sh
luajit test/asyncio/run.lua          # whole suite
luajit test/asyncio/run.lua amp      # only files whose name matches
```

The exit code is `0` when everything passes. See [test/asyncio/README.md](test/asyncio/README.md) for the layout and conventions.

## Project Layout

```text
elxlib/
├── init.lua              # Entry module, loader setup, and module aliases
├── main.lua              # Placeholder mpv script entry
├── bin/                  # C extension DLLs and helper executables (not in the repo)
├── elxlibs/              # Feature modules
└── test/                 # Standalone test-suite (plain LuaJIT, no mpv needed)
```

## Third-Party Projects

- [Base64](https://github.com/Reselim/Base64) `/hashlib/base64.lua`  
  A pretty fast Luau Base64 encoder/decoder.
- [pure_lua_SHA](https://github.com/Egor-Skriptunoff/pure_lua_SHA) `/hashlib/sha.lua`  
  SHA1, SHA2, SHA3, BLAKE2 and BLAKE3 functions written in pure Lua and optimized for speed.
- [json.lua](https://github.com/rxi/json.lua) `/json/{decode,encode}.lua`  
  A lightweight JSON library for Lua.
- [Lua CJSON](https://github.com/mpx/lua-cjson) `/cjson`  
  Fast JSON encoding/decoding for Lua (used through `bin/cjson.dll`).
- [luaexpat](https://github.com/lunarmodules/luaexpat) `/lxp`  
  LuaExpat is a SAX XML parser based on the Expat library.
- [lrexlib](https://github.com/rrthomas/lrexlib) `/rex`  
  A Lua binding of various regex library APIs.
- [luasocket](https://github.com/lunarmodules/luasocket) `/socket`  
  Network support for the Lua language.
- [luafun](https://github.com/luafun/luafun) `/fun/init.lua`  
  A high-performance functional programming library for LuaJIT.

## License

This project is released under the MIT License. See [LICENSE](LICENSE).
