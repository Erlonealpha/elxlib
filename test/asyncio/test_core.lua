-- Core coroutine/task/gather behaviour, plus the modules built on top of the
-- (ok, value|error) try_await protocol: Queue, Lock, shield.

local F = require("mpv_luatest.framework")
local support = require("support")

local asyncio = require("elxlibs.asyncio")
local std = require("elxlibs.std")
local queues = require("elxlibs.asyncio.queues")
local locks = require("elxlibs.asyncio.locks")

F.section("core: task / await / gather")

F.test("await() keeps every return value of the task", function()
    ---@type { n: integer, [1]: string, [2]: string, [3]: string }?
    local got
    support.run(function()
        local t = asyncio.create_task(function() return "a", "b", "c" end)
        got = table.pack(asyncio.await(t))
    end)
    got = assert(got, "task must return packed values")
    F.eq(got.n, 3, "number of returned values")
    F.eq(got[1] .. got[2] .. got[3], "abc", "returned values in order")
end)

F.test("try_await() reports (true, value...) / (false, err)", function()
    local ok, err
    support.run(function()
        ok = asyncio.try_await(asyncio.sleep(0))
        local t = asyncio.create_task(function() error(std.RuntimeError("boom")) end)
        local _, _err = asyncio.try_await(t)
        err = _err
    end)
    F.eq(ok, true, "sleep(0) succeeds")
    F.contains(err, "RuntimeError", "failed task yields the exception")
end)

F.test("await(nil) yields the empty value", function()
    local n
    support.run(function()
        n = select("#", asyncio.await())
    end)
    F.eq(n, 0, "no values returned")
end)

F.test("gather() resolves with every child result", function()
    ---@type integer[]?
    local results
    support.run(function()
        results = asyncio.await(asyncio.gather({
            asyncio.create_task(function()
                asyncio.await(asyncio.sleep(0.01))
                return 1
            end),
            asyncio.create_task(function() return 2 end),
        }))
    end)
    results = assert(results, "gather must return child results")
    F.eq(results[1], 1, "first child")
    F.eq(results[2], 2, "second child")
end)

F.test("gather() completes when a child is already done (regression)", function()
    local done_before_await
    ---@type { result: string }?
    local first
    support.run(function()
        local loop = asyncio.loops.get_running_loop()
        local f = loop:create_future()
        f:set_result("already-done")
        local g = asyncio.gather({f}, true)
        done_before_await = g:done()
        first = (asyncio.await(g))[1]
    end)
    F.eq(done_before_await, true, "gathering future is finished immediately")
    first = assert(first, "gather must include the completed child")
    F.eq(first.result, "already-done", "child result is collected")
end)

F.section("core: queue")

F.test("Queue: put/get, maxsize back-pressure and join()", function()
    ---@type string[]?
    local items
    local emptied, unfinished
    support.run(function()
        local q = queues.Queue(2)
        items = {}
        local consumer = asyncio.create_task(function()
            for _ = 1, 3 do
                table.insert(items, asyncio.await(q:get()))
                q:task_done()
            end
        end)
        local producer = asyncio.create_task(function()
            for i = 1, 3 do
                asyncio.await(q:put("item" .. i))
            end
        end)
        asyncio.await(asyncio.gather({consumer, producer}))
        asyncio.await(q:join())
        emptied = q:empty()
        unfinished = q._unfinished_tasks
    end)
    F.eq(table.concat(assert(items), ","), "item1,item2,item3", "items arrive in order")
    F.eq(emptied, true, "queue is empty at the end")
    F.eq(unfinished, 0, "all tasks marked done")
end)

F.section("core: locks and shield")

F.test("Lock serializes its holders", function()
    ---@type string[]?
    local order
    support.run(function()
        local lock = locks.Lock()
        order = {}
        local function worker(name)
            return asyncio.create_task(function()
                asyncio.await(lock:acquire())
                table.insert(order, name .. "-in")
                asyncio.await(asyncio.sleep(0.01))
                table.insert(order, name .. "-out")
                lock:release()
            end)
        end
        asyncio.await(asyncio.gather({worker("A"), worker("B")}))
    end)
    F.eq(table.concat(assert(order), " "), "A-in A-out B-in B-out", "no interleaving")
end)

F.test("shield() protects the inner future from outer cancellation", function()
    local outer_cancelled, inner_result
    support.run(function()
        local t = asyncio.create_task(function()
            asyncio.await(asyncio.sleep(0.02))
            return "shielded"
        end)
        local s = asyncio.shield(t)
        s:cancel()
        outer_cancelled = s:cancelled()
        inner_result = asyncio.await(t)
    end)
    F.eq(outer_cancelled, true, "outer future is cancelled")
    F.eq(inner_result, "shielded", "inner future still completes")
end)
