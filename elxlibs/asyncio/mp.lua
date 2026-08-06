--- Override defaults.lua defines to handle events in asyncio eventloop.

local mp = require("mp")


local messages = {}

function mp.register_script_message(name, fn)
    messages[name] = fn
end

function mp.unregister_script_message(name)
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

function mp.observe_property(name, t, cb)
    local id = property_id + 1
    property_id = id
    properties[id] = cb
    mp.raw_observe_property(id, name, t)
end

function mp.unobserve_property(cb)
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

function mp.register_event(name, cb)
    local list = event_handlers[name]
    if not list then
        list = {}
        event_handlers[name] = list
    end
    list[#list + 1] = cb
    return mp.request_event(name, true)
end

function mp.unregister_event(cb)
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

mp.register_event("shutdown", exit)
mp.register_event("client-message", message_dispatch)
mp.register_event("property-change", property_change)

local idle_handlers = {}

function mp.register_idle(cb)
    idle_handlers[#idle_handlers + 1] = cb
end