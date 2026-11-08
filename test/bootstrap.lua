-- Shared setup for all test groups; mpv-luatest configures module search paths.
table.pack = table.pack or function(...)
    return { n = select('#', ...), ... }
end
table.unpack = table.unpack or unpack

-- Normally supplied by the mpv entry module.
_G.debug_msg = _G.debug_msg or function() end
