---@class json.Encoder
---@field indent int?
---@field nil_placeholder any
---@field type_func_map table<string, function|string>
local encoder = {}
encoder.__index = encoder

function encoder.new(indent, nil_placeholder)
    local type_func_map = {
        [ "nil"     ] = "encode_nil",
        [ "table"   ] = "encode_table",
        [ "string"  ] = "encode_string",
        [ "number"  ] = "encode_number",
        [ "boolean" ] = tostring,
    }
    return setmetatable({indent = indent, nil_placeholder = nil_placeholder, type_func_map = type_func_map}, encoder)
end

local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end

function encoder:escape_char(c)
    return escape_char(c)
end

function encoder:encode_nil(c, stack, level)
    if self.nil_placeholder ~= nil then
        return self:_encode(self.nil_placeholder, stack, level)
    end
    return "null"
end

---@param val any
---@param stack table
---@param level int
---@return string
function encoder:encode_table(val, stack, level)
    local res = {}
    stack = stack or {}
    level = level or 0

    -- Circular reference?
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Treat as array -- check keys are valid and it is not sparse
        local n = 0
        for k in pairs(val) do
            if type(k) ~= "number" then
                error("invalid table: mixed or invalid key types")
            end
            n = n + 1
        end
        if n ~= #val then
            error("invalid table: sparse array")
        end
        -- Encode
        for i, v in ipairs(val) do
            table.insert(res, self:_encode(v, stack, level + 1))
        end
        stack[val] = nil
        if self.indent ~= nil then
            if #res == 0 then
                return "[]"
            end
            local indent_str = string.rep(" ", self.indent * (level + 1))
            local close_indent_str = string.rep(" ", self.indent * level)
            local items = {}
            for _, v in ipairs(res) do
                table.insert(items, indent_str .. v)
            end
            return "[\n" .. table.concat(items, ",\n") .. "\n" .. close_indent_str .. "]"
        else
            return "[" .. table.concat(res, ",") .. "]"
        end
    else
        -- Treat as an object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types")
            end
            if self.indent ~= nil then
                table.insert(res, self:_encode(k, stack, level + 1) .. ": " .. self:_encode(v, stack, level + 1))
            else
                table.insert(res, self:_encode(k, stack, level + 1) .. ":" .. self:_encode(v, stack, level + 1))
            end
        end
        stack[val] = nil
        if self.indent ~= nil then
            local indent_str = string.rep(" ", self.indent * (level + 1))
            local close_indent_str = string.rep(" ", self.indent * level)
            local items = {}
            for _, v in ipairs(res) do
                table.insert(items, indent_str .. v)
            end
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. close_indent_str .. "}"
        else
            return "{" .. table.concat(res, ",") .. "}"
        end
    end
end


function encoder:encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


function encoder:encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end

function encoder:_encode(val, stack, level)
    local t = type(val)
    local f = self.type_func_map[t]
    if type(f) == "function" then
        return f(val, stack)
    else
        return self[f](self, val, stack, level)
    end
    error("unexpected type '" .. t .. "'")
end

function encoder:encode(t, indent, nil_placeholder)
    if indent ~= nil then
        self.indent = indent
    end
    if nil_placeholder ~= nil then
        self.nil_placeholder = nil_placeholder
    end
    return self:_encode(t, nil, 0)
end

return encoder
