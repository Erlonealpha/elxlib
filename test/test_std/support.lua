local S = {}

--- Dynamic/invalid values for runtime reflection boundary checks.
---@param value any
---@return any
function S.runtime(value) return value end

return S
