# elxlib for MPV
适用于MPV的lua脚本集成库

# 集成功能


# 安装
elxlib 默认应该安装到 `~~/scripts` 路径中。

# 使用方式
受限于lua的包加载限制，需要先将库路径加入到 package.path 中。

```lua
local scripts_dir = mp.command_native({"expand-path", "~~/scripts"})
package.path = package.path .. ';' .. scripts_dir .. '/?/init.lua'
require 'elxlib'
```
接下来可以通过 `elxlibs.{package}?.{subname}` 或 `elxlib.{package}?.{subname}` 加载包。
```lua
local std = require 'elxlibs.std'
print(std.version)
> 'v0.1.0'
```

# 使用到的第三方项目
- [Base64](https://github.com/Reselim/Base64) /hashlib/base64.lua
  A pretty fast Luau Base64 encoder/decoder
- [pure_lua_SHA](https://github.com/Egor-Skriptunoff/pure_lua_SHA) /hashlib/sha.lua
  SHA1, SHA2, SHA3, BLAKE2 and BLAKE3 functions written in pure Lua and optimized for speed
- [json.lua](https://github.com/rxi/json.lua) /json/{decode,encode}.lua
  A lightweight JSON library for Lua
- [luaexpat](https://github.com/lunarmodules/luaexpat) /lxp
LuaExpat is a SAX XML parser based on the Expat library
- [lrexlib](https://github.com/rrthomas/lrexlib) /rex
A Lua (5.1 and later) binding of various regex library APIs (POSIX, PCRE, PCRE2, GNU, Oniguruma and TRE)
