local F = require 'mpv_luatest.framework'
local S = require 'support'
local amp_stub = require 'amp_stub'
local std = require 'elxlibs.std'

F.section('amp public adapters')

---@param script? table<integer, string|table>
local function boot(script)
    local stub = amp_stub.new({script = script or {[40] = 'shutdown'}, max_block = 0})
    local asyncio = S.reload_asyncio(stub)
    return require 'elxlibs.asyncio.amp', stub, asyncio
end

local function pump()
    local ok, err = pcall(_G.mp_event_loop)
    if not ok then error(err, 0) end
end

F.test('amp alias, host loop, warnings and event registration/removal', function()
    local amp, stub, asyncio = boot({[8] = 'file-loaded', [16] = 'file-loaded', [40] = 'shutdown'})
    F.eq(amp, require 'elxlibs.asyncio.mp', 'amp alias identity')
    F.eq(stub.asyncio_event_loop, true, 'host override flag')
    F.eq(_G.mp_event_loop_wrap, true, 'global override flag')
    F.eq(require 'elxlibs.asyncio.log', stub.msg, 'logging uses host messages')
    local loop = amp.EventLoop_mp()
    F.ok(std.isinstance(loop, asyncio.loops.EventLoop), 'host loop inherits base loop')
    F.ok(loop:time() >= 0, 'host clock available')
    loop:close()
    local removed, surviving = 0, 0
    local remove = function() removed = removed + 1 end
    amp.register_event('file-loaded', remove)
    amp.unregister_event(remove)
    ---@type fun(ev:table)
    local survivor
    survivor = function(ev)
        F.eq(ev.event, 'file-loaded', 'event payload forwarded')
        surviving = surviving + 1
        amp.unregister_event(survivor)
    end
    amp.register_event('file-loaded', survivor)
    stub.register_event('file-loaded', function() end)
    F.contains(stub.messages[#stub.messages], 'Use amp.register_event', 'old host API warns')
    pump()
    F.eq(removed, 0, 'removed callback not called')
    F.eq(surviving, 1, 'callback can unregister itself')
    local disabled = false
    for _, call in ipairs(stub.calls.request_event) do
        if call[1] == 'file-loaded' and call[2] == false then disabled = true end
    end
    F.eq(disabled, true, 'last handler removal disables raw event')
end)

F.test('script messages dispatch arguments and support replacement/removal', function()
    local amp = boot({
        [8] = {event = 'client-message', args = {'echo', 'a', 'b'}},
        [16] = {event = 'client-message', args = {'removed'}},
        [24] = {event = 'client-message', args = {}}, [40] = 'shutdown',
    })
    local got, old, removed = nil, 0, 0
    amp.register_script_message('echo', function() old = old + 1 end)
    amp.register_script_message('echo', function(a, b) got = a .. b end)
    amp.register_script_message('removed', function() removed = removed + 1 end)
    amp.unregister_script_message('removed')
    pump()
    F.eq(got, 'ab', 'message arguments forwarded')
    F.eq(old, 0, 'new registration replaces old')
    F.eq(removed, 0, 'removed and empty messages ignored')
end)

F.test('property observation routes raw IDs and unregisters every matching callback', function()
    local amp, stub = boot({
        [8] = {event = 'property-change', id = 1, name = 'volume', data = 42},
        [16] = {event = 'property-change', id = 2, name = 'pause', data = true},
        [24] = {event = 'property-change', id = 1, name = 'volume', data = 99},
        [40] = 'shutdown',
    })
    local values = {}
    ---@type fun(name:string, data:any)
    local callback
    callback = function(name, data)
        values[#values + 1] = name .. ':' .. tostring(data)
        if name == 'pause' then amp.unobserve_property(callback) end
    end
    amp.observe_property('volume', 'number', callback)
    amp.observe_property('pause', 'bool', callback)
    F.eq(assert(stub.calls.raw_observe_property[1])[1], 1, 'first raw ID')
    F.eq(assert(stub.calls.raw_observe_property[2])[3], 'bool', 'raw observation type')
    pump()
    F.eq(table.concat(values, ','), 'volume:42,pause:true', 'only live observations dispatched')
    F.eq(#stub.calls.raw_unobserve_property, 2, 'all callback observations unregistered')
end)

F.test('idle handlers can remove themselves and removed finally callbacks do not run', function()
    local amp = boot()
    local idle, final = 0, 0
    ---@type fun()
    local handler
    handler = function()
        idle = idle + 1
        amp.unregister_idle(handler)
    end
    amp.register_idle(handler)
    local removed = function() final = final + 100 end
    amp.add_finally(removed)
    amp.remove_finally(removed)
    amp.add_finally(function() final = final + 1 end)
    pump()
    F.eq(idle, 1, 'idle callback can remove itself')
    F.eq(final, 1, 'finally removal keeps remaining callbacks')
end)

F.test('key bindings dispatch keyboard/mouse/repeat/complex and removal', function()
    local amp, stub = boot({
        [8] = {event = 'client-message', args = {'key-binding', 'simple', 'd', 'A', ''}},
        [12] = {event = 'client-message', args = {'key-binding', 'simple', 'u', 'A', ''}},
        [16] = {event = 'client-message', args = {'key-binding', 'simple', 'r', 'A', ''}},
        [20] = {event = 'client-message', args = {'key-binding', 'simple', 'um', 'MOUSE', ''}},
        [24] = {event = 'client-message', args = {'key-binding', 'repeat', 'r', 'B', ''}},
        [28] = {event = 'client-message', args = {'key-binding', 'complex', 'umc', 'C', '', '2', 'arg'}},
        [32] = {event = 'client-message', args = {'removed'}},
        [36] = {event = 'client-message', args = {'complex'}}, [60] = 'shutdown',
    })
    local simple, repeated, removed, complex = 0, 0, 0, {}
    amp.add_key_binding('A', 'simple', function() simple = simple + 1 end)
    amp.add_forced_key_binding('B', 'repeat', function() repeated = repeated + 1 end, 'repeatable')
    amp.add_key_binding('C', 'complex', function(ev) complex[#complex + 1] = ev end,
        {complex = true, scalable = true, forced = true})
    amp.add_key_binding('D', 'removed', function() removed = removed + 1 end)
    amp.remove_key_binding('removed')
    amp.flush_keybindings()
    local sections = stub.calls.input_define_section
    F.contains(assert(sections[1])[2], 'simple', 'default section contains binding')
    F.contains(assert(sections[2])[2], 'repeat', 'forced section contains binding')
    F.contains(assert(sections[2])[2], 'complex', 'forced option honored')
    F.eq(#stub.calls.input_enable_section, 2, 'both sections enabled')
    local before = #sections
    amp.flush_keybindings()
    F.eq(#sections, before, 'clean flush does not rewrite sections')
    pump()
    F.eq(simple, 2, 'keyboard down and mouse up dispatch; nonrepeat ignores repeat')
    F.eq(repeated, 1, 'repeatable binding dispatches repeat')
    F.eq(removed, 0, 'binding removal also removes message')
    F.eq(complex[1].event, 'up', 'complex state decoded')
    F.eq(complex[1].canceled, true, 'complex cancellation flag')
    F.eq(complex[1].is_mouse, true, 'complex mouse flag')
    F.eq(complex[1].key_text, nil, 'empty key text normalized')
    F.eq(complex[1].scale, 2, 'scale parsed')
    F.eq(complex[1].arg, 'arg', 'argument forwarded')
    F.eq(complex[2].event, 'press', 'script message produces press')
end)

F.test('legacy bindings generate input commands and dispatch press/down/up', function()
    local amp, stub = boot({
        [8] = {event = 'client-message', args = {'key-binding', '__keybinding1', 'p'}},
        [16] = {event = 'client-message', args = {'key-binding', '__keybinding1', 'd'}},
        [24] = {event = 'client-message', args = {'key-binding', '__keybinding1', 'u'}},
        [32] = {event = 'client-message', args = {'key-binding', '__keybinding1', 'r'}},
        [40] = 'shutdown',
    })
    local order = {}
    amp.set_key_bindings({{'A', function() order[#order + 1] = 'press' end,
        function() order[#order + 1] = 'down' end,
        function() order[#order + 1] = 'up' end}, {'B', 'show-text example'}}, 'legacy')
    F.eq(assert(stub.calls.input_define_section[1])[1], 'legacy', 'requested section')
    F.contains(assert(stub.calls.input_define_section[1])[2], 'B show-text example', 'string command emitted')
    pump()
    F.eq(table.concat(order, ','), 'press,down,up', 'legacy dispatch states')
end)

F.test('timers run one-shot and periodic callbacks; stop/resume/kill preserve deadlines', function()
    local amp, stub = boot({[80] = 'shutdown'})
    local now = 0
    stub.get_time = function() return now end
    local wait = stub.wait_event
    stub.wait_event = function(timeout)
        now = now + math.max(0.001, math.min(timeout, 0.02))
        return wait(timeout)
    end
    F.eq(amp.get_next_timeout(), nil, 'no registered timer')
    local delayed_runs, periodic_runs, cancelled_runs = 0, 0, 0
    local delayed = amp.add_timeout(0.05, function() delayed_runs = delayed_runs + 1 end, true)
    F.eq(delayed:is_enabled(), false, 'disabled timer')
    delayed:resume()
    F.close(assert(amp.get_next_timeout()), 0.05, 'relative timeout')
    now = 0.01
    delayed:stop()
    F.eq(delayed:is_enabled(), false, 'stopped timer')
    now = 1
    delayed:resume()
    F.close(assert(amp.get_next_timeout()), 0.04, 'resume preserves remaining delay')
    local cancelled = amp.add_timeout(0, function() cancelled_runs = cancelled_runs + 1 end)
    amp.cancel_timer(cancelled)
    cancelled:resume()
    cancelled:kill()
    ---@type mp_timer
    local periodic
    periodic = amp.add_periodic_timer(0.01, function()
        periodic_runs = periodic_runs + 1
        if periodic_runs == 3 then periodic:kill() end
    end)
    pump()
    F.eq(delayed_runs, 1, 'last one-shot callback is not lost')
    F.eq(periodic_runs, 3, 'periodic callback repeats until killed')
    F.eq(cancelled_runs, 0, 'killed timer never runs')
    F.eq(delayed:is_enabled(), false, 'one-shot disables after running')
    F.eq(amp.get_next_timeout(), nil, 'no remaining timers')
end)

F.test('hooks automatically continue, defer, and reject double continuation', function()
    local amp, stub = boot({
        [8] = {event = 'hook', id = 1, hook_id = 101},
        [16] = {event = 'hook', id = 2, hook_id = 102}, [40] = 'shutdown',
    })
    local registrations = {}
    stub.raw_hook_add = function(...) registrations[#registrations + 1] = {...} end
    ---@type mp_hook_event?
    local deferred
    amp.add_hook('on_load', 50, function() end)
    amp.add_hook('on_unload', 60, function(event)
        deferred = event
        event:defer()
    end)
    amp.add_hook('on_preloaded', 70, function() end)
    F.eq(registrations[3][1], 3, 'hook registration ID')
    F.eq(registrations[3][3], 20, 'Lua hook priority offset')
    pump()
    deferred = assert(deferred)
    F.eq(assert(stub.calls.raw_hook_continue[1])[1], 101, 'automatic continuation')
    F.eq(#stub.calls.raw_hook_continue, 1, 'deferred hook not continued')
    deferred:cont()
    F.eq(assert(stub.calls.raw_hook_continue[2])[1], 102, 'explicit continuation')
    deferred:cont()
    F.contains(stub.messages[#stub.messages], 'already continued', 'double continuation logged')
end)

F.test('native async commands report success/error, abort and raw submission failure', function()
    local amp, stub = boot({
        [8] = {event = 'command-reply', id = 1, result = 'ok'},
        [16] = {event = 'command-reply', id = 2, error = 'failed'}, [40] = 'shutdown',
    })
    local submitted, values = {}, {}
    stub.raw_command_native_async = function(id, node)
        submitted[#submitted + 1] = {id, node}
        if id == 3 then return nil, 'submit-failed' end
        return true
    end
    local success = amp.command_native_async({'one'}, function(ok, result, err)
        values[1] = {ok, result, err}
    end)
    local failure = amp.command_native_async({'two'}, function(ok, result, err)
        values[2] = {ok, result, err}
    end)
    success, failure = assert(success), assert(failure)
    amp.abort_async_command(failure)
    F.eq(assert(stub.calls.raw_abort_async_command[1])[1], 2, 'abort uses raw ID')
    local rejected, rejection = amp.command_native_async({'three'}, function(ok, result, err)
        values[3] = {ok, result, err}
    end)
    F.eq(rejected, nil, 'submission rejected')
    F.eq(rejection, 'submit-failed', 'submission error returned')
    pump()
    F.eq(submitted[1][2][1], 'one', 'command node forwarded')
    F.eq(values[1][1], true, 'success callback')
    F.eq(values[1][2], 'ok', 'success result')
    F.eq(values[2][1], false, 'failure callback')
    F.eq(values[2][3], 'failed', 'reply error')
    F.eq(values[3][1], false, 'raw failure callback runs asynchronously')
    F.eq(values[3][3], 'submit-failed', 'raw error callback')
    F.eq(success.id, nil, 'success handle retired')
    F.eq(failure.id, nil, 'failure handle retired')
    amp.abort_async_command(success)
    F.eq(#stub.calls.raw_abort_async_command, 1, 'completed command not aborted')
end)

F.test('GC cannot discard event/timer/idle errors before finally reports them', function()
    for _, source in ipairs({'event', 'timer', 'idle'}) do
        local amp, stub, asyncio = boot({[8] = 'file-loaded'})
        local wait = stub.wait_event
        stub.wait_event = function(timeout)
            local event = wait(timeout)
            collectgarbage('collect')
            return event
        end
        local cleanup = false
        local fail = function() error(std.RuntimeError(source .. '-gc-boom')) end
        if source == 'event' then amp.register_event('file-loaded', fail)
        elseif source == 'timer' then amp.add_timeout(0, fail)
        else amp.register_idle(fail) end
        amp.add_finally(asyncio.async(function()
            asyncio.await(asyncio.sleep(0))
            cleanup = true
        end))
        local ok, err = pcall(_G.mp_event_loop)
        F.eq(ok, false, source .. ' error surfaced despite GC')
        F.contains(err, source .. '-gc-boom', source .. ' error preserved')
        F.eq(cleanup, true, source .. ' finally completed')
        F.ok(stub.wait_calls < 80, source .. ' failure exits promptly')
    end
end)
