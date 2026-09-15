--- Override defaults.lua defines to handle events in asyncio eventloop.

local mp = require("mp")
local std = require('elxlibs.std')
local asyncio = require('elxlibs.asyncio')
local class = require('elxlibs.std.class')

local type = type
local table = table
local error = error
local pairs = pairs
local xpcall = xpcall
local string = string
local unpack = unpack
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local setmetatable = setmetatable
local debug_traceback = debug.traceback

local await = asyncio.await

---@class asyncio.amp
local amp = {}


-- For dispatching script-binding. This is sent as:
--      script-message-to $script_name $binding_name $keystate
-- The array is indexed by $binding_name, and has functions like this as value:
--      fn($binding_name, $keystate)
local dispatch_key_bindings = {}

local message_id = 0
local function reserve_binding()
    message_id = message_id + 1
    return "__keybinding" .. tostring(message_id)
end

local function dispatch_key_binding(name, state, key_name, key_text, scale, arg)
    local fn = dispatch_key_bindings[name]
    if fn then
        fn(name, state, key_name, key_text, scale, arg)
    end
end

-- "Old", deprecated API

-- each script has its own section, so that they don't conflict
local default_section = "input_dispatch_" .. mp.script_name

-- Set the list of key bindings. These will override the user's bindings, so
-- you should use this sparingly.
-- A call to this function will remove all bindings previously set with this
-- function. For example, set_key_bindings({}) would remove all script defined
-- key bindings.
-- Note: the bindings are not active by default. Use enable_key_bindings().
--
-- list is an array of key bindings, where each entry is an array as follow:
--      {key, callback_press, callback_down, callback_up}
-- key is the key string as used in input.conf, like "ctrl+a"
--
-- callback can be a string too, in which case the following will be added like
-- an input.conf line: key .. " " .. callback
-- (And callback_down is ignored.)
---@param list [string, fun()?, fun()?, fun()?][] <key, cb, cb_down, cb_up>[]
---@param section string?
---@param flags define_section_flags?
function amp.set_key_bindings(list, section, flags)
    local cfg = ""
    for i = 1, #list do
        local entry = list[i]
        local key = entry[1]
        local cb = entry[2]
        local cb_down = entry[3]
        local cb_up = entry[4]
        if type(cb) ~= "string" then
            local mangle = reserve_binding()
            dispatch_key_bindings[mangle] = function(_, state)
                local event = state:sub(1, 1)
                local is_mouse = state:sub(2, 2) == "m"
                local def = (is_mouse and "u") or "d"
                if event == "r" then
                    return
                end
                if event == "p" and cb then
                    cb()
                elseif event == "d" and cb_down then
                    cb_down()
                elseif event == "u" and cb_up then
                    cb_up()
                elseif event == def and cb then
                    cb()
                end
            end
            cfg = cfg .. key .. " script-binding " ..
                  mp.script_name .. "/" .. mangle .. "\n"
        else
            cfg = cfg .. key .. " " .. cb .. "\n"
        end
    end
    mp.input_define_section(section or default_section, cfg, flags)
end


-- "Newer" and more convenient API

local key_bindings = {}
local key_binding_counter = 0
local key_bindings_dirty = false

