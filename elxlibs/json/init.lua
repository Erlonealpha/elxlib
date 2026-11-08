---@class json
local M = {version = "0.2.0"}

local Decoder = require("elxlibs.json.decode")
local Encoder = require("elxlibs.json.encode")

M.null = setmetatable({}, {
    __tostring = function() return "null" end,
    __jsontype = "null"
})

---@interface json.IEncoder
---@field encode fun(s:self, t:any, indent:integer?, nil_placeholder:any, fallback:(fun(value:any):string)?):string

---@interface json.IDecoder
---@field decode fun(s:self, str:string):any JSON scalars, tables or the configured null placeholder

---@param t any
---@param indent? int?
---@param nil_placeholder? any
---@param encoder? json.IEncoder
---@param fallback? fun(value:any):string
---@return string
function M.dumps(t, indent, nil_placeholder, encoder, fallback)
    if nil_placeholder == nil then nil_placeholder = M.null end
    encoder = encoder or Encoder.new(indent, nil_placeholder)
    return encoder:encode(t, indent, nil_placeholder, fallback)
end

---@param str string
---@param nil_placeholder? any
---@param decoder? json.IDecoder
---@return any JSON scalars, tables or the configured null placeholder
function M.loads(str, nil_placeholder, decoder)
    decoder = decoder or Decoder.new(nil_placeholder)
    return decoder:decode(str)
end

return M
