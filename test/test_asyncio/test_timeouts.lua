-- asyncio.Timeout / wait_for: the timer handle plumbing and the conversion of
-- an own-cancellation into TimeoutError.

local F = require("mpv_luatest.framework")
local support = require("test_asyncio.support")

local asyncio = require("elxlibs.asyncio")
local std = require("elxlibs.std")
local timeouts = require("elxlibs.asyncio.timeouts")

F.section("timeouts")

F.test("wait_for(task) returns the result when it finishes in time", function()
    local value
    support.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.01))
            return "in-time"
        end)
        value = asyncio.await(asyncio.wait_for(t, 1))
    end)
    F.eq(value, "in-time", "result is forwarded")
end)

F.test("wait_for(task, timeout) raises TimeoutError", function()
    local ok, err
    support.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.3))
            return "never"
        end)
        ok, err = asyncio.try_await(asyncio.wait_for(t, 0.05))
    end)
    F.eq(ok, false, "wait_for fails")
    F.contains(err, "TimeoutError", "TimeoutError is raised")
    F.ok(std.isinstance(err, std.TimeoutError), "and it is an instance, not the class")
    if std.isinstance(err, std.TimeoutError) then
        F.contains(err.__cause, "CancelledError", "the cancellation is kept as __cause")
    end
end)

F.test("wait_for(future, timeout) works on plain futures", function()
    local ok, err
    support.run(function()
        local loop = asyncio.loops.get_running_loop()
        local fut = loop:create_future()       -- never resolved
        ok, err = asyncio.try_await(asyncio.wait_for(fut, 0.05))
    end)
    F.eq(ok, false, "wait_for fails")
    F.contains(err, "TimeoutError", "TimeoutError is raised")
end)

F.test("wait_for(fut, 0) reports a completed future / cancels a pending one", function()
    local done_ok, done_val, pending_ok, pending_err
    support.run(function()
        local loop = asyncio.loops.get_running_loop()
        local fin = loop:create_future()
        fin:set_result("ready")
        done_ok, done_val = asyncio.try_await(asyncio.wait_for(fin, 0))

        local pending = loop:create_future()
        pending_ok, pending_err = asyncio.try_await(asyncio.wait_for(pending, 0))
    end)
    F.eq(done_ok, true, "finished future returns immediately")
    F.eq(done_val, "ready", "with its result")
    F.eq(pending_ok, false, "pending future is cancelled")
    F.contains(pending_err, "TimeoutError", "TimeoutError is raised")
    if std.isinstance(pending_err, std.TimeoutError) then
        F.contains(pending_err.__cause, "CancelledError", "with the cancellation as __cause")
    else
        F.fail("pending future must produce a TimeoutError instance")
    end
end)

F.test("Timeout:with() runs the target and forwards its result", function()
    local value
    support.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.01))
            return "with-result"
        end)
        value = asyncio.await(timeouts.timeout(1):with(t))
    end)
    F.eq(value, "with-result", "result is forwarded")
end)

F.test("Timeout:with() converts its own cancellation into TimeoutError", function()
    local ok, err
    support.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.3))
            return "never"
        end)
        ok, err = asyncio.try_await(timeouts.timeout(0.05):with(t))
    end)
    F.eq(ok, false, "times out")
    F.contains(err, "TimeoutError", "TimeoutError is raised")
    if std.isinstance(err, std.TimeoutError) then
        F.contains(err.__cause, "CancelledError", "with __cause set")
    else
        F.fail("Timeout:with must produce a TimeoutError instance")
    end
end)

F.test("Timeout state machine reports expiry", function()
    local expired, state
    support.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.2))
        end)
        local to = timeouts.timeout(0.02)
        pcall(function() asyncio.await(to:with(t)) end)
        expired = to:expired()
        state = to._state
    end)
    F.eq(expired, true, "expired() is true after the deadline")
    F.eq(state, "expired", "final state is 'expired'")
end)

F.test('Timeout exposes deadlines and rejects rescheduling outside its active state', function()
    support.run(function()
        local loop = asyncio.loops.get_running_loop()
        local deadline = loop:time() + 1
        local to = timeouts.timeout_at(deadline)
        F.eq(to:when(), deadline, 'absolute deadline kept')
        F.eq(to:expired(), false, 'new timeout not expired')
        F.raises(function() to:reschedule(nil) end, 'not been entered', 'created timeout cannot reschedule')
        local result = asyncio.await(to:with(function()
            F.contains(tostring(to), 'active', 'active representation')
            F.eq(to:when(), deadline, 'active deadline')
            to:reschedule(nil)
            F.eq(to:when(), nil, 'deadline disabled')
            return 'value', nil
        end))
        F.eq(result, 'value', 'disabled timeout returns result')
        F.eq(to:expired(), false, 'finished timeout not expired')
        F.contains(tostring(to), 'finished', 'finished representation')
        F.raises(function() to:reschedule(deadline) end, 'Cannot change state', 'finished cannot reschedule')
        local ran = false
        local ok, err = asyncio.try_await(to:with(function() ran = true end))
        asyncio.await(asyncio.sleep(0))
        F.eq(ok, false, 'timeout cannot be entered twice')
        F.ok(std.isinstance(err, std.RuntimeError), 'reuse error identity')
        F.eq(ran, false, 'reuse failure does not run new body')
    end)
end)

