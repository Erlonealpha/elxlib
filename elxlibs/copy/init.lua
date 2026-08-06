---@class elxcopy
local copy = {}

function copy.deep_copy(obj)
    if type(obj) ~= 'table' then
        return obj
    end
    local res = {}
    for k, v in pairs(obj) do
        res[copy.deep_copy(k)] = copy.deep_copy(v)
    end
    return res
end

function copy.shallow_copy(obj)
    if type(obj) ~= 'table' then
        return obj
    end
    local res = {}
    for k, v in pairs(obj) do
        res[k] = v
    end
    return res
end

return copy