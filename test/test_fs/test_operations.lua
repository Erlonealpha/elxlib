local F = require 'mpv_luatest.framework'
local S = require 'test_fs.support'

F.section('fs subprocess contracts')

F.test('every operation forwards paths, flags and capture options', function()
    S.with_host(function(fs, host)
        local path = 'folder 中文/a "quoted" name'
        F.eq(fs.mkdir, fs.create_dir, 'mkdir alias')
        F.eq(fs.exists(path), true, 'exists true')
        host.result.stdout = 'false\n'
        F.eq(fs.exists(path), false, 'missing is successful false')
        F.eq(fs.create_dir(path), true, 'default mkdir')
        F.eq(host.calls[#host.calls].args[6], '-e', 'exists_ok defaults true')
        fs.create_dir(path, false)
        F.eq(#host.calls[#host.calls].args, 5, 'explicit false omits exists_ok')
        fs.remove_dir(path, true)
        F.eq(host.calls[#host.calls].args[6], '-r', 'recursive removal')
        fs.copy(path, 'destination space', true)
        local args = host.calls[#host.calls].args
        F.eq(args[4], '-s', 'copy source flag')
        F.eq(args[5], path, 'copy source stays one argument')
        F.eq(args[7], 'destination space', 'copy destination stays one argument')
        F.eq(args[8], '-r', 'recursive copy')
        host.result.stdout = '12345\n'
        F.eq(fs.get_size(path, true), 12345, 'size parsed')
        F.eq(host.calls[#host.calls].args[6], '-r', 'recursive size')
        host.result.stdout = 'st_mode=33188 st_size=12 st_mtime=-1 st_mtime_ns=-1000000000 st_file_attributes=32'
        local stat = assert(fs.get_stat(path))
        F.eq(stat.st_size, 12, 'stat size')
        F.eq(stat.st_mtime, -1, 'signed timestamps')
        F.eq(stat.st_mtime_ns, -1000000000, 'nanosecond field with two underscores')
        F.eq(stat.st_file_attributes, 32, 'platform field with two underscores')
        F.eq(host.calls[#host.calls].args[3], 'get_stat', 'stat command')
        for _, opts in ipairs(host.calls) do
            F.eq(opts.name, 'subprocess', 'real mptl adapter used')
            F.eq(opts.playback_only, false, 'subprocess independent of playback')
            F.eq(opts.capture_stdout, true, 'stdout captured')
            F.eq(opts.capture_stderr, true, 'stderr captured')
            F.eq(opts.args[1], 'X:/scripts/elxlib/bin/fstool.exe', 'Windows tool path')
        end
    end)
    S.with_host(function(fs)
        F.eq(fs._exists_cmd('p')[1], 'X:/scripts/elxlib/bin/fstool', 'non-Windows tool name')
    end, 'linux')
end)

F.test('transport errors and nonzero statuses retain failure conventions', function()
    S.with_host(function(fs, host)
        for _, item in ipairs({{'exists', nil}, {'create_dir', false}, {'remove_dir', false},
            {'copy', false}, {'get_size', nil}, {'get_stat', nil}}) do
            local invoke = fs[item[1]]
            host.result = nil; host.error = 'transport error'
            local value, err = invoke('p', 'd')
            F.eq(value, item[2], item[1] .. ' transport failure result')
            F.eq(err, 'transport error', item[1] .. ' transport failure error')
            host.result = {status = 7, stdout = '', stderr = 'tool failed'}; host.error = nil
            value, err = invoke('p', 'd')
            F.eq(value, item[2], item[1] .. ' tool failure result')
            F.eq(err, 'fs.' .. item[1] .. ': tool failed', item[1] .. ' tool failure context')
        end
    end)
end)
