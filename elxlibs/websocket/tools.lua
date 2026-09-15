--[[@
    WebSocket 内部工具。

    该模块只提供协议编码所需的基础二进制、SHA-1、Base64 和 URL 工具。
]]

local bit = require("websocket.bit")
local mime = require("mime")

local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local bnot = bit.bnot
local lshift = bit.lshift
local rshift = bit.rshift
local rol = bit.rol
local unpack = table.unpack or unpack

local function read_bytes(data, position, count)
    position = position or 1
    local bytes = { data:byte(position, position + count - 1) }
    if #bytes ~= count then
        return nil, "incomplete data"
    end
    return position + count, unpack(bytes)
end

local function read_int8(data, position)
    return read_bytes(data, position, 1)
end

local function read_int16(data, position)
    local next_position, a, b = read_bytes(data, position, 2)
    if not next_position then
        return nil, "incomplete data"
    end
    return next_position, lshift(a, 8) + b
end

local function read_uint32(data, position)
    local next_position, a, b, c, d = read_bytes(data, position, 4)
    if not next_position then
        return nil, "incomplete data"
    end
    return next_position,
        lshift(a, 24) + lshift(b, 16) + lshift(c, 8) + d
end

local function uint32_bytes(value)
    return string.char(
        band(rshift(value, 24), 0xff),
        band(rshift(value, 16), 0xff),
        band(rshift(value, 8), 0xff),
        band(value, 0xff)
    )
end

local function write_int8(value)
    return string.char(band(value, 0xff))
end

local function write_int16(value)
    return string.char(
        band(rshift(value, 8), 0xff),
        band(value, 0xff)
    )
end

local function write_uint32(value)
    return uint32_bytes(value)
end

-- SHA-1，遵循 FIPS PUB 180-4 的消息扩展和压缩过程。
local function sha1(data)
    local bit_length = #data * 8
    data = data .. string.char(0x80)

    local remainder = (#data + 8) % 64
    local padding = (64 - remainder) % 64
    if padding > 0 then
        data = data .. string.rep("\0", padding)
    end

    local high = math.floor(bit_length / 0x100000000)
    local low = bit_length - high * 0x100000000
    data = data .. write_uint32(high) .. write_uint32(low)

    local h0 = 0x67452301
    local h1 = 0xEFCDAB89
    local h2 = 0x98BADCFE
    local h3 = 0x10325476
    local h4 = 0xC3D2E1F0

    for offset = 1, #data, 64 do
        local block = data:sub(offset, offset + 63)
        local words = {}
        local position = 1
        for i = 1, 16 do
            position, words[i] = read_uint32(block, position)
        end
        for i = 17, 80 do
            words[i] = rol(bxor(words[i - 3], words[i - 8], words[i - 14], words[i - 16]), 1)
        end

        local a, b, c, d, e = h0, h1, h2, h3, h4
        for i = 1, 80 do
            local f, k
            if i <= 20 then
                f = bor(band(b, c), band(bnot(b), d))
                k = 0x5A827999
            elseif i <= 40 then
                f = bxor(b, c, d)
                k = 0x6ED9EBA1
            elseif i <= 60 then
                f = bor(band(b, c), band(b, d), band(c, d))
                k = 0x8F1BBCDC
            else
                f = bxor(b, c, d)
                k = 0xCA62C1D6
            end
            local temp = (rol(a, 5) + f + e + k + words[i]) % 0x100000000
            e = d
            d = c
            c = rol(b, 30)
            b = a
            a = temp
        end

        h0 = (h0 + a) % 0x100000000
        h1 = (h1 + b) % 0x100000000
        h2 = (h2 + c) % 0x100000000
        h3 = (h3 + d) % 0x100000000
        h4 = (h4 + e) % 0x100000000
    end

    return uint32_bytes(h0)
        .. uint32_bytes(h1)
        .. uint32_bytes(h2)
        .. uint32_bytes(h3)
        .. uint32_bytes(h4)
end

local DEFAULT_PORTS = {
    ws = 80,
    wss = 443,
}

local function parse_url(value)
    if type(value) ~= "string" then
        return nil, "WebSocket URL 必须是字符串"
    end

    local protocol, authority, uri = value:match("^(%a[%w+.-]*)://([^/]+)(.*)$")
    if not protocol then
        return nil, "无效的 WebSocket URL: " .. value
    end
    ---@cast authority -?
    ---@cast uri -?

    protocol = protocol:lower()
    if protocol ~= "ws" and protocol ~= "wss" then
        return nil, "不支持的 WebSocket 协议: " .. protocol
    end

    local host, port = authority:match("^%[([^%]]+)%]:(%d+)$")
    if not host then
        host, port = authority:match("^%[([^%]]+)%]$")
    end
    if not host then
        host, port = authority:match("^(.+):(%d+)$")
    end
    if not host then
        host = authority
    end

    port = tonumber(port) or DEFAULT_PORTS[protocol]
    uri = uri == "" and "/" or uri

    return protocol, host, port, uri
end

local function generate_key()
    local bytes = {}
    for i = 1, 16 do
        bytes[i] = string.char(math.random(0, 255))
    end
    return mime.b64(table.concat(bytes))
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

---@return string
local function base64_encode(data)
    return mime.b64(data)
end

local function has_token(header, token)
    token = token:lower()
    for value in header:gmatch("([^,]+)") do
        if trim(value):lower() == token then
            return true
        end
    end
    return false
end

return {
    sha1 = sha1,
    base64 = {
        encode = base64_encode,
    },
    parse_url = parse_url,
    generate_key = generate_key,
    has_token = has_token,
    trim = trim,
    read_int8 = read_int8,
    read_int16 = read_int16,
    read_uint32 = read_uint32,
    read_int32 = read_uint32,
    write_int8 = write_int8,
    write_int16 = write_int16,
    write_uint32 = write_uint32,
    write_int32 = write_uint32,
}
