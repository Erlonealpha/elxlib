local root = assert(os.getenv('ELXLIB_TEST_ROOT')):gsub('\\', '/')
local directory = assert(os.getenv('ELXLIB_TEST_FILES')):gsub('\\', '/')
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
table.pack = table.pack or function(...) return {n = select('#', ...), ...} end
table.unpack = table.unpack or unpack
_G.debug_msg = function() end
local mp = require 'mp'
mp.utils = require 'mp.utils'
mp.get_script_directory = function() return root end
local A = require 'elxlibs.asyncio'
local fs = require 'elxlibs.aiofs'
local amp = require 'elxlibs.asyncio.amp'
local await = A.await
local watchdog = amp.add_timeout(5, function() error('aiofs host did not finish') end)

amp.add_timeout(0, function()
    A.create_task(A.async(function()
        local source = directory .. '/source.bin'
        local result = await(fs.exists(source))
        assert(result.ok and result.result == true)
        local missing = await(fs.exists(directory .. '/missing'))
        assert(missing.ok and missing.result == false)
        local size = await(fs.get_size(source))
        assert(size.ok and size.result == 7)
        local stat = await(fs.get_stat(source))
        assert(stat.ok and stat.result and stat.result.st_size == 7 and stat.result.st_file_attributes ~= nil)
        assert(await(fs.copy(source, directory .. '/copied.bin')).ok)
        local tree = directory .. '/tree'
        assert(await(fs.create_dir(tree)).ok)
        -- Current binary returns a failure for existing directories despite -e.
        assert(await(fs.create_dir(tree)).ok == false)
        assert(await(fs.create_dir(tree, false)).ok == false)
        assert(await(fs.copy(source, tree .. '/nested.bin')).ok)
        local tree_size = await(fs.get_size(tree, true))
        assert(tree_size.ok and tree_size.result == 7)
        assert(await(fs.copy(tree, directory .. '/tree-copy', true)).ok)
        assert(await(fs.remove_dir(tree)).ok == false)
        assert(await(fs.remove_dir(tree, true)).ok)
        local removed = await(fs.exists(tree))
        assert(removed.ok and removed.result == false)
        local bad_size = await(fs.get_size(directory .. '/missing'))
        assert(bad_size.ok == false and type(bad_size.error) == 'string')
        local bad_stat = await(fs.get_stat(directory .. '/missing'))
        assert(bad_stat.ok == false and type(bad_stat.error) == 'string')
        watchdog:kill()
        local report = assert(io.open(assert(os.getenv('ELXLIB_TEST_REPORT')), 'w'))
        report:write('PASS: aiofs real amp callbacks, binary/recursive copy, size/stat and failures\n')
        report:close()
        mp.commandv('quit')
    end))
end)
