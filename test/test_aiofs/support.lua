local S = {}
local fs_support = require 'test_fs.support'

--- Reload asyncio/aiofs around an isolated command adapter, then restore modules.
---@param body fun(aiofs:aiofs, asyncio:asyncio, adapter:table)
function S.with_adapter(body)
    local saved = {}
    for name, value in pairs(package.loaded) do
        if name:match('^elxlibs%.asyncio') or name == 'elxlibs.aiofs' then
            saved[name] = value
            package.loaded[name] = nil
        end
    end
    local preload = package.preload['elxlibs.asyncio.mp']
    local adapter = {calls = {}, aborted = {}}
    function adapter.command_native_async(opts, cb)
        local token = {id = #adapter.calls + 1}
        adapter.calls[#adapter.calls + 1] = {opts = opts, callback = cb, token = token}
        if adapter.launch_error then return nil, adapter.launch_error end
        if adapter.response then
            ---@type {success:boolean?, result:table?, error:string?}
            local r = assert(adapter.response)
            require('elxlibs.asyncio').loops.get_running_loop():call_soon(function()
                cb(r.success, r.result, r.error)
            end)
        end
        return token
    end
    function adapter.abort_async_command(token) adapter.aborted[#adapter.aborted + 1] = token end
    function adapter.reply(index, success, result, err)
        adapter.calls[index].callback(success, result, err)
    end
    package.preload['elxlibs.asyncio.mp'] = function() return adapter end
    local ok, err = pcall(function()
        fs_support.with_host(function(_, host)
            host.msg = setmetatable({}, {__index = function() return function() end end})
            body(require 'elxlibs.aiofs', require 'elxlibs.asyncio', adapter)
        end)
    end)
    package.preload['elxlibs.asyncio.mp'] = preload
    for name in pairs(package.loaded) do
        if name:match('^elxlibs%.asyncio') or name == 'elxlibs.aiofs' then package.loaded[name] = nil end
    end
    for name, value in pairs(saved) do package.loaded[name] = value end
    if not ok then error(err, 0) end
end

---@param A asyncio
---@param body function|asyncio.Coroutine<any>
function S.run(A, body)
    local class = require 'elxlibs.std.class'
    ---@class _aiofs_test.Loop : asyncio.EventLoop
    ---@overload fun():self
    local Loop = class.new('_aiofs_test.Loop', A.loops.EventLoop)
    function Loop.time(_self) return os.clock() end
    local loop = Loop()
    local watchdog = loop:call_later(2, function() error('TEST-WATCHDOG: aiofs did not finish') end)
    loop:set_exception_handler(function(context) error(context.exception or context.msg, 0) end)
    local result = table.pack(pcall(function()
        return loop:run_until_complete(loop:create_task(body))
    end))
    watchdog:cancel()
    loop:close()
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

return S