function amp.flush_keybindings()
    if not key_bindings_dirty then
        return
    end
    key_bindings_dirty = false

    for i = 1, 2 do
        local section, flags
        local def = i == 1
        if def then
            section = "input_" .. mp.script_name
            flags = "default"
        else
            section = "input_forced_" .. mp.script_name
            flags = "force"
        end
        local bindings = {}
        for _, v in pairs(key_bindings) do
            if v.bind and v.forced ~= def then
                bindings[#bindings + 1] = v
            end
        end
        table.sort(bindings, function(a, b)
            return a.priority < b.priority
        end)
        local cfg = ""
        for _, v in ipairs(bindings) do
            cfg = cfg .. v.bind .. "\n"
        end
        mp.input_define_section(section, cfg, flags)
        mp.input_enable_section(section, "allow-hide-cursor+allow-vo-dragging")
    end
end

---@param attrs key_binding_attrs
---@param key string?
---@param name string?
---@param fn binding_callback?
---@param rp (string|table)?
---@overload fun(
---     attrs: key_binding_attrs,
---     key: string?,
---     fn: binding_callback?,
---     rp: (string|table)?
--- ):void
local function add_binding(attrs, key, name, fn, rp)
    if type(name) ~= "string" and name ~= nil then
        ---@diagnostic disable-next-line: assign-type-mismatch
        rp = fn
        ---@diagnostic disable-next-line: assign-type-mismatch
        fn = name
        name = nil
    end

    ---@cast name string?
    ---@cast fn binding_callback?
    ---@diagnostic disable-next-line: cast-type-mismatch
    ---@cast rp (string|table)?

    rp = rp or ""
    if name == nil then
        name = reserve_binding()
    end
    local repeatable = rp == "repeatable" or rp["repeatable"]
    local scalable = rp == "scalable" or rp["scalable"]
    if rp["forced"] then
        attrs.forced = true
    end
    local key_cb, msg_cb
    if not fn then
        fn = function() end
    end
    if rp["complex"] then
        local key_states = {
            ["u"] = "up",
            ["d"] = "down",
            ["r"] = "repeat",
            ["p"] = "press",
        }
        key_cb = function(_, state, key_name, key_text, scale, arg)
            if key_text == "" then
                key_text = nil
            end
            fn({
                event = key_states[state:sub(1, 1)] or "unknown",
                is_mouse = state:sub(2, 2) == "m",
                canceled = state:sub(3, 3) == "c",
                key_name = key_name,
                key_text = key_text,
                scale = tonumber(scale),
                arg = arg,
            })
        end
        msg_cb = function()
            fn({event = "press", is_mouse = false})
        end
    else
        key_cb = function(_, state)
            -- Emulate the same semantics as input.c uses for most bindings:
            -- For keyboard, "down" runs the command, "up" does nothing;
            -- for mouse, "down" does nothing, "up" runs the command.
            -- Also, key repeat triggers the binding again.
            local event = state:sub(1, 1)
            local is_mouse = state:sub(2, 2) == "m"
            local canceled = state:sub(3, 3) == "c"
            if canceled or event == "r" and not repeatable then
                return
            end
            if is_mouse and (event == "u" or event == "p") then
                fn()
            elseif not is_mouse and (event == "d" or event == "r" or event == "p") then
                fn()
            end
        end
        msg_cb = fn
    end
    local prefix = scalable and "" or " nonscalable"
    if key and #key > 0 then
        attrs.bind = key .. prefix .. " script-binding " .. mp.script_name .. "/" .. name
    end
    attrs.name = name
    -- new bindings override old ones (but do not overwrite them)
    key_binding_counter = key_binding_counter + 1
    attrs.priority = key_binding_counter
    key_bindings[name] = attrs
    key_bindings_dirty = true
    dispatch_key_bindings[name] = key_cb

    ---@diagnostic disable-next-line: param-type-mismatch
    amp.register_script_message(name, msg_cb)
end

---@param key string?
---@param name string?
---@param fn binding_callback?
---@param rp (string|table)?
---@overload fun(
---     key: string?,
---     fn: binding_callback?,
---     rp: (string|table)?
--- ):void
function amp.add_key_binding(key, name, fn, rp)
    add_binding({forced=false}, key, name, fn, rp)
end

---@param key string?
---@param name string?
---@param fn binding_callback?
---@param rp (string|table)?
---@overload fun(
---     key: string?,
---     fn: binding_callback?,
---     rp: (string|table)?
--- ):void
function amp.add_forced_key_binding(key, name, fn, rp)
    add_binding({forced=true}, key, name, fn, rp)
end

---@param name string
function amp.remove_key_binding(name)
    key_bindings[name] = nil
    dispatch_key_bindings[name] = nil
    key_bindings_dirty = true
    amp.unregister_script_message(name)
end


---@type table<mp_timer, mp_timer>
local timers = {}

---@diagnostic disable-next-line: missing-fields
---@type _mp_timer_mt
local timer_mt = {}
timer_mt.__index = timer_mt

---@param seconds number
---@param cb fun():void
---@param disabled boolean?
---@return mp_timer
function amp.add_timeout(seconds, cb, disabled)
    local t = amp.add_periodic_timer(seconds, cb, disabled)
    t.oneshot = true
    return t
end

---@param seconds number
---@param cb fun():void
---@param disabled boolean?
---@return mp_timer
function amp.add_periodic_timer(seconds, cb, disabled)
    local t = {
        timeout = seconds,
        cb = cb,
        oneshot = false,
    }
    setmetatable(t, timer_mt)
    if not disabled then
        t:resume()
    end
    ---@cast t mp_timer
    return t
end

function timer_mt.stop(t)
    if timers[t] then
        timers[t] = nil
        t.next_deadline = t.next_deadline - mp.get_time()
    end
end

function timer_mt.kill(t)
    timers[t] = nil
    t.next_deadline = nil
end
amp.cancel_timer = timer_mt.kill

function timer_mt.resume(t)
    if not timers[t] then
        local timeout = t.next_deadline
        if timeout == nil then
            timeout = t.timeout
        end
        t.next_deadline = mp.get_time() + timeout
        timers[t] = t
    end
end

---@return boolean
function timer_mt.is_enabled(t)
    return timers[t] ~= nil
end

-- Return the timer that expires next.
---@generic T
---@param scheduled? asyncio.TimerHandle[]
---@return mp_timer|number?
---@overload fun():mp_timer?
---@overload fun(scheduled: asyncio.TimerHandle[]):mp_timer|number?
local function get_next_timer(scheduled)
    ---@type mp_timer?
    local best = nil
    for t, _ in pairs(timers) do
        if best == nil or t.next_deadline < best.next_deadline then
            best = t
        end
    end
    if scheduled then
        local _scheduled
        for _, t in ipairs(scheduled) do
            if _scheduled then
                if t.when < best--[[@cast +number]] then
                    best = t.when
                end
            elseif best == nil or t.when < best.next_deadline then
                best = t.when
                _scheduled = true
            end
        end
    end
    return best
end

---@return number?
function amp.get_next_timeout()
    local timer = get_next_timer()
    if not timer then
        return
    end
    local now = mp.get_time()
    return timer.next_deadline - now
end

-- Run timers that have met their deadline at the time of invocation.
-- Return: time>0 in seconds till the next due timer, 0 if there are due timers
--         (aborted to avoid infinite loop), or nil if no timers
---@generic T
---@param scheduled asyncio.TimerHandle[]
---@return number? wait
---@return fun()[]? cbs
local function process_timers(scheduled)
    ---@type fun()[]
    local cbs = {}
    local t0 = nil
    while true do
        local timer = get_next_timer(scheduled)
        if not timer then
            return
        end
        if type(timer) == "number" then
            -- Scheduled asyncio callbacks store an absolute deadline, while
            -- mp.wait_event expects a relative timeout.
            return math.max(0, timer - mp.get_time()), cbs
        end
        local now = mp.get_time()
        local wait = timer.next_deadline - now
        if wait > 0 then
            return wait, cbs
        else
            if not t0 then
                t0 = now  -- first due callback: always executes, remember t0
            elseif timer.next_deadline > t0 then
                -- don't block forever with slow callbacks and endless timers.
                -- we'll continue right after checking mpv events.
                return 0, cbs
            end

            if timer.oneshot then
                timer:kill()
            else
                timer.next_deadline = now + timer.timeout
            end
            table.insert(cbs, timer.cb)
        end
    end
end

local messages = {}

---@param name string
---@param fn fun(...):void
function amp.register_script_message(name, fn)
    messages[name] = fn
end

---@param name string
function amp.unregister_script_message(name)
    messages[name] = nil
end

local function message_dispatch(ev)
    if #ev.args > 0 then
        local handler = messages[ev.args[1]]
        if handler then
            handler(unpack(ev.args, 2))
        end
    end
end

local property_id = 0
local properties = {}

---@param name properties_t|string
---@param t observe_property_type
---@param cb fun(name:properties_t|string, data:any):void
---@overload fun(name:properties_t|string, t:"native", cb:fun(name:string, data:table|string|number|boolean):void)
---@overload fun(name:properties_t|string, t:"number", cb:fun(name:string, data:number|int):void)
---@overload fun(name:properties_t|string, t:"string", cb:fun(name:string, data:string):void)
---@overload fun(name:properties_t|string, t:"bool",   cb:fun(name:string, data:boolean):void)
function amp.observe_property(name, t, cb)
    local id = property_id + 1
    property_id = id
    properties[id] = cb
    ---@diagnostic disable-next-line: param-type-mismatch
    mp.raw_observe_property(id, name, t)
end

---@param cb fun(name:string):void
function amp.unobserve_property(cb)
    for prop_id, prop_cb in pairs(properties) do
        if cb == prop_cb then
            properties[prop_id] = nil
            mp.raw_unobserve_property(prop_id)
        end
    end
end

local function property_change(ev)
    local prop = properties[ev.id]
    if prop then
        prop(ev.name, ev.data)
    end
end


local event_handlers = {}


---@alias mp_ev_start_file         {id:int, event:string, error:string?,
---                                 playlist_entry_id: int}
---@alias mp_ev_end_file           {id:int, event:string, error:string?,
---                                 reason: "eof"|"stop"|"quit"|"error"|"redirect"|"unknown",
---                                 playlist_entry_id: int,
---                                 playlist_insert_id: int?,
---                                 playlist_insert_num_entries: table[]?}
---@alias mp_ev_file_loaded        {id:int, event:string, error:string?}
---@alias mp_ev_seek               {id:int, event:string, error:string?}
---@alias mp_ev_playback_restart   {id:int, event:string, error:string?}
---@alias mp_ev_shutdown           {id:int, event:string, error:string?}
---@alias mp_ev_log_message        {id:int, event:string, error:string?,
---                                 prefix: string, level: string, text: string}
---@alias mp_ev_hook               {id:int, event:string, error:string?, 
---                                 hook_id:int}
---@alias mp_ev_command_reply      {id:int, event:string, error:string?, 
---                                 result:string}
---@alias mp_ev_client_message     {id:int, event:string, error:string?,
---                                 args: any[]}
---@alias mp_ev_video_reconfig     {id:int, event:string, error:string?}
---@alias mp_ev_audio_reconfig     {id:int, event:string, error:string?}
---@alias mp_ev_property_change    {id:int, event:string, error:string?,
---                                 name:string, data:any}

---@param name string
---@param cb fun(ev:table)
---@overload fun(name:"start-file",          cb:fun(ev:mp_ev_start_file))
---@overload fun(name:"end-file",            cb:fun(ev:mp_ev_end_file))
---@overload fun(name:"file-loaded",         cb:fun(ev:mp_ev_file_loaded))
---@overload fun(name:"seek",                cb:fun(ev:mp_ev_seek))
---@overload fun(name:"playback-restart",    cb:fun(ev:mp_ev_playback_restart))
---@overload fun(name:"shutdown",            cb:fun(ev:mp_ev_shutdown))
---@overload fun(name:"log-message",         cb:fun(ev:mp_ev_log_message))
---@overload fun(name:"hook",                cb:fun(ev:mp_ev_hook))
---@overload fun(name:"command-reply",       cb:fun(ev:mp_ev_command_reply))
---@overload fun(name:"client-message",      cb:fun(ev:mp_ev_client_message))
---@overload fun(name:"video-reconfig",      cb:fun(ev:mp_ev_video_reconfig))
---@overload fun(name:"audio-reconfig",      cb:fun(ev:mp_ev_audio_reconfig))
---@overload fun(name:"property-change",     cb:fun(ev:mp_ev_property_change))
function amp.register_event(name, cb)
    local list = event_handlers[name]
    if not list then
        list = {}
        event_handlers[name] = list
    end
    list[#list + 1] = cb
    return mp.request_event(name, true)
end

---@param cb fun(ev:table)
function amp.unregister_event(cb)
    for name, sub in pairs(event_handlers) do
        local found = false
        for _, e in ipairs(sub) do
            if e == cb then
                found = true
                break
            end
        end
        if found then
            -- create a new array, just in case this function was called
            -- from an event handler
            local new = {}
            for i = 1, #sub do
                if sub[i] ~= cb then
                    new[#new + 1] = sub[i]
                end
            end
            event_handlers[name] = new
            if #new == 0 then
                mp.request_event(name, false)
            end
        end
    end
end

-- default handlers
amp.register_event("client-message", message_dispatch)
amp.register_event("property-change", property_change)

-- called before the event loop goes back to sleep
local idle_handlers = {}

---@param cb fun()
function amp.register_idle(cb)
    idle_handlers[#idle_handlers + 1] = cb
end

---@param cb fun()
function amp.unregister_idle(cb)
    local new = {}
    for _, handler in ipairs(idle_handlers) do
        if handler ~= cb then
            new[#new + 1] = handler
        end
    end
    idle_handlers = new
end

-- sent by "script-binding"
amp.register_script_message("key-binding", dispatch_key_binding)


amp.register_idle(amp.flush_keybindings)


local hook_table = {}

---@class _mp_hook_event_mt
local hook_mt = {}
hook_mt.__index = hook_mt

function hook_mt.cont(t)
    if t._id == nil then
        mp.msg.error("hook already continued")
    else
        mp.raw_hook_continue(t._id)
        t._id = nil
    end
end

function hook_mt.defer(t)
    t._defer = true
end

amp.register_event("hook", function(ev)
    local fn = hook_table[tonumber(ev.id)]
    local hookobj = {
        _id = ev.hook_id,
        _defer = false,
    }
    setmetatable(hookobj, hook_mt)
    if fn then
        fn(hookobj)
    end
    if not hookobj._defer and hookobj._id ~= nil then
        hookobj:cont()
    end
end)

---@class mp_hook_event : _mp_hook_event_mt

--[[
    on_load:
        在打开文件时调用，在实际执行任何操作之前调用。
        例如，您可以读取和写入 stream-open-filename 用于将 URL 重定向到其他位置的属性
        （考虑支持 （很少向用户提供直接媒体 URL 的流媒体网站），或者 您可以通过设置属性来为每个文件设置选项。
        file-local-options/<option name> 玩家将等待所有钩子都运行完毕。
        排序在 start-file 之后， playback-restart 之前。

    on_load_fail:
        文件打开后调用，但失败。这可能是 用于在原生解复用器无法识别时提供备用方案 该文件，而不是始终在原生解复用器之前运行，
        例如 on_load 仅当 stream-open-filename 时才会重试解复用。 已更改。如果再次失败，则不会再次调用此钩子，并且 加载肯定失败了。
        排序在 on_load 之后， playback-restart 和 end-file 之前。

    on_preloaded:
        此方法在文件打开后、选择音轨和创建解码器之前调用。如果 API 用户希望根据可用音轨集手动选择音轨，这将非常有用。
        此外，它还允许 API 以特定方式初始化 --lavfi-complex ，而无需事先“探测”可用流。
        请注意，这尚未应用默认曲目选择。具体哪些操作可以执行、哪些操作不能执行，以及哪些信息可用、哪些信息尚不可用，所有这些都可能发生变化。
        按 on_load_fail 等之后、 playback-restart 之前排序。

    on_unload:
        在关闭文件之前，以及在实际取消初始化所有内容之前运行此命令。在此状态下无法恢复播放。
        排序在 end-file 之前。错误情况下也会发生（然后是之后）。 on_load_fail ).

    on_before_start_file:
        在发送 start-file 事件之前运行。（如果任何客户端更改了当前播放列表条目，或向播放器发送了退出命令，
        则在钩子返回后，相应的事件实际上不会发生。）这有助于在加载新文件之前清除属性更改。
    on_after_end_file:
        在 end-file 事件发生后运行。可用于在文件执行完毕后清除属性更改。
]]
---@alias mp_hooks "on_load"|"on_load_fail"|"on_preloaded"|"on_unload"|"on_before_start_file"|"on_after_end_file"

---@param name mp_hooks
---@param pri int
---@param cb fun(ev:mp_hook_event):void
function amp.add_hook(name, pri, cb)
    local id = #hook_table + 1
    hook_table[id] = cb
    -- The C API suggests using 0 for a neutral priority, but lua.rst suggests
    -- 50 (?), so whatever.
    mp.raw_hook_add(id, name, pri - 50)
end

local async_call_table = {}
local async_next_id = 1

---@param node table
---@param cb fun(success: boolean, result: any?, error: string?)
---@overload fun(
---    node: table,
---    cb: fun(success: boolean, result: any?, error: string?)
--- ):nil,string
---@return table?, string?
function amp.command_native_async(node, cb)
    local id = async_next_id
    async_next_id = async_next_id + 1
    cb = cb or function() end
    local res, err = mp.raw_command_native_async(id, node)
    if not res then
        amp.add_timeout(0, function() cb(false, nil, err) end)
        return res, err
    end
    local t = {cb = cb, id = id}
    async_call_table[id] = t
    return t
end

amp.register_event("command-reply", function(ev)
    local id = tonumber(ev.id)
    local t = async_call_table[id]
    local cb = t.cb
    t.id = nil
    async_call_table[id] = nil
    if ev.error then
        cb(false, nil, ev.error)
    else
        cb(true, ev.result, nil)
    end
end)

---@param t table
function amp.abort_async_command(t)
    if t.id ~= nil then
        mp.raw_abort_async_command(t.id)
    end
end


---@class asyncio.EventLoop_mp : asyncio.EventLoop
---@overload fun():asyncio.EventLoop_mp
local EventLoop_mp = class.new('asyncio.EventLoop_mp', {asyncio.loops.EventLoop})

amp.EventLoop_mp = EventLoop_mp

function EventLoop_mp:time()
    return mp.get_time()
end

function EventLoop_mp:_run_once()
    local ntodo = #self._ready
    -- debug_msg('EventLoop_mp:_run_once,', ntodo)

    local time = self:time()
    while #self._scheduled > 0 do
        local sche = self._scheduled[1]
        -- debug_msg('EventLoop_mp:_run_once sche.when', sche.when, 'time', time, sche.func)
        if sche.when > time then
            break
        end
        table.insert(self._ready, table.remove(self._scheduled, 1))
    end

    if ntodo > 0 then
        for i = 1, ntodo do
            local handle = table.remove(self._ready, 1)
            if not handle._cancelled then
                -- debug_msg('EventLoop_mp:_run_once run', handle.func)
                handle:_run()
            end
        end
    end
end

local loop = EventLoop_mp()
local _stoping = false
local task_id = 0
---@type table<int, asyncio.Task<nil>>
local events_tasks = setmetatable({}, {__mode = 'v'})
---@type int[]
local err_tasks = {}
---@type fun(ok: boolean, err: string?)[]
local finally_funcs = {}

local function amp_event_loop()
    asyncio.run(function()
        while true do
            await()

            local wait = 0
            local cbs
            wait, cbs = process_timers(loop._scheduled)
            if not wait then
                wait = 1e20
            end
            if #loop._ready ~= 0 or _stoping then
                wait = 0
            end

            if cbs and #cbs > 0 then
                for _, cb in ipairs(cbs) do
                    local t_id = task_id
                    local t = loop:create_task(function()
                        local ok, err = xpcall(cb, debug_traceback)
                        if not ok then
                            table.insert(err_tasks, t_id)
                            error(err, 0)
                        else
                            events_tasks[t_id] = nil
                        end
                    end, string.format('Task-(Timer)-%d', t_id))
                    events_tasks[t_id] = t
                    task_id = task_id + 1
                end
            end

            if wait ~= 0 then
                for _, handler in ipairs(idle_handlers) do
                    local t_id = task_id
                    local t = loop:create_task(function()
                        local ok, err = xpcall(handler, debug_traceback)
                        if not ok then
                            table.insert(err_tasks, t_id)
                            error(err, 0)
                        else
                            events_tasks[t_id] = nil
                        end
                    end, string.format('Task-(idle)-%d', t_id))
                    events_tasks[t_id] = t
                    task_id = task_id + 1
                end
            end

            local e = mp.wait_event(wait)
            if e.event ~= "none" then
                local handlers = event_handlers[e.event]
                if handlers then
                    -- debug_msg('create_task events', #handlers)
                    for _, handler in ipairs(handlers) do
                        -- debug_msg('event', e.event, e.args and e.args[1] or '')
                        local t_id = task_id
                        local t = loop:create_task(function()
                            -- debug_msg('event run', _, handler)
                            local ok, err = xpcall(function()
                                return handler(e)
                            end, debug_traceback)
                            if not ok then
                                table.insert(err_tasks, t_id)
                                error(err, 0)
                            else
                                events_tasks[t_id] = nil
                            end
                        end, string.format('Task-(%s)-%d', e.event, t_id))
                        events_tasks[t_id] = t
                        task_id = task_id + 1
                    end
                end
            end

            if #err_tasks > 0 then
                if #err_tasks == 1 then
                    local err = events_tasks[err_tasks[1]]._exception
                    events_tasks[err_tasks[1]] = nil
                    std.raise(err, 0)
                else
                    local errs = {}
                    for _, t_id in ipairs(err_tasks) do
                        table.insert(errs, tostring(events_tasks[t_id]._exception))
                        events_tasks[t_id] = nil
                    end
                    std.raise(table.concat(errs, 
                        '\nDuring handling of the above exception, another exception occurred:\n'), 0)
                end
            end

            if _stoping and 
                #loop._ready == 0 and 
                #loop._scheduled == 0 then
                -- 这里不等待amp.timer
                break
            end
        end
        -- debug_msg('End of MainLoop')
    end, loop, 'Task-AmpMainLoop')
end

_G.mp_event_loop = function ()
    local ok, err = xpcall(amp_event_loop, debug_traceback)
    if ok then
        err = nil
    end
    local errs = {}
    if #finally_funcs > 0 then
        for _, fn in ipairs(finally_funcs) do
            local _ok, _err = xpcall(function()
                return fn(ok, err)
            end, debug_traceback)
            if not _ok then
                table.insert(errs, tostring(err))
            end
        end
    end
    if err ~= nil then
        table.insert(errs, 1, tostring(err))
    end
    if #errs > 0 then
        std.raise(table.concat(errs, 
            '\nDuring handling of the above exception, another exception occurred:\n'), 0)
    end
end

amp.register_event("shutdown", function()
    -- debug_msg('shutdown recv')
    _stoping = true
end)

---@param fn fun(ok: boolean, err: string?)
function amp.add_finally(fn)
    table.insert(finally_funcs, fn)
end

---@param fn fun(ok: boolean, err: string?)
function amp.remove_finally(fn)
    for i, func in ipairs(finally_funcs) do
        if fn == func then
            table.remove(finally_funcs, i)
            break
        end
    end
end

-- TODO
-- ---@class asyncio.amp._sync
-- local _copy_fields = {}
-- _copy_fields.set_key_bindings = amp.set_key_bindings
-- _copy_fields.flush_keybindings = amp.flush_keybindings
-- _copy_fields.add_key_binding = amp.add_key_binding
-- _copy_fields.add_forced_key_binding = amp.add_forced_key_binding
-- _copy_fields.remove_key_binding = amp.remove_key_binding
-- _copy_fields.add_timeout = amp.add_timeout
-- _copy_fields.add_periodic_timer = amp.add_periodic_timer
-- _copy_fields.get_next_timeout = amp.get_next_timeout
-- _copy_fields.register_script_message = amp.register_script_message
-- _copy_fields.unregister_script_message = amp.unregister_script_message
-- _copy_fields.observe_property = amp.observe_property
-- _copy_fields.unobserve_property = amp.unobserve_property
-- _copy_fields.register_event = amp.register_event
-- _copy_fields.unregister_event = amp.unregister_event
-- _copy_fields.register_idle = amp.register_idle
-- _copy_fields.unregister_idle = amp.unregister_idle
-- _copy_fields.add_hook = amp.add_hook
-- _copy_fields.command_native_async = amp.command_native_async
-- _copy_fields.abort_async_command = amp.abort_async_command

-- ---@class asyncio.amp.sync: asyncio.amp._sync
-- amp.sync = setmetatable({}, {
--     __index = function (t, key)
--     end
-- })

local function warning_for_mp(name)
    return function ()
        local extra = debug.traceback()
        -- local extra
        -- if info ~= nil then
        --     extra = string.format('\n    (from %s:%d)', info.short_src, info.linedefined)
        -- else
        --     extra = ''
        -- end
        mp.msg.warn(string.format(
            "Warning: asyncio.mp is already loaded. Use amp.%s instead of mp.%s%s", name, name, extra))
    end
end

mp.set_key_bindings = warning_for_mp("set_key_bindings")
mp.flush_keybindings = warning_for_mp("flush_keybindings")
mp.add_key_binding = warning_for_mp("add_key_binding")
mp.add_forced_key_binding = warning_for_mp("add_forced_key_binding")
mp.remove_key_binding = warning_for_mp("remove_key_binding")
mp.add_timeout = warning_for_mp("add_timeout")
mp.add_periodic_timer = warning_for_mp("add_periodic_timer")
mp.get_next_timeout = warning_for_mp("get_next_timeout")
mp.register_script_message = warning_for_mp("register_script_message")
mp.unregister_script_message = warning_for_mp("unregister_script_message")
mp.observe_property = warning_for_mp("observe_property")
mp.unobserve_property = warning_for_mp("unobserve_property")
mp.register_event = warning_for_mp("register_event")
mp.unregister_event = warning_for_mp("unregister_event")
mp.register_idle = warning_for_mp("register_idle")
mp.unregister_idle = warning_for_mp("unregister_idle")
mp.add_hook = warning_for_mp("add_hook")
mp.command_native_async = warning_for_mp("command_native_async")
mp.abort_async_command = warning_for_mp("abort_async_command")

---@diagnostic disable-next-line: inject-field
mp.asyncio_event_loop = true
---@diagnostic disable-next-line: inject-field
mp.amp = amp

return amp