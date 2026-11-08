-- Only fixture-owned paths are changed; user configuration is disabled by Python.
local root = assert(os.getenv('ELXLIB_TEST_ROOT')):gsub('\\', '/')
local directory = assert(os.getenv('ELXLIB_TEST_FILES')):gsub('\\', '/')
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
local mp = require 'mp'
mp.utils = require 'mp.utils'
-- Point the adapter at the actual repository while the host script lives in temp.
mp.get_script_directory = function() return root end
local fs = require 'elxlibs.fs'

local ok, err = pcall(function()
    local source = directory .. '/source.bin'
    assert(fs.exists(source) == true)
    assert(fs.exists(directory .. '/missing') == false)
    assert(fs.get_size(source) == 7)
    local stat = assert(fs.get_stat(source))
    assert(stat.st_size == 7 and stat.st_mode > 0 and stat.st_mtime > 0)
    assert(stat.st_mtime_ns > stat.st_mtime and stat.st_file_attributes ~= nil)
    assert(fs.copy(source, directory .. '/copied.bin'))
    local tree = directory .. '/tree'
    assert(fs.mkdir(tree))
    -- Bundled fstool currently ignores -e for existing directories.
    assert(fs.mkdir(tree) == false)
    assert(fs.mkdir(tree, false) == false)
    assert(fs.copy(source, tree .. '/nested.bin'))
    assert(fs.get_size(tree, true) == 7)
    assert(fs.copy(tree, directory .. '/tree-copy', true))
    assert(fs.remove_dir(tree) == false)
    assert(fs.remove_dir(tree, true))
    assert(fs.exists(tree) == false)
    local size, size_error = fs.get_size(directory .. '/missing')
    assert(size == nil and type(size_error) == 'string')
    local missing_stat, stat_error = fs.get_stat(directory .. '/missing')
    assert(missing_stat == nil and type(stat_error) == 'string')
end)
if ok then
    local report = assert(io.open(assert(os.getenv('ELXLIB_TEST_REPORT')), 'w'))
    report:write('PASS: fs real subprocess, binary/recursive copy, size/stat, flags and failures\n')
    report:close()
else
    mp.msg.error(err)
end
mp.commandv('quit', ok and '0' or '1')
