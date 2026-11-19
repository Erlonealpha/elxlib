local F = require 'mpv_luatest.framework'
local std = require 'elxlibs.std'
local S = require 'test_std.support'

F.section('std utilities and exports')

F.test('split uses literal delimiters, keeps empty fields and supports limits', function()
    local fields = std.split('a.*b.*', '.*')
    F.eq(#fields, 3, 'pattern characters treated literally')
    F.eq(fields[2], 'b', 'middle field')
    F.eq(fields[3], '', 'trailing empty field')
    local empty = std.split(',a,,b', ',')
    F.eq(empty[1], '', 'leading empty field')
    F.eq(empty[3], '', 'adjacent delimiters')
    F.eq(std.split('', ',')[1], '', 'empty input retained')
    F.eq(std.split('abc', ',')[1], 'abc', 'no delimiter')
    local limited = std.split('a,b,c', ',', 1)
    F.eq(#limited, 2, 'one split')
    F.eq(limited[2], 'b,c', 'unsplit suffix')
    F.eq(std.split('a,b', ',', 0)[1], 'a,b', 'zero splits')
    F.raises(function() std.split('abc', '') end, 'ValueError', 'empty separator rejected')
end)

F.test('trim and comma_split normalize whitespace and validate input', function()
    F.eq(std.trim(' \t hello\r\n'), 'hello', 'outer whitespace removed')
    F.eq(std.trim('a b'), 'a b', 'inner whitespace kept')
    F.eq(std.trim(' \t'), '', 'whitespace-only string')
    local fields = std.comma_split(' a, b ,c, ')
    F.eq(#fields, 4, 'comma fields found')
    F.eq(table.concat(fields, '|'), 'a|b|c|', 'fields trimmed')
    F.eq(#std.comma_split(''), 0, 'empty input')
    F.eq(#std.comma_split(' \n'), 0, 'whitespace input')
    F.eq(#std.comma_split(nil), 0, 'missing input')
    F.raises(function() std.comma_split(S.runtime({})) end, 'TypeError', 'non-string rejected')
end)

F.test('aggregate exports are the direct class and exception objects', function()
    F.eq(std.class, require 'elxlibs.std.class', 'class module identity')
    F.eq(std.exception, require 'elxlibs.std.exception', 'exception module identity')
    for _, name in ipairs({'super', 'kindof', 'issubclass', 'isinstance'}) do
        F.eq(std[name], std.class[name], name .. ' identity')
    end
    for _, name in ipairs({'raise', 'try', 'catch', 'finally', 'xpcall', 'pcall', 'traceback',
        'BaseException', 'Exception', 'RuntimeError', 'TypeError', 'ValueError', 'IndexError',
        'KeyError', 'AttributeError', 'NotImplementedError', 'AssertionError', 'EOFError',
        'IOError', 'OSError', 'ImportError', 'MemoryError', 'TimeoutError'}) do
        F.eq(std[name], std.exception[name], name .. ' identity')
    end
end)
