--[[@
    WebSocket 内部位运算适配层。

    优先使用 Lua 5.2+ 的 bit32；LuaJIT/Lua 5.1 则使用 luabitop。
]]

local ok, bit = pcall(require, "bit32")
if ok then
    bit.rol = bit.lrotate
    bit.ror = bit.rrotate
    return bit
end

return require("bit")
