--[[@
    RFC 6455 数据帧编码与解码。
]]

local bit = require("websocket.bit")
local tools = require("websocket.tools")

local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local rshift = bit.rshift

local M = {
    CONTINUATION = 0x0,
    TEXT = 0x1,
    BINARY = 0x2,
    CLOSE = 0x8,
    PING = 0x9,
    PONG = 0xA,
}

local FIN = 0x80
local MASK = 0x80

local function mask_payload(payload, key)
    local out = {}
    for i = 1, #payload do
        local key_byte = key:byte((i - 1) % 4 + 1)
        out[i] = string.char(bxor(payload:byte(i), key_byte))
    end
    return table.concat(out)
end

local function random_mask()
    local key = {}
    for i = 1, 4 do
        key[i] = string.char(math.random(0, 255))
    end
    return table.concat(key)
end

local function encode_length(length)
    if length < 126 then
        return string.char(length)
    end
    if length <= 0xffff then
        return string.char(126) .. tools.write_int16(length)
    end
    local high = math.floor(length / 0x100000000)
    local low = length - high * 0x100000000
    return string.char(127) .. tools.write_uint32(high) .. tools.write_uint32(low)
end

--- 编码一个 WebSocket 数据帧。
---@param payload string 负载。
---@param opcode integer 帧操作码。
---@param masked boolean 是否添加掩码。
---@param fin? boolean 是否为消息的最后一帧。
---@return string encoded 编码后的完整帧。
function M.encode(payload, opcode, masked, fin)
    assert(type(payload) == "string", "帧负载必须是字符串")
    opcode = opcode or M.TEXT
    fin = fin ~= false

    local first = opcode
    if fin then
        first = bor(first, FIN)
    end

    local length = #payload
    local second = encode_length(length):byte(1)
    local extra_length = encode_length(length):sub(2)
    local mask_key = ""

    if masked then
        second = bor(second, MASK)
        mask_key = random_mask()
        payload = mask_payload(payload, mask_key)
    end

    return string.char(first, second) .. extra_length .. mask_key .. payload
end

--- 解码一个完整或部分 WebSocket 帧。
--- 当输入数据不足时，第二返回值为还需要读取的字节数。
---@param encoded string 缓冲区。
---@return string|nil payload 解码后的负载；数据不足时为 `nil`。
---@return boolean|integer fin 是否结束；数据不足时表示还需读取的字节数。
---@return integer|nil opcode 操作码。
---@return string rest 后续尚未消费的数据。
---@return boolean|nil masked 是否带掩码。
---@return string|nil err 协议错误说明。
function M.decode(encoded)
    if #encoded < 2 then
        return nil, 2 - #encoded
    end

    local first = encoded:byte(1)
    local second = encoded:byte(2)
    local fin = band(first, FIN) ~= 0
    local rsv = band(first, 0x70)
    local opcode = band(first, 0x0f)
    local masked = band(second, MASK) ~= 0
    local length_code = band(second, 0x7f)

    if rsv ~= 0 then
        return nil, nil, nil, nil, nil, "不支持 RSV 扩展位"
    end

    if opcode ~= M.CONTINUATION and opcode ~= M.TEXT and opcode ~= M.BINARY
        and opcode ~= M.CLOSE and opcode ~= M.PING and opcode ~= M.PONG then
        return nil, nil, nil, nil, nil, "未知 WebSocket 操作码: " .. opcode
    end

    local position = 3
    local length
    if length_code < 126 then
        length = length_code
    elseif length_code == 126 then
        if #encoded < position + 1 then
            return nil, position + 1 - #encoded
        end
        position, length = tools.read_int16(encoded, position)
    else
        if #encoded < position + 7 then
            return nil, position + 7 - #encoded
        end
        local next_position, high, low = tools.read_uint32(encoded, position)
        position = next_position
        local _, low_value = tools.read_uint32(encoded, position)
        low = low_value or low
        position = position + 4
        if high > 0x1fffff then
            return nil, nil, nil, nil, nil, "帧负载长度超过 Lua 可安全表示的范围"
        end
        length = high * 0x100000000 + low
    end

    if (opcode == M.CLOSE or opcode == M.PING or opcode == M.PONG) and length > 125 then
        return nil, nil, nil, nil, nil, "控制帧负载不能超过 125 字节"
    end

    local key = ""
    if masked then
        if #encoded < position + 3 then
            return nil, position + 3 - #encoded
        end
        key = encoded:sub(position, position + 3)
        position = position + 4
    end

    local available = #encoded - position + 1
    if available < length then
        return nil, length - available
    end

    local payload = encoded:sub(position, position + length - 1)
    local consumed = position + length
    local rest = encoded:sub(consumed)
    if masked then
        payload = mask_payload(payload, key)
    end

    return payload, fin, opcode, rest, masked
end

--- 编码关闭帧负载。
---@param code? integer 关闭状态码。
---@param reason? string 关闭原因。
---@return string payload
function M.encode_close(code, reason)
    if code == nil then
        return ""
    end
    if code < 1000 or code >= 5000 then
        error("无效的 WebSocket 关闭码: " .. tostring(code))
    end
    reason = reason or ""
    if #reason > 123 then
        error("WebSocket 关闭原因过长")
    end
    return tools.write_int16(code) .. reason
end

--- 解析关闭帧负载。
---@param data string
---@return integer|nil code
---@return string reason
function M.decode_close(data)
    if #data == 0 then
        return nil, ""
    end
    if #data == 1 then
        return nil, "无效的关闭帧负载"
    end
    local _, code = tools.read_int16(data, 1)
    return code, data:sub(3)
end

return M
