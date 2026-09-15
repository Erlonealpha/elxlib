# elxlib for MPV

适用于 MPV / mpv.net 的 Lua 脚本集成库。elxlib 将常用的 Lua 工具库、mpv 辅助封装以及部分二进制扩展整理到统一的 `elxlibs.*` 命名空间中，方便其他脚本直接复用。

[English](README.md)

## 功能概览

- 自动配置 `package.path` / `package.cpath`，并将 `bin` 目录加入运行时 DLL 搜索路径。
- 支持通过 `elxlibs.{module}` 或 `elxlib.{module}` 加载内置模块。
- 提供 JSON、哈希/Base64、正则、XML、LuaSocket、WebSocket、函数式迭代等常用能力。
- 提供面向 mpv 的工具封装，包括 subprocess、同步/异步文件系统操作、协程事件循环和锁文件。
- 附带 EmmyLua/LuaLS 类型标注，便于在编辑器中获得补全和类型提示。

## 环境要求与限制

- 目前硬性要求：Windows / `win32` 和 LuaJIT。
- 主要使用场景是 MPV / mpv.net 脚本环境，入口依赖 `mp` 与 `mp.utils`。
- 如果使用 `mpv.net`，需要确保 `libmpv` 动态链接 Lua；静态链接 Lua 的构建在使用 C 扩展时可能崩溃。可从 [Releases](https://github.com/Erlonealpha/elxlib/releases) 获取动态链接版本。
- `fs` / `aiofs` 依赖 `bin/fstool.exe`，`rex` / `lxp` 等模块依赖 `bin` 下随库提供的 DLL。

## 安装

将仓库目录放到 MPV 的脚本目录下，并保持目录名为 `elxlib`：

```text
~~/scripts/elxlib/
```

在 mpv 中，`~~/scripts` 通常对应配置目录下的 `scripts` 文件夹。mpv.net 用户可放在 portable config 的 `scripts` 目录中。

## 快速开始

受 Lua 包加载机制限制，其他脚本需要先把脚本目录加入 `package.path`，再加载 elxlib：

```lua
local scripts_dir = mp.command_native({"expand-path", "~~/scripts"})
package.path = package.path .. ";" .. scripts_dir .. "/?/init.lua"

local elxlib = require "elxlib"
```

加载完成后，可以用两种等价路径导入模块：

```lua
local std = require "elxlibs.std"
local json = require "elxlib.json"

print(std.version) -- 0.1.0
print(json.dumps({name = "elxlib", ok = true}, 2))
```

也可以通过入口对象懒加载：

```lua
local elxlib = require "elxlib"
local fs = elxlib.fs

local ok, err = fs.create_dir("cache", true)
if not ok then
    mp.msg.error(err)
end
```

## 模块清单

| 模块          | 说明 |
| ---           | --- |
| `std`         | 基础工具函数、类系统和异常封装。包含 `round`、`clamp`、`split`、`trim`、`class`、`try/catch/finally` 等。 |
| `json`        | JSON 编码/解码，提供 `dumps`、`loads` 和 `json.null`。 |
| `hashlib`     | 纯 Lua 哈希函数集合，并导出 `base64_encode` / `base64_decode`。 |
| `copy`        | `deep_copy` 与 `shallow_copy`。 |
| `fs`          | 基于 `fstool` 的同步文件系统工具：`exists`、`create_dir` / `mkdir`、`remove_dir`、`copy`、`get_size`。 |
| `aiofs`       | 基于 `asyncio` 与 mpv async command 的异步文件系统工具。 |
| `asyncio`     | 协程式异步工具：`run`、`async`、`await`、`create_task`、`sleep`、`wait`、`gather` 等。 |
| `mptl`        | mpv 工具层，目前封装 `mp.command_native` subprocess 与异步 subprocess。 |
| `lockfile`    | 跨进程锁文件封装，按平台加载实现，Windows 下基于 Win32 API。 |
| `socket`      | LuaSocket 入口。 |
| `websocket`   | 同步 WebSocket 客户端/服务端入口。 |
| `rex`         | lrexlib PCRE2 封装，包含安全包装和 `unsafe` 原始入口。 |
| `lxp`         | LuaExpat XML SAX 解析器入口。 |
| `fun`         | Lua Fun 函数式迭代库，并包含 `str_concat` 扩展。 |
| `urlparse`    | URL 解析模块预留入口。 |

## 示例

JSON：

```lua
local json = require "elxlibs.json"

local text = json.dumps({items = {1, 2, 3}, empty = json.null}, 2)
local data = json.loads(text)
```

subprocess：

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

异步任务：

```lua
local asyncio = require "elxlibs.asyncio"

asyncio.run(asyncio.async(function()
    mp.msg.info("before")
    asyncio.await(asyncio.sleep(1))
    mp.msg.info("after")
end))
```

## 目录结构

```text
elxlib/
├── init.lua              # 入口模块，注册加载路径和模块别名
├── main.lua              # mpv 脚本占位入口
├── bin/                  # C 扩展 DLL 与辅助可执行文件
└── elxlibs/              # 各功能模块
```

## 使用到的第三方项目

- [Base64](https://github.com/Reselim/Base64) `/hashlib/base64.lua`  
  A pretty fast Luau Base64 encoder/decoder.
- [pure_lua_SHA](https://github.com/Egor-Skriptunoff/pure_lua_SHA) `/hashlib/sha.lua`  
  SHA1, SHA2, SHA3, BLAKE2 and BLAKE3 functions written in pure Lua and optimized for speed.
- [json.lua](https://github.com/rxi/json.lua) `/json/{decode,encode}.lua`  
  A lightweight JSON library for Lua.
- [luaexpat](https://github.com/lunarmodules/luaexpat) `/lxp`  
  LuaExpat is a SAX XML parser based on the Expat library.
- [lrexlib](https://github.com/rrthomas/lrexlib) `/rex`  
  A Lua binding of various regex library APIs.
- [luasocket](https://github.com/lunarmodules/luasocket) `/socket`  
  Network support for the Lua language.
- [luafun](https://github.com/luafun/luafun) `/fun/init.lua`  
  A high-performance functional programming library for LuaJIT.

## 许可证

本项目使用 MIT License，详见 [LICENSE](LICENSE)。
