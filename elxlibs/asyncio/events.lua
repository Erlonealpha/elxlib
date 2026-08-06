local events = {}

local _running_loop = {loop = nil}

function events.get_running_loop()
    if _running_loop.loop == nil then
        error("No running event loop")
    end
    return _running_loop.loop
end

function events._set_running_loop(loop)
    _running_loop.loop = loop
end

return events