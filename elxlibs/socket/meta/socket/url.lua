---@meta

---@class SocketURL
local url = {}

---@field _VERSION string URL 模块版本。

---从基础 URL 和相对 URL 构造绝对 URL。
---@param base string|LuaSocketParsedURL 基础 URL。
---@param relative string 相对 URL。
---@return string absolute
function url.absolute(base, relative) end

---根据 URL 组成部分重建 URL。
---@param parsed LuaSocketParsedURL
---@return string built
function url.build(parsed) end

---根据 segment 列表构造 path。
---@param segments string[] path segment 列表。
---@param unsafe? any 非 nil 时不转义保留字符。
---@return string path
function url.build_path(segments, unsafe) end

---识别主机字符串的类型。
---@param host string 原始主机字符串。
---@return 'name'|'ipv4'|'ipv6' hosttype
---@return string host 去除 IPv6 方括号后的主机字符串。
function url.classify_host(host) end

---对 URL 内容执行百分号转义。
---@param content string
---@return string escaped
function url.escape(content) end

---将 URL 字符串解析为组成部分。
---@param value string URL。
---@param default? LuaSocketParsedURL 默认字段表；仅覆盖 URL 中实际存在的字段。
---@return LuaSocketParsedURL? parsed
function url.parse(value, default) end

---将 path 拆分为 segment 列表并去除转义。
---@param path string
---@return string[] segments
function url.parse_path(path) end

---移除 URL 百分号转义。
---@param content string
---@return string unescaped
function url.unescape(content) end

return url
