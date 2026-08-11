local events = {}

---@type {loop: asyncio.EventLoop?}
local _running_loop = {loop = nil}

function events.get_running_loop()
    if _running_loop.loop == nil then
        error("No running event loop")
    end
    debug_msg('get_running_loop', _running_loop.loop)
    return _running_loop.loop
end

---@param loop asyncio.EventLoop?
function events._set_running_loop(loop)
    debug_msg('_set_running_loop', loop)
    _running_loop.loop = loop
end

function events._get_running_loop()
    debug_msg('_get_running_loop', _running_loop.loop)
    return _running_loop.loop
end

return events