-- asyncio.Timeout / wait_for: the timer handle plumbing and the conversion of
-- an own-cancellation into TimeoutError.

local F = require("framework")
local support = require("support")

local asyncio = require("elxlibs.asyncio")
local std = require("elxlibs.std")
local timeouts = require("elxlibs.asyncio.timeouts")

F.section("timeouts")

F.test("wait_for(task) returns the result when it finishes in time", function()
    local value
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.01))
            return "in-time"
        end)
        value = asyncio.await(asyncio.wait_for(t, 1))
    end, support.real_loop(asyncio))
    F.eq(value, "in-time", "result is forwarded")
end)

F.test("wait_for(task, timeout) raises TimeoutError", function()
    local ok, err
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.3))
            return "never"
        end)
        ok, err = asyncio.try_await(asyncio.wait_for(t, 0.05))
    end, support.real_loop(asyncio))
    F.eq(ok, false, "wait_for fails")
    F.is_error(err, "std.TimeoutError", "TimeoutError is raised")
    F.ok(std.isinstance(err, std.TimeoutError), "and it is an instance, not the class")
    F.is_error(err.__cause, "CancelledError", "the cancellation is kept as __cause")
end)

F.test("wait_for(future, timeout) works on plain futures", function()
    local ok, err
    asyncio.run(function()
        local loop = asyncio.loops.get_running_loop()
        local fut = loop:create_future()       -- never resolved
        ok, err = asyncio.try_await(asyncio.wait_for(fut, 0.05))
    end, support.real_loop(asyncio))
    F.eq(ok, false, "wait_for fails")
    F.is_error(err, "std.TimeoutError", "TimeoutError is raised")
end)

F.test("wait_for(fut, 0) reports a completed future / cancels a pending one", function()
    local done_ok, done_val, pending_ok, pending_err
    asyncio.run(function()
        local loop = asyncio.loops.get_running_loop()
        local fin = loop:create_future()
        fin:set_result("ready")
        done_ok, done_val = asyncio.try_await(asyncio.wait_for(fin, 0))

        local pending = loop:create_future()
        pending_ok, pending_err = asyncio.try_await(asyncio.wait_for(pending, 0))
    end, support.real_loop(asyncio))
    F.eq(done_ok, true, "finished future returns immediately")
    F.eq(done_val, "ready", "with its result")
    F.eq(pending_ok, false, "pending future is cancelled")
    F.is_error(pending_err, "std.TimeoutError", "TimeoutError is raised")
    F.is_error(pending_err.__cause, "CancelledError", "with the cancellation as __cause")
end)

F.test("Timeout:with() runs the target and forwards its result", function()
    local value
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.01))
            return "with-result"
        end)
        value = asyncio.await(timeouts.timeout(1):with(t))
    end, support.real_loop(asyncio))
    F.eq(value, "with-result", "result is forwarded")
end)

F.test("Timeout:with() converts its own cancellation into TimeoutError", function()
    local ok, err
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.3))
            return "never"
        end)
        ok, err = asyncio.try_await(timeouts.timeout(0.05):with(t))
    end, support.real_loop(asyncio))
    F.eq(ok, false, "times out")
    F.is_error(err, "std.TimeoutError", "TimeoutError is raised")
    F.is_error(err.__cause, "CancelledError", "with __cause set")
end)

F.test("Timeout state machine reports expiry", function()
    local expired, state
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.2))
        end)
        local to = timeouts.timeout(0.02)
        pcall(function() asyncio.await(to:with(t)) end)
        expired = to:expired()
        state = to._state
    end, support.real_loop(asyncio))
    F.eq(expired, true, "expired() is true after the deadline")
    F.eq(state, "expired", "final state is 'expired'")
end)
