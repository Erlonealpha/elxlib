-- A tiny, scriptable stand-in for mpv's `mp` module.
--
-- Only what elxlib's asyncio layer touches is implemented: a clock, an event
-- queue (driven by a call script) and a pile of no-op registrations. This
-- keeps the tests runnable with plain LuaJIT.

local M = {}

local NOOP_NAMES = {
    "request_event", "unregister_event",
    "register_idle", "unregister_idle",
    "register_script_message", "unregister_script_message",
    "observe_property", "unobserve_property",
    "raw_observe_property", "raw_unobserve_property",
    "raw_hook_continue", "raw_abort_async_command", "abort_async_command",
    "unregister_event", "remove_key_binding", "add_forced_key_binding",
    "set_key_bindings", "input_define_section", "input_enable_section",
    "flush_keybindings", "cancel_timer", "commandv", "command",
    "set_property", "_sync",
}

---@class test.amp_stub
---@field wait_calls integer
---@field events table<string, integer> delivered `mpv` events, by name
---@field messages string[]             everything written to mp.msg
---@field calls table<string, table[]>  raw host API calls and arguments
---@field asyncio_event_loop? boolean
---@field msg table<string, function>
---@field register_event function
---@field get_time fun():number
---@field wait_event fun(timeout:number):table
---@field raw_hook_add function
---@field raw_command_native_async fun(id:integer, node:table):boolean?,string?

---@class _asyncio_test.amp_stub_new_opts
---@field verbose? boolean                  print mp.msg output
---@field script? table<integer, string|table> wait_event call # -> name or event payload
---@field error_at? integer                 raise inside wait_event at call #
---@field error_msg? string
---@field limit? integer                    hard cap on wait_event calls (default 500)
---@field watchdog? number                  seconds of CPU time before failing (default 10)
---@field max_block? number

---@param opts? _asyncio_test.amp_stub_new_opts?
---@return test.amp_stub
function M.new(opts)
    opts = opts or {}
    local limit = opts.limit or 500
    local watchdog = opts.watchdog or 10
    local script = opts.script or {}
    local t0 = os.clock()

    local stub = {
        wait_calls = 0,
        events = {},
        messages = {},
        calls = {},
        script_name = "test-script",
    }

    local function log(level, ...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        local line = table.concat(parts, " ")
        stub.messages[#stub.messages + 1] = level .. ": " .. line
        if opts.verbose then
            print("    [mp." .. level .. "] " .. line)
        end
    end

    stub.get_time = function()
        local elapsed = os.clock() - t0
        if elapsed > watchdog then
            error(string.format(
                "TEST-WATCHDOG: still running after %.1fs (%d wait_event calls)",
                elapsed, stub.wait_calls))
        end
        return elapsed
    end

    --- Deliver a scripted event. `opts.script` maps a wait_event call number
    --- to an event name, e.g. { [20] = "shutdown" }.
    --- Like mpv, the call blocks for (at most) the requested timeout, so the
    --- clock the event loop timers are compared against actually moves on.
    --- The block is capped to keep the suite fast.
    stub.wait_event = function(timeout)
        stub.wait_calls = stub.wait_calls + 1
        if stub.wait_calls > limit then
            error(string.format(
                "TEST-LIMIT: event loop did not exit within %d wait_event calls", limit))
        end
        if opts.error_at and stub.wait_calls == opts.error_at then
            error(opts.error_msg or "stubbed mp.wait_event failure")
        end
        local payload = script[stub.wait_calls]
        if payload then
            local event = type(payload) == 'string' and {event = payload} or payload
            local name = event.event
            stub.events[name] = (stub.events[name] or 0) + 1
            return event
        end
        local block = math.min(tonumber(timeout) or 0, opts.max_block or 0.02)
        if block > 0 then
            local deadline = os.clock() + block
            while os.clock() < deadline do end
        end
        return { event = "none" }
    end

    stub.msg = {
        info = function(...) log("info", ...) end,
        warn = function(...) log("warn", ...) end,
        error = function(...) log("error", ...) end,
        verbose = function(...) log("verbose", ...) end,
        fatal = function(...) log("fatal", ...) end,
        debug = function(...) log("debug", ...) end,
    }

    stub.get_script_name = function() return stub.script_name end
    stub.get_time = stub.get_time
    stub.get_next_timeout = function() return nil end
    stub.is_idle = function() return false end
    stub.command_native = function() return {} end
    stub.command_native_async = function() return 1 end
    stub.raw_command_native_async = function() return 1 end
    stub.raw_hook_add = function() return 1 end
    stub.add_timeout = function() return { kill = function() end }, 1 end
    stub.add_periodic_timer = function() return { kill = function() end }, 1 end
    stub.add_key_binding = function() return {} end
    stub.sync = function(cb) if cb then cb() end end
    stub.get_property = function() return nil end

    for _, name in ipairs(NOOP_NAMES) do
        stub[name] = function(...)
            local calls = stub.calls[name] or {}
            stub.calls[name] = calls
            calls[#calls + 1] = table.pack(...)
        end
    end

    ---@cast stub test.amp_stub
    return stub
end

return M
