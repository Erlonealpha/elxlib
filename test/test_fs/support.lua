local S = {}

--- Load the real fs/mptl against an isolated subprocess host, restoring globals.
---@param body fun(fs:elxfs, host:table)
---@param platform? string
function S.with_host(body, platform)
    local names = {'mp', 'elxlibs.fs', 'elxlibs.mptl'}
    local saved = {}
    for _, name in ipairs(names) do saved[name] = package.loaded[name]; package.loaded[name] = nil end
    local preload = package.preload.mp
    local host = {calls = {}, result = {status = 0, stdout = 'true\n', stderr = ''}}
    function host.get_property() return platform or 'windows' end
    function host.get_script_directory() return 'X:/scripts/example' end
    host.utils = {split_path = function() return 'X:/scripts/', 'example' end}
    function host.command_native(opts)
        host.calls[#host.calls + 1] = opts
        return host.result, host.error
    end
    package.preload.mp = function() return host end
    local ok, err = pcall(function() body(require 'elxlibs.fs', host) end)
    package.preload.mp = preload
    for _, name in ipairs(names) do package.loaded[name] = saved[name] end
    if not ok then error(err, 0) end
end

return S
