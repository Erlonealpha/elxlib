-- The mp-backed amp event loop: shutdown handling and the finally callbacks.
--
-- Every case boots a *fresh* asyncio module tree (support.reload_asyncio) on
-- top of an mp stub with a scripted event sequence, because the loop, the
-- registered finally callbacks and the "stopping" flag are module locals of
-- elxlibs/asyncio/mp.lua.
--
-- The regression this suite was written for: awaiting the finally callbacks
-- inline in the loop body suspended the only code path that pumps
-- mp.wait_event(), so a callback waiting for an mpv event (case 5) never
-- completed and mpv could not shut down.

local F = require("framework")
local support = require("support")
local mp_stub = require("mp_stub")

local std = require("elxlibs.std")

F.section("amp loop: shutdown / finally")

--- Cases ---------------------------------------------------------------------

local cases = {}

local function case(t)
    cases[#cases + 1] = t
end

local function finally_coro(asyncio, body)
    return asyncio.async(function() body() end)
end

case {
    name = "shutdown without finally callbacks exits",
    opts = { script = { [20] = "shutdown" } },
    setup = function() end,
    check = function(rec)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.ok(rec.wait_calls < 40, "loop exited promptly (" .. rec.wait_calls .. " wait_event calls)")
    end,
}

case {
    name = "sync finally callback runs",
    opts = { script = { [20] = "shutdown" } },
    setup = function(_, amp, _, rec)
        amp.add_finally(function() rec.runs[#rec.runs + 1] = "sync" end)
    end,
    check = function(rec)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.eq(table.concat(rec.runs, ","), "sync", "callback ran exactly once")
    end,
}

case {
    name = "async (coroutine) finally callback runs",
    opts = { script = { [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.add_finally(finally_coro(asyncio, function()
            rec.runs[#rec.runs + 1] = "async"
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.eq(table.concat(rec.runs, ","), "async", "coroutine body ran")
    end,
}

case {
    name = "finally callback may await a timer",
    opts = { script = { [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.add_finally(finally_coro(asyncio, function()
            asyncio.await(asyncio.sleep(0.05))
            rec.runs[#rec.runs + 1] = "slept"
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.eq(table.concat(rec.runs, ","), "slept", "callback completed its await")
    end,
}

case {
    -- the regression: the event must still be pumped while the finally runs
    name = "finally callback waiting for an mpv event is delivered",
    opts = { script = { [20] = "shutdown", [25] = "file-loaded" } },
    setup = function(asyncio, amp, _, rec)
        amp.register_event("file-loaded", function()
            if rec.gate and not rec.gate:done() then
                rec.gate:set_result("event-data")
            end
        end)
        amp.add_finally(finally_coro(asyncio, function()
            rec.gate = asyncio.loops.get_running_loop():create_future()
            asyncio.await(rec.gate)
            rec.runs[#rec.runs + 1] = rec.gate:result()
        end))
    end,
    check = function(rec, stub)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.eq(stub.events["file-loaded"], 1, "the event was actually pumped")
        F.eq(table.concat(rec.runs, ","), "event-data", "callback received it")
    end,
}

case {
    name = "error inside a finally callback is reported",
    opts = { script = { [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.add_finally(finally_coro(asyncio, function()
            error(std.RuntimeError("finally-boom"))
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, false, "loop reported a failure")
        F.is_error(rec.err, "finally-boom", "the callback error is surfaced")
    end,
}

case {
    name = "every registered finally callback runs",
    opts = { script = { [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.add_finally(finally_coro(asyncio, function()
            rec.runs[#rec.runs + 1] = "one"
        end))
        amp.add_finally(finally_coro(asyncio, function()
            asyncio.await(asyncio.sleep(0.03))
            rec.runs[#rec.runs + 1] = "two"
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.eq(table.concat(rec.runs, ","), "one,two", "both callbacks ran")
    end,
}

case {
    name = "a pending long timer does not block shutdown",
    opts = { script = { [8] = "file-loaded", [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.register_event("file-loaded", function()
            -- a task that will still be sleeping when shutdown arrives
            asyncio.create_task(function()
                asyncio.await(asyncio.sleep(3))
            end)
            rec.order[#rec.order + 1] = "long-task-started"
        end)
    end,
    check = function(rec)
        F.eq(rec.ok, true, "loop returned normally" .. (rec.ok and "" or (" -> " .. rec.err_msg:gsub("\n", " | "))))
        F.eq(table.concat(rec.order, ","), "long-task-started", "the task was started")
        F.ok(rec.elapsed < 1, string.format("shutdown was not delayed by the 3s timer (%.2fs)", rec.elapsed))
    end,
}

case {
    name = "handler error while running is reported after the finally ran",
    opts = { script = { [8] = "file-loaded", [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.register_event("file-loaded", function()
            error(std.RuntimeError("handler-boom"))
        end)
        amp.add_finally(finally_coro(asyncio, function()
            rec.runs[#rec.runs + 1] = "cleanup"
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, false, "loop reported the handler failure")
        F.is_error(rec.err, "handler-boom", "the handler error is surfaced")
        F.eq(table.concat(rec.runs, ","), "cleanup", "cleanup still ran")
    end,
}

case {
    name = "error in the shutdown handler is reported",
    opts = { script = { [20] = "shutdown" } },
    setup = function(asyncio, amp, _, rec)
        amp.register_event("shutdown", function()
            error(std.RuntimeError("shutdown-handler-boom"))
        end)
        amp.add_finally(finally_coro(asyncio, function()
            rec.runs[#rec.runs + 1] = "cleanup"
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, false, "loop reported the failure")
        F.is_error(rec.err, "shutdown-handler-boom", "the handler error is surfaced")
        F.eq(table.concat(rec.runs, ","), "cleanup", "cleanup still ran")
    end,
}

case {
    name = "loop body error still runs the finally callbacks",
    opts = { script = {}, error_at = 6, error_msg = "test-boom" },
    setup = function(asyncio, amp, _, rec)
        amp.add_finally(finally_coro(asyncio, function()
            asyncio.await(asyncio.sleep(0.02))
            rec.runs[#rec.runs + 1] = "cleanup"
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, false, "loop reported the failure")
        F.is_error(rec.err, "test-boom", "the loop error is surfaced")
        F.eq(table.concat(rec.runs, ","), "cleanup", "cleanup still ran")
    end,
}

case {
    name = "handler error without finally callbacks fails immediately",
    opts = { script = { [8] = "file-loaded" } },
    setup = function(_, amp)
        amp.register_event("file-loaded", function()
            error(std.RuntimeError("handler-boom"))
        end)
    end,
    check = function(rec)
        F.eq(rec.ok, false, "loop reported the failure")
        F.is_error(rec.err, "handler-boom", "the handler error is surfaced")
    end,
}

case {
    -- self-test of the harness: a real deadlock must fail the suite instead of
    -- hanging it forever (the stub's call limit / watchdog turn it into an
    -- error)
    name = "a finally callback that can never finish is reported by the stub",
    opts = { script = { [20] = "shutdown" }, limit = 40 },
    setup = function(asyncio, amp, _, rec)
        amp.add_finally(finally_coro(asyncio, function()
            -- nothing ever resolves this future
            asyncio.await(asyncio.loops.get_running_loop():create_future())
        end))
    end,
    check = function(rec)
        F.eq(rec.ok, false, "the deadlock surfaced as an error")
        F.is_error(rec.err, "TEST-LIMIT", "it was caught by the stub, not hung")
    end,
}

--- Driver --------------------------------------------------------------------

for _, c in ipairs(cases) do
    F.test(c.name, function()
        local stub = mp_stub.new(c.opts)
        local asyncio = support.reload_asyncio(stub)
        local amp = require("elxlibs.asyncio.amp")
        local rec = { runs = {}, order = {} }

        c.setup(asyncio, amp, stub, rec)

        local t0 = os.clock()
        local ok, err = pcall(function() _G.mp_event_loop() end)
        rec.ok, rec.err, rec.elapsed = ok, err, os.clock() - t0
        rec.wait_calls = stub.wait_calls
        rec.err_msg = tostring(err or "")

        c.check(rec, stub)
    end)
end

