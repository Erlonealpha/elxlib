local exc = require 'elxlibs.std.exception'

if _G.mp_event_loop and not _G.mp_event_loop_wrap then
    local event_loop = _G.mp_event_loop
    _G.mp_event_loop = function()
        local ok, err = xpcall(event_loop, exc.traceback)
        if not ok then
            error(tostring(err), 0)
        end
    end
    _G.mp_event_loop_wrap = true
    _G.mp_event_loop_wrap_origin = event_loop
end
