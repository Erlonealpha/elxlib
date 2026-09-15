---@meta

---@class Mime
local mime = {}

---@field encodet table<string, function>
---@field decodet table<string, function>
---@field wrapt table<string, function>

---根据编码名称创建解码过滤器。
---@param encoding? 'base64'|'quoted-printable'|string
---@return Ltn12Filter
function mime.decode(encoding) end

---根据编码名称创建编码过滤器。
---@param encoding? 'base64'|'quoted-printable'|string
---@param mode? 'text'|'binary'
---@return Ltn12Filter
function mime.encode(encoding, mode) end

---创建规范换行符转换过滤器。
---@param marker? string 新的行结束符，默认 CRLF。
---@return Ltn12Filter
function mime.normalize(marker) end

---创建点填充（SMTP dot-stuffing）过滤器。
---@return Ltn12Filter
function mime.stuff() end

---创建按 MIME 编码拆分长行的过滤器。
---@param mode? 'text'|'base64'|'quoted-printable'|string
---@param length? number 目标行长，默认 76。
---@return Ltn12Filter
function mime.wrap(mode, length) end

---Base64 编码低层函数。
---@param c string 当前输入块。
---@param d? string 可拼接的后续输入块。
---@return string? encoded 最大可安全编码的前缀。
---@return string? rest 尚未编码的剩余数据。
function mime.b64(c, d) end

---Base64 解码低层函数。
---@param c string 当前输入块。
---@param d? string 可拼接的后续输入块。
---@return string? decoded 最大可安全解码的前缀。
---@return string? rest 尚未解码的剩余数据。
function mime.unb64(c, d) end

---SMTP 点填充低层函数。
---@param m number 上一块的行尾上下文；消息开头通常为 2。
---@param b? string 当前输入块。
---@return string? stuffed 点填充后的数据。
---@return number context 新上下文。
function mime.dot(m, b) end

---统一换行符的低层过滤器。
---@param c number 上一次调用返回的上下文。
---@param d? string 当前输入块。
---@param marker? string 目标行结束符，默认 CRLF。
---@return string? converted 转换后的数据。
---@return number context 新上下文。
function mime.eol(c, d, marker) end

---Quoted-Printable 编码低层函数。
---@param c string 当前输入块。
---@param d? string 可拼接的后续输入块。
---@param marker? string CRLF 替换目标，默认 CRLF。
---@return string? encoded 最大可安全编码的前缀。
---@return string? rest 尚未编码的剩余数据。
function mime.qp(c, d, marker) end

---Quoted-Printable 解码低层函数。
---@param c string 当前输入块。
---@param d? string 可拼接的后续输入块。
---@return string? decoded 最大可安全解码的前缀。
---@return string? rest 尚未解码的剩余数据。
function mime.unqp(c, d) end

---按行长度切分 Quoted-Printable 文本的低层函数。
---@param n number 第一行剩余可用长度。
---@param b? string 当前输入块。
---@param length? number 行长度，默认 76。
---@return string? wrapped 切分后的数据。
---@return number remaining 最后一行剩余可用长度。
function mime.qpwrp(n, b, length) end

---按行长度切分普通文本的低层函数。
---@param n number 第一行剩余可用长度。
---@param b? string 当前输入块。
---@param length? number 行长度，默认 76。
---@return string? wrapped 切分后的数据。
---@return number remaining 最后一行剩余可用长度。
function mime.wrp(n, b, length) end

return mime
