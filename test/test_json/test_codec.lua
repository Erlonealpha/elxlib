local F = require 'mpv_luatest.framework'
local json = require 'elxlibs.json'
local Encoder = require 'elxlibs.json.encode'
local Decoder = require 'elxlibs.json.decode'

F.section('json codec')

F.test('scalars, escapes, Unicode and nested structures round trip', function()
    for _, value in ipairs({true, false, 0, -12.25, 'quote" slash\\ newline\n tab\t\0', '中文 😀'}) do
        F.eq(json.loads(json.dumps(value)), value, 'scalar round trip')
    end
    F.eq(json.dumps(nil), 'null', 'nil encoded as null')
    F.eq(json.loads('null'), nil, 'default null decoded as nil')
    F.eq(json.loads('"\\u4e2d\\u6587"'), '中文', 'Unicode escapes')
    F.eq(json.loads('"\\ud83d\\ude00"'), '😀', 'surrogate pair')
    F.eq(json.loads('"\\b\\f\\r\\n\\t\\/"'), '\b\f\r\n\t/', 'JSON escapes')
    local value = json.loads(' { "a": [1, false, {"name":"v"}], "b": -1.2e3 } ')
    F.eq(value.a[2], false, 'nested boolean')
    F.eq(value.a[3].name, 'v', 'nested object')
    F.eq(value.b, -1200, 'exponent number')
    local decoded = json.loads(json.dumps(value))
    F.eq(decoded.a[1], 1, 'nested round trip')
    F.eq(decoded.b, -1200, 'object round trip')
end)

F.test('null placeholders preserve array positions and repeated sentinels', function()
    local value = json.loads('[null,1,null]', json.null)
    F.eq(value[1], json.null, 'first null sentinel')
    F.eq(value[3], json.null, 'last null sentinel')
    F.eq(json.dumps(value), '[null,1,null]', 'repeated sentinel encoded')
    F.eq(json.dumps({a = json.null, b = json.null}):find('null') ~= nil, true, 'object sentinel')
    local false_values = json.loads('[null,false]', false)
    F.eq(false_values[1], false, 'false is a valid decode placeholder')
    F.eq(json.dumps(nil, nil, false), 'false', 'false encode placeholder kept')
    F.eq(tostring(json.null), 'null', 'sentinel representation')
end)

F.test('pretty formatting and custom encoder/decoder hooks', function()
    local encoded = json.dumps({1, {name = 'v'}}, 2)
    F.contains(encoded, '\n  1,', 'array indentation')
    F.contains(encoded, '\n    "name": "v"', 'nested object indentation')
    F.eq(json.dumps({}, 2), '[]', 'empty table encodes as array')
    local custom = {encode = function(_, value, indent, placeholder, fallback)
        F.eq(value.key, 1, 'custom encoder input')
        F.eq(indent, 3, 'custom indent forwarded')
        F.eq(placeholder, json.null, 'custom placeholder forwarded')
        F.eq(type(fallback), 'function', 'custom fallback forwarded')
        return 'custom-output'
    end}
    F.eq(json.dumps({key = 1}, 3, nil, custom, function() return 'null' end),
        'custom-output', 'custom encoder result')
    local decoder = {decode = function(_, value) return {input = value} end}
    F.eq(json.loads('input', nil, decoder).input, 'input', 'custom decoder result')
    local reused = Encoder.new(nil, json.null)
    F.eq(reused:encode({1}, 2), '[\n  1\n]', 'direct encoder configuration')
    F.eq(Decoder.new(json.null):decode('null'), json.null, 'direct decoder placeholder')
end)

F.test('encoder rejects cycles, sparse/mixed tables, nonfinite numbers and unsupported types', function()
    local circular = {}; circular.self = circular
    F.raises(function() json.dumps(circular) end, 'circular', 'cycle rejected')
    F.raises(function() json.dumps({[1] = 'a', [3] = 'c'}) end, 'sparse', 'sparse array rejected')
    F.raises(function() json.dumps({[1] = 'a', name = 'b'}) end, 'key types', 'mixed keys rejected')
    for _, value in ipairs({math.huge, -math.huge, 0 / 0}) do
        F.raises(function() json.dumps(value) end, 'unexpected number', 'nonfinite value rejected')
    end
    F.raises(function() json.dumps(function() end) end, 'unexpected type', 'function rejected')
    F.eq(json.dumps({function() end}, nil, nil, nil, function() return '"fallback"' end),
        '["fallback"]', 'fallback emits JSON fragment')
    local shared = {key = 'shared'}
    local decoded = json.loads(json.dumps({shared, shared}))
    F.eq(decoded[2].key, 'shared', 'non-cyclic shared object accepted')
end)

F.test('decoder rejects malformed syntax with source positions', function()
    for _, value in ipairs({'', '[1,]', '{"a":1,}', '{a:1}', '{"a" 1}', '[1 2]',
        '"unterminated', '"\\q"', '"\\uZZZZ"', 'true false', 'nope', '1e',
        '01', '+1', '0x10', '1.', '"\\ud800"', '"\\ud800\\u0041"', '"\\udc00"'}) do
        F.raises(function() json.loads(value) end, 'line', 'invalid input ' .. value)
    end
    ---@type any Invalid runtime input
    local invalid = 42
    F.raises(function() Decoder.new():decode(invalid) end, 'string', 'non-string input rejected')
    F.raises(function() json.loads('[\n  ?]') end, 'line 2 col 3', 'line and column reported')
end)
