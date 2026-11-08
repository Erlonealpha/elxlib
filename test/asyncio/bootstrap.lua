-- mpv-luatest sets project/test search paths before running this setup hook.
-- Bare LuaJIT may omit the Lua 5.2 table helpers used by elxlib.
table.pack = table.pack or function(...)
    return { n = select('#', ...), ... }
end
table.unpack = table.unpack or unpack

-- Normally supplied by the mpv entry module.
_G.debug_msg = _G.debug_msg or function() end

-- The amp adapter needs a scripted wait_event implementation beyond the
-- general mpv-luatest fake host. Keep it under a project-specific module name.
local amp_stub = require 'amp_stub'
package.preload['mp'] = function() return amp_stub.new() end
package.loaded['mp'] = nil
