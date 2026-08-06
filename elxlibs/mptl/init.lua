local mp = require("mp")


---@class mptl
local mptl = {}

---@alias subprocess_result {
---     status: int,
---     stdout: string,
---     stderr: string,
---     error_string: ""|"killed"|"init",
---     killed_by_us: boolean,
--- }

---@param opts {
---     args: string[],
---     playback_only?: boolean,
---     capture_size?: int,
---     capture_stdout?: boolean,
---     capture_stderr?: boolean,
---     detach?: boolean,
---     env?: string[],
---     stdin_data?: string,
---     passthrough_stdin?: boolean,
---
---     name?: "subprocess",
--- }?
--- @return subprocess_result?, string?
function mptl.subprocess(opts)
    if opts == nil then
        opts = {}
    end
    opts.name = "subprocess"
    local rv, err = mp.command_native(opts)
    ---@cast rv subprocess_result?
    return rv, err
end

return mptl