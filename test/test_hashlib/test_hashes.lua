local F = require 'mpv_luatest.framework'
local H = require 'elxlibs.hashlib'
local sha = require 'elxlibs.hashlib.sha'

-- Runtime dispatch spans functions with different parameter/streaming overloads.
---@param name string
---@return fun(...:any):any
local function exported(name) return H[name] --[[@as fun(...:any):any]] end

F.section('hashlib hashes')

-- Independently checked with Python hashlib/OpenSSL for the message "abc".
local vectors = {
    {name = 'md5', digest = '900150983cd24fb0d6963f7d28e17f72'},
    {name = 'sha1', digest = 'a9993e364706816aba3e25717850c26c9cd0d89d'},
    {name = 'sha224', digest = '23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7'},
    {name = 'sha256', digest = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'},
    {name = 'sha512_224', digest = '4634270f707b6a54daae7530460842e20e37ed265ceee9a43e8924aa'},
    {name = 'sha512_256', digest = '53048e2681941ef99b2e29b76b4c7dabe4c2d0c634fc6d46e0e2f13107e7af23'},
    {name = 'sha384', digest = 'cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7'},
    {name = 'sha512', digest = 'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f'},
    {name = 'sha3_224', digest = 'e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf'},
    {name = 'sha3_256', digest = '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532'},
    {name = 'sha3_384', digest = 'ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25'},
    {name = 'sha3_512', digest = 'b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0'},
    {name = 'blake2b', digest = 'ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923'},
    {name = 'blake2s', digest = '508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982'},
}

F.test('known digest vectors and streaming lifecycle', function()
    for _, vector in ipairs(vectors) do
        local hash = exported(vector.name)
        F.eq(hash, sha[vector.name], vector.name .. ' aggregate identity')
        F.eq(hash('abc'), vector.digest, vector.name .. ' vector')
        local feed = hash()
        feed('a'); feed(''); feed('bc')
        F.eq(feed(), vector.digest, vector.name .. ' partial digest')
        F.eq(feed(), vector.digest, vector.name .. ' repeated finalization')
        F.raises(function() feed('late') end, '', vector.name .. ' rejects input after finalization')
    end
end)

F.test('SHAKE vectors and binary block boundaries', function()
    local shake = {
        {name = 'shake128', digest = '5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8'},
        {name = 'shake256', digest = '483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739'},
    }
    for _, vector in ipairs(shake) do
        local hash = exported(vector.name)
        F.eq(hash(32, 'abc'), vector.digest, vector.name .. ' vector')
        local feed = hash(32); feed('ab'); feed('c')
        F.eq(feed(), vector.digest, vector.name .. ' streamed')
        F.eq(#hash(17, 'abc'), 34, vector.name .. ' output length in bytes')
    end
    local bytes = {}
    for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
    local binary = string.rep(table.concat(bytes), 32)
    local expected = 'dc404a613fedaeb54034514bc6505f56b933caa5250299ba7d094377a51caa46'
    F.eq(H.sha256(binary), expected, '8192-byte binary vector')
    local feed = H.sha256()
    for i = 1, #binary, 63 do feed(binary:sub(i, i + 62)) end
    F.eq(feed(), expected, 'chunks cross compression boundaries')
end)

F.test('HMAC and keyed/salted BLAKE2 vectors', function()
    local message = 'The quick brown fox jumps over the lazy dog'
    local expected = 'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8'
    F.eq(H.hmac(H.sha256, 'key', message), expected, 'HMAC-SHA256 vector')
    local feed = H.hmac(H.sha256, 'key'); feed(message:sub(1, 9)); feed(message:sub(10))
    F.eq(feed(), expected, 'streamed HMAC')
    F.eq(H.blake2b('abc', 'key', 'salt', 20), 'a0c56fd509bb3dee11385596c6b35623a2364a7b', 'BLAKE2b parameters')
    F.eq(H.blake2s('abc', 'key', 'salt', 20), '4bae7c7f84daf781eb64a2f2a16ec3914ebd70f5', 'BLAKE2s parameters')
    F.raises(function() H.blake2b('a', string.rep('x', 65)) end, '', 'oversize BLAKE2b key rejected')
    F.raises(function() H.blake2s('a', '', string.rep('x', 17)) end, '', 'oversize BLAKE2s salt rejected')
    F.raises(function() H.blake2b('a', '', '', 0) end, '', 'invalid digest size rejected')
end)

F.test('BLAKE aliases, parallel/XOF streaming and BLAKE3', function()
    F.eq(H.blake2, H.blake2b, 'blake2 alias')
    F.eq(H.blake2b_512, H.blake2b, '512-bit alias')
    F.eq(H.blake2s_256, H.blake2s, '256-bit alias')
    for _, item in ipairs({{'blake2b_160', 'blake2b', 20}, {'blake2b_256', 'blake2b', 32},
        {'blake2b_384', 'blake2b', 48}, {'blake2s_128', 'blake2s', 16},
        {'blake2s_160', 'blake2s', 20}, {'blake2s_224', 'blake2s', 28}}) do
        F.eq(H[item[1]]('abc'), H[item[2]]('abc', nil, nil, item[3]), item[1] .. ' digest size')
    end
    local message = string.rep('binary\0', 400)
    for _, name in ipairs({'blake2bp', 'blake2sp', 'blake3'}) do
        local hash = exported(name)
        local feed = hash(); feed(message:sub(1, 511)); feed(message:sub(512))
        F.eq(feed(), hash(message), name .. ' tree boundary streaming')
    end
    for _, name in ipairs({'blake2xb', 'blake2xs'}) do
        local hash = exported(name)
        local feed = hash(65); feed('a'); feed('bc')
        F.eq(feed(), hash(65, 'abc'), name .. ' streamed XOF')
        F.eq(#hash(65, 'abc'), 130, name .. ' XOF length')
    end
    F.eq(H.blake3(''), 'af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262', 'official BLAKE3 empty vector')
    local feed = exported('blake3_derive_key')(nil, 'elxlib test context', 48); feed('a'); feed('bc')
    F.eq(feed(), H.blake3_derive_key('abc', 'elxlib test context', 48), 'streamed key derivation')
    F.ok(H.blake3_derive_key('abc', 'context A') ~= H.blake3_derive_key('abc', 'context B'), 'contexts separate derived keys')
    F.raises(function() H.blake3('a', string.rep('x', 33)) end, '', 'oversize BLAKE3 key rejected')
end)
