local F = require 'mpv_luatest.framework'
local S = require 'test_aiofs.support'

F.section('aiofs coroutine and subprocess contracts')

F.test('operations are lazy and every command/result is adapted', function()
    S.with_adapter(function(fs, A, adapter)
        local lazy = fs.exists('path space 中文')
        F.eq(#adapter.calls, 0, 'creating coroutine starts no subprocess')
        F.eq(fs.fs, require 'elxlibs.fs', 'sync fs identity')
        S.run(A, A.async(function()
            adapter.response = {success = true, result = {status = 0, stdout = 'false\n'}}
            local result = A.await(lazy)
            F.eq(result.ok, true, 'exists success')
            F.eq(result.result, false, 'missing is a successful false result')
            F.eq(adapter.calls[1].opts.args[5], 'path space 中文', 'path stays one argument')
            adapter.response.result.stdout = 'true\n'
            F.eq(A.await(fs.exists('p')).result, true, 'exists true')
            for _, item in ipairs({{'create_dir', 'mkdir'}, {'remove_dir', 'rmdir'}, {'copy', 'copy'}}) do
                local invoke = fs[item[1]]
                result = A.await(invoke('source', 'destination', true))
                F.eq(result.ok, true, item[1] .. ' success')
                F.eq(result.result, nil, item[1] .. ' no payload')
                F.eq(adapter.calls[#adapter.calls].opts.args[3], item[2], item[1] .. ' command')
            end
            A.await(fs.create_dir('p'))
            F.eq(adapter.calls[#adapter.calls].opts.args[6], '-e', 'default exists_ok')
            A.await(fs.create_dir('p', false))
            F.eq(#adapter.calls[#adapter.calls].opts.args, 5, 'false exists_ok')
            A.await(fs.remove_dir('p', true))
            F.eq(adapter.calls[#adapter.calls].opts.args[6], '-r', 'recursive removal')
            A.await(fs.copy('s', 'd', true))
            F.eq(adapter.calls[#adapter.calls].opts.args[8], '-r', 'recursive copy')
            adapter.response.result.stdout = '42\n'
            F.eq(A.await(fs.get_size('p', true)).result, 42, 'size parsed')
            F.eq(adapter.calls[#adapter.calls].opts.args[6], '-r', 'recursive size')
            adapter.response.result.stdout = 'st_size=42 st_mtime_ns=-12 st_file_attributes=32'
            local stat = assert(A.await(fs.get_stat('p')).result)
            F.eq(stat.st_size, 42, 'stat size')
            F.eq(stat.st_mtime_ns, -12, 'shared signed stat parser')
            F.eq(stat.st_file_attributes, 32, 'shared platform field parser')
            for _, call in ipairs(adapter.calls) do
                F.eq(call.opts.name, 'subprocess', 'subprocess native command')
                F.eq(call.opts.playback_only, false, 'independent of playback')
                F.eq(call.opts.capture_stdout, true, 'capture stdout')
                F.eq(call.opts.capture_stderr, true, 'capture stderr')
            end
            F.eq(#adapter.aborted, 0, 'completed commands need no abort')
        end))
    end)
end)

F.test('concurrent operations own separate handles', function()
    S.with_adapter(function(fs, A, adapter)
        S.run(A, A.async(function()
            local first = A.create_task(fs.exists('first'))
            local second = A.create_task(fs.get_size('second'))
            A.await(A.sleep(0))
            F.eq(#adapter.calls, 2, 'both operations started')
            first:cancel()
            F.eq(A.try_await(first), false, 'first operation cancelled')
            F.eq(#adapter.aborted, 1, 'one abort only')
            F.eq(adapter.aborted[1], adapter.calls[1].token, 'first command owns abort')
            F.eq(second:done(), false, 'other operation remains pending')
            adapter.reply(2, true, {status = 0, stdout = '17'})
            F.eq(A.await(second).result, 17, 'other operation still completes')
        end))
    end)
end)

F.test('transport, missing results and tool failures resolve without callback errors', function()
    S.with_adapter(function(fs, A, adapter)
        S.run(A, A.async(function()
            for _, response in ipairs({{success = false, error = 'transport'},
                {success = false}, {success = true},
                {success = true, result = {status = 3, stderr = 'tool failed'}}}) do
                adapter.response = response
                local result = A.await(fs.exists('p'))
                F.eq(result.ok, false, 'failure returned')
                F.eq(result.result, nil, 'no failure payload')
                F.ok(type(result.error) == 'string' and #result.error > 0, 'failure always has message')
                if response.error then F.eq(result.error, response.error, 'transport detail') end
                if response.result then F.eq(result.error, 'tool failed', 'stderr detail') end
            end
            adapter.response = {success = true, result = {status = 0, stdout = nil}}
            local result = A.await(fs.get_size('p'))
            F.eq(result.ok, false, 'malformed output resolves as failure')
            F.ok(type(result.error) == 'string', 'parse error reported')
        end))
    end)
end)

F.test('failed launch resolves even when adapter supplies no callback', function()
    S.with_adapter(function(fs, A, adapter)
        adapter.launch_error = 'cannot launch'
        S.run(A, A.async(function()
            local result = A.await(fs.get_stat('p'))
            F.eq(result.ok, false, 'launch failure')
            F.eq(result.error, 'cannot launch', 'launch error retained')
        end))
    end)
end)

F.test('cancellation aborts its command and ignores late or duplicate callbacks', function()
    S.with_adapter(function(fs, A, adapter)
        S.run(A, A.async(function()
            local task = A.create_task(fs.copy('s', 'd'))
            A.await(A.sleep(0))
            F.eq(#adapter.calls, 1, 'command started')
            F.eq(task:cancel(), true, 'cancel pending operation')
            local ok, err = A.try_await(task)
            F.eq(ok, false, 'cancellation propagates')
            F.eq(require('elxlibs.std').isinstance(err, require('elxlibs.asyncio.exceptions').CancelledError), true, 'CancelledError identity')
            F.eq(adapter.aborted[1], adapter.calls[1].token, 'abort owned handle')
            F.eq(pcall(adapter.reply, 1, true, {status = 0, stdout = ''}), true, 'late success ignored')
            F.eq(pcall(adapter.reply, 1, false, nil, 'late failure'), true, 'late failure ignored')
            local finished = A.create_task(fs.exists('p'))
            A.await(A.sleep(0))
            adapter.reply(2, true, {status = 0, stdout = 'true'})
            F.eq(A.await(finished).result, true, 'normal completion')
            F.eq(pcall(adapter.reply, 2, true, {status = 0, stdout = 'false'}), true, 'duplicate ignored')
            F.eq(finished:result().result, true, 'first result retained')
            F.eq(#adapter.aborted, 1, 'only cancelled handle aborted')
        end))
    end)
end)
