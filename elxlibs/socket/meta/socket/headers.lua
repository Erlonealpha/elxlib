---@meta

---@class SocketHeaders
local headers = {}

---@field canonic table<string, string> 小写 HTTP/MIME 字段名到规范大小写的映射。

---注册一个自定义的 HTTP/MIME 字段规范大小写形式。
---@param header string 字段名，例如 "X-Request-ID"。
function headers.setcanonic(header) end

return headers
