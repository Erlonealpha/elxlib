-- Loaded in an isolated, headless mpv process by real_host.py.
local root = assert(os.getenv('ELXLIB_TEST_ROOT')):gsub('\\', '/')
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
table.pack = table.pack or function(...) return {n = select('#', ...), ...} end
table.unpack = table.unpack or unpack
_G.debug_msg = function() end

local mp = require 'mp'
local asyncio = require 'elxlibs.asyncio'
local amp = require 'elxlibs.asyncio.amp'
local await = asyncio.await
---@type table<string, boolean>
local seen = {}
local watchdog = amp.add_timeout(3, function()
    error('real host did not deliver all callbacks')
end)

amp.register_script_message('elxlib-smoke', function(value)
    assert(value == 'payload', 'message payload')
    seen.message = true
end)
amp.observe_property('pause', 'bool', function(name, value)
    assert(name == 'pause' and type(value) == 'boolean', 'property callback')
    seen.property = true
end)
amp.command_native_async({'expand-text', '${pause}'}, function(ok, value, err)
    assert(ok and type(value) == 'string' and err == nil, 'command callback')
    seen.command = true
end)
amp.add_key_binding('F24', 'elxlib-smoke-key', function() end)
amp.add_forced_key_binding('F23', 'elxlib-smoke-forced', function() end)
mp.commandv('script-message-to', mp.get_script_name(), 'elxlib-smoke', 'payload')

amp.add_timeout(0.1, function()
    assert(seen.message and seen.property and seen.command, 'host callbacks')
    seen.timer = true
    watchdog:kill()
    mp.commandv('quit')
end)
amp.add_finally(asyncio.async(function()
    await(asyncio.sleep(0))
    assert(seen.timer, 'timer before shutdown')
    local file = assert(io.open(assert(os.getenv('ELXLIB_TEST_REPORT')), 'w'))
    file:write('PASS: message, property, command, timer, shutdown/finally\n')
    file:close()
end))
