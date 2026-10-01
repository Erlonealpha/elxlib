-- std exception plumbing: raise()/traceback() levels, exception chaining and
-- the xpcall/try wrappers that asyncio error handling is built on.

local F = require("framework")
require("support")

local std = require("elxlibs.std")

F.section("std: raise()")

F.test("string errors keep their file:line position", function()
    local err
    local line
    local ok, e = pcall(function()
        line = debug.getinfo(1, "l").currentline + 1
        std.raise("plain-string-error")
    end)
    F.eq(ok, false, "raise() throws")
    err = tostring(e)
    F.contains(err, "plain-string-error", "message is preserved")
    F.contains(err, ":" .. line .. ":", "position points at the raise() call site")
end)

F.test("level 0 adds no position information", function()
    local ok, e = pcall(function() std.raise("no-position", 0) end)
    F.eq(ok, false, "raise() throws")
    F.ok(not tostring(e):find(":%d+:"), "no file:line prefix")
end)

F.test("exception objects capture a traceback (when raising)", function()
    local err, line
    local ok, e = pcall(function()
        line = debug.getinfo(1, "l").currentline + 1
        std.raise(std.ValueError("exc-error"))
    end)
    F.eq(ok, false, "raise() throws")
    err = e
    F.eq(type(err), "table", "the exception object itself is thrown")
    F.is_error(err, "std.ValueError", "exception type survives")
    F.contains(tostring(err), ":" .. line .. ":", "traceback starts at the raise() site")
end)

F.test("raise(err, level, from) chains __cause", function()
    local ok, e = pcall(function()
        std.raise(std.ValueError("outer"), nil, std.RuntimeError("inner"))
    end)
    F.eq(ok, false, "raise() throws")
    F.is_error(e, "std.ValueError", "outer exception")
    F.is_error(e.__cause, "std.RuntimeError", "__cause holds the inner exception")
    F.contains(tostring(e), "The above exception was the direct cause",
        "tostring() renders the chain")
end)

F.section("std: traceback / xpcall / try")

F.test("traceback(message) keeps the message", function()
    local tb = std.traceback("tb-message")
    F.contains(tb, "tb-message", "message present")
    F.contains(tb, "stack traceback:", "traceback present")
end)

F.test("traceback(thread, err, level) walks the given coroutine's stack", function()
    local co = coroutine.create(function()
        error("inside-coroutine")
    end)
    coroutine.resume(co)          -- dies with an error
    local tb = std.traceback(co, "thread-error", 0)
    F.contains(tb, "thread-error", "message present")
    F.contains(tb, "test_exceptions.lua:6", "coroutine frames are reported")
    F.ok(not tb:find("in function 'traceback'", 1, true),
        "does not report the traceback helper's own frames")
end)

F.test("xpcall preserves multiple return values", function()
    local r = table.pack(std.xpcall(function() return 1, 2, 3 end))
    F.eq(r.n, 4, "ok + 3 values")
    F.eq(r[1], true, "call succeeded")
    F.eq(r[2] .. r[3] .. r[4], "123", "values in order")
end)

F.test("try/catch/finally keeps results and routes errors", function()
    local caught
    local a, b = std.try{ function() return "x", "y" end }
    F.eq(a .. b, "xy", "values pass through")

    std.try{
        function() error(std.ValueError("try-catch")) end,
        std.catch{ function(e) caught = e end },
    }
    F.is_error(caught, "ValueError", "catch receives the error")
end)

F.test("try/finally runs the finally block", function()
    local order = {}
    local a, b = std.try{
        function() return "x", "y" end,
        std.finally{ function(ok) order[#order + 1] = "finally:" .. tostring(ok) end },
    }
    F.eq(a .. b, "xy", "values pass through")
    F.eq(table.concat(order, ","), "finally:true", "finally ran with ok=true")
end)
