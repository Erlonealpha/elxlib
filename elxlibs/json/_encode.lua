---@class _json.Encoder
---@field nil_placeholder any
local encoder = {}
encoder.__index = encoder

function encoder.new(nil_placeholder)
    return setmetatable({nil_placeholder = nil_placeholder}, encoder)
end

local function is_list(t)
    local i
    if type(t) == "table" then
        for k, _ in pairs(t) do
            if type(k) ~= "number" then
                -- key is not a number
                return false
            elseif i ~= nil and k-1 ~= i then
                -- table keys are not sequential
                return false
            end
        end
        return true
    end
    return false
end

local function _format_json(t, indent, break_line, level, nil_placeholder)
    local result
    local level_str = string.rep(" ", indent*level)
    if type(t) == "table" then
        if t == nil_placeholder then
            result = "null"
        elseif is_list(t) then
            result = level_str .. "[" .. break_line
            for i, v in ipairs(t) do
                if i == #t then
                    result = result .. level_str .. _format_json(v, indent, break_line, level+1, nil_placeholder) .. break_line
                else
                    result = result .. level_str .. _format_json(v, indent, break_line, level+1, nil_placeholder) .. "," .. break_line
                end
            end
            result = result .. level_str .. "]"
        else
            result = level_str .. "{" .. break_line
            local first = true
            for k, v in pairs(t) do
                if not first then
                    -- 为上一个元素尾部补充逗号和换行符
                    result = result .. "," .. break_line
                end
                result = result .. level_str .. string.format("%s\"%s\": %s",
                    string.rep(" ", indent), tostring(k), _format_json(v, indent, break_line, level+1, nil_placeholder))
                first = false
            end
            if not first then
                -- 表中有任意元素，则在尾部补充换行符
                result = result .. break_line
            end
            result = result .. level_str .. "}"
        end
    elseif type(t) == "string" then
        result = t:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        result = string.format("\"%s\"", result)
    else
        -- if strict then
            
        -- end
        result = tostring(t)
    end
    return result
end

---@param t table
---@param indent number|nil
---@param break_line boolean|nil|string
---@return string
function encoder:encode(t, indent, break_line)
    if indent == nil then
        if break_line then
            indent = 4
        else
            indent = 0
        end
    end
    local break_line_str = break_line and "\n" or " "
    return _format_json(t, indent, break_line_str, 0, self.nil_placeholder)
end

return encoder