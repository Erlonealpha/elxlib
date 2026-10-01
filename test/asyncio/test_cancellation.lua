-- Cancellation semantics: the bookkeeping (cancelling/uncancel) used by
-- asyncio.Timeout, plus the two paths a cancel request can take.

local F = require("framework")
local support = require("support")

local asyncio = require("elxlibs.asyncio")
local std = require("elxlibs.std")
local exceptions = require("elxlibs.asyncio.exceptions")

F.section("cancellation")

F.test("cancelling()/uncancel() count pending cancel requests", function()
    local before, after, uncancelled, now
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.05))
        end)
        before = t:cancelling()
        t:cancel()
        after = t:cancelling()
        uncancelled = t:uncancel()
        now = t:cancelling()
        asyncio.await(asyncio.sleep(0.1))    -- let it finish; uncancel() undid it
    end, support.real_loop(asyncio))
    F.eq(before, 0, "starts at zero")
    F.eq(after, 1, "cancel() increments")
    F.eq(uncancelled, 0, "uncancel() returns the remaining count")
    F.eq(now, 0, "no pending requests left")
end)

F.test("cancel() before the task ever ran is not dropped", function()
    local ok, err
    asyncio.run(function()
        local t = asyncio.create_task(function()
            return "ran-to-completion"     -- no suspension at all
        end)
        t:cancel("early")
        ok, err = asyncio.try_await(t)
    end, support.real_loop(asyncio))
    F.eq(ok, false, "task is cancelled")
    F.is_error(err, "asyncio.CancelledError", "CancelledError is reported")
    F.contains(tostring(err), "early", "cancel message is kept")
end)

F.test("cancel() while awaiting a future cancels the await point", function()
    local ok, err
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.2))
            return "late"
        end)
        asyncio.await(asyncio.sleep(0.02))   -- let it reach its await point
        t:cancel("mid")
        ok, err = asyncio.try_await(t)
    end, support.real_loop(asyncio))
    F.eq(ok, false, "task is cancelled")
    F.is_error(err, "asyncio.CancelledError", "CancelledError is reported")
    F.contains(tostring(err), "mid", "cancel message is kept")
end)

F.test("try_await() reports cancellation instead of raising", function()
    local ok, err
    asyncio.run(function()
        local loop = asyncio.loops.get_running_loop()
        local fut = loop:create_future()
        fut:cancel("fut-cancel")
        ok, err = asyncio.try_await(fut)
    end, support.real_loop(asyncio))
    F.eq(ok, false, "returns false")
    F.is_error(err, "asyncio.CancelledError", "returns the CancelledError")
end)

F.test("cancelled tasks surface CancelledError through await()", function()
    local raised
    asyncio.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.2))
        end)
        t:cancel()
        local _ok, err = asyncio.try_await(t)
        raised = err
    end, support.real_loop(asyncio))
    F.is_error(raised, "asyncio.CancelledError", "cancellation is visible")
    F.ok(std.isinstance(raised, exceptions.CancelledError),
        "and is a real CancelledError instance")
end)
