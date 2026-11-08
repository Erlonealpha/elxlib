-- The amp adapter needs a scripted wait_event implementation beyond the
-- general mpv-luatest fake host. Keep it under a project-specific module name.
-- Loaded by this group's support module, not by the shared test bootstrap.
local amp_stub = require 'test_asyncio.amp_stub'
package.preload['mp'] = function() return amp_stub.new() end
package.loaded['mp'] = nil
