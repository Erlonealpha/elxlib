local mp = require('mp')

local os_name = mp.get_property('platform')

local lockfile
if os_name == 'windows' then
    lockfile = require('elxlibs.lockfile.win32')
elseif os_name == 'linux' then
    lockfile = require('elxlibs.lockfile.linux')
else
    error('Unsupported OS: ' .. os_name)
end

if lockfile == nil then
    error('lockfile load failed')
end

---@class elxlockfile
local M = {}

---@type LockFile
M.LockFile = lockfile

return M