F.test('Timeout can disable and move its deadline while the target runs', function()
    support.run(function()
        local to = timeouts.timeout(0.001)
        local result = asyncio.await(to:with(function()
            to:reschedule(nil)
            asyncio.await(asyncio.sleep(0.003))
            to:reschedule(asyncio.loops.get_running_loop():time() + 0.02)
            return 'rescheduled'
        end))
        F.eq(result, 'rescheduled', 'cancelled old deadline does not fire')
        local immediate = timeouts.timeout(nil)
        local ok, err = asyncio.try_await(immediate:with(function()
            immediate:reschedule(asyncio.loops.get_running_loop():time() - 1)
            asyncio.await(asyncio.sleep(1))
        end))
        F.eq(ok, false, 'past reschedule expires')
        F.ok(std.isinstance(err, std.TimeoutError), 'past reschedule produces TimeoutError')
        F.eq(immediate:expired(), true, 'expired state exposed')
        F.raises(function() immediate:reschedule(nil) end, 'Cannot change state', 'expired cannot reschedule')
    end)
end)

F.test('immediate Timeout cancels function/thread/Coroutine at suspension', function()
    support.run(function()
        for _, kind in ipairs({'function', 'thread', 'coroutine'}) do
            local ran = false
            local body = function()
                asyncio.await(asyncio.sleep(1))
                ran = true
            end
            local input = body
            if kind == 'thread' then input = coroutine.create(body)
            elseif kind == 'coroutine' then input = asyncio.async(body) end
            local ok, err = asyncio.try_await(timeouts.timeout(0):with(input))
            F.eq(ok, false, kind .. ' deadline already passed')
            F.ok(std.isinstance(err, std.TimeoutError), kind .. ' typed timeout')
            F.eq(ran, false, kind .. ' has no side effects')
        end
    end)
end)

F.test('unbounded wait_for forwards errors and external cancellation stays CancelledError', function()
    support.run(function()
        local boom = std.RuntimeError('unbounded-boom')
        local failed = asyncio.create_task(function() error(boom) end)
        local ok, err = asyncio.try_await(asyncio.wait_for(failed, nil))
        F.eq(ok, false, 'unbounded child failure')
        F.eq(err, boom, 'unbounded failure identity')
        local target = asyncio.create_task(function() asyncio.await(asyncio.sleep(1)) end)
        local to = timeouts.timeout(1)
        local wrapper = asyncio.create_task(to:with(target))
        asyncio.await(asyncio.sleep(0))
        wrapper:cancel('external-cancel')
        local cancelled, cancel_err = asyncio.try_await(wrapper)
        local exceptions = require 'elxlibs.asyncio.exceptions'
        F.eq(cancelled, false, 'external cancellation forwarded')
        F.ok(std.isinstance(cancel_err, exceptions.CancelledError), 'external cancel is not a timeout')
        F.eq(target:cancelled(), true, 'external cancel reaches target')
        F.eq(to:expired(), false, 'external cancel does not expire timeout')
        local pending = asyncio.loops.get_running_loop():create_future()
        local negative_ok, negative_err = asyncio.try_await(asyncio.wait_for(pending, -1))
        F.eq(negative_ok, false, 'negative wait_for cancels pending future')
        F.ok(std.isinstance(negative_err, std.TimeoutError), 'negative typed timeout')
        F.eq(pending:cancelled(), true, 'negative deadline cancels target')
    end)
end)

F.test('nested timeouts retain the inner exception and return arity', function()
    support.run(function()
        local ok, err = asyncio.try_await(timeouts.timeout(1):with(function()
            return asyncio.await(timeouts.timeout(0.001):with(function()
                asyncio.await(asyncio.sleep(1))
            end))
        end))
        F.eq(ok, false, 'inner timeout propagated')
        F.ok(std.isinstance(err, std.TimeoutError), 'inner TimeoutError identity')
        local result = table.pack(asyncio.await(timeouts.timeout(nil):with(function()
            return 'first', nil, false, nil
        end)))
        F.eq(result.n, 4, 'Timeout preserves all return values')
    end)
end)
