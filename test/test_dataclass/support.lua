local S = {}

--- Invalid/dynamic values used to test public runtime boundaries.
---@param value any
---@return any
function S.runtime(value) return value end

return S
