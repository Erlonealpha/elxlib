---@class json
local M = {version = "0.1.0"}

local Decoder = require("elxlibs.json.decode")
local Encoder = require("elxlibs.json.encode")

M.null = setmetatable({}, {
    __tostring = function() return "null" end,
    __jsontype = "null"
})

---@interface json.IEncoder
---@field encode fun(s:self, t:table, null:any, ...:any):string

---@interface json.IDecoder
---@field decode fun(s:self, str:string)

---@param t any
---@param indent? int?
---@param nil_placeholder? any
---@param encoder? json.IEncoder
---@return string
function M.dumps(t, indent, nil_placeholder, encoder, fallback)
    nil_placeholder = nil_placeholder or M.null
    encoder = encoder or Encoder.new(indent, nil_placeholder)
    return encoder:encode(t, indent, nil_placeholder, fallback)
end

---@param str string
---@param nil_placeholder? any
---@param decoder? json.IDecoder
function M.loads(str, nil_placeholder, decoder)
    decoder = decoder or Decoder.new(nil_placeholder)
    return decoder:decode(str)
end

return M