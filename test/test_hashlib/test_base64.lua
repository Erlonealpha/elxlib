local F = require 'mpv_luatest.framework'
local H = require 'elxlibs.hashlib'
local Base64 = require 'elxlibs.hashlib.base64'

F.section('hashlib Base64 and binary conversions')

F.test('RFC 4648 vectors and exported aliases', function()
    F.eq(H.base64_encode, Base64.Encode, 'encoder identity')
    F.eq(H.base64_decode, Base64.Decode, 'decoder identity')
    for _, pair in ipairs({{'', ''}, {'f', 'Zg=='}, {'fo', 'Zm8='}, {'foo', 'Zm9v'},
        {'foob', 'Zm9vYg=='}, {'fooba', 'Zm9vYmE='}, {'foobar', 'Zm9vYmFy'}}) do
        F.eq(H.base64_encode(pair[1]), pair[2], 'RFC encode')
        F.eq(H.base64_decode(pair[2]), pair[1], 'RFC decode')
        F.eq(H.bin_to_base64(pair[1]), pair[2], 'SHA module encoder')
        F.eq(H.base64_to_bin(pair[2]), pair[1], 'SHA module decoder')
    end
    for _, pair in ipairs({{'hex2bin', 'hex_to_bin'}, {'bin2hex', 'bin_to_hex'},
        {'base642bin', 'base64_to_bin'}, {'bin2base64', 'bin_to_base64'}}) do
        F.eq(H[pair[1]], H[pair[2]], 'conversion alias identity')
    end
end)

F.test('binary data crosses Base64 output chunk boundaries', function()
    F.eq(H.base64_encode('\0\255\254'), 'AP/+', 'zero and high bytes vector')
    F.eq(H.hex_to_bin('00FfFe'), '\0\255\254', 'case-insensitive hex input')
    F.eq(H.bin_to_hex('\0\255\254'), '00fffe', 'lowercase hex output')
    local bytes = {}
    for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
    local binary = string.rep(table.concat(bytes), 24) .. '\0\255'
    local encoded = H.base64_encode(binary)
    F.eq(encoded, H.bin_to_base64(binary), 'independent Base64 implementations agree')
    F.eq(H.base64_decode(encoded), binary, 'decode past 4096 output bytes')
    F.eq(H.hex_to_bin(H.bin_to_hex(binary)), binary, 'large binary hex round trip')
end)
