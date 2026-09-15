---@meta

---@class LuaSocketHTTPResponseHeaders: table<string, string|number>

---@class LuaSocketHTTPRequest
---@field url string 请求 URL。
---@field sink? LuaSocketSink 响应体接收 sink；缺省时丢弃响应体。
---@field method? string HTTP 方法，默认 GET。
---@field headers? table<string, string|number> 请求头。
---@field source? LuaSocketSource 请求体 source。
---@field step? LuaSocketStep LTN12 pump step 函数。
---@field proxy? string 代理 URL。
---@field redirect? boolean 是否自动跟随 301/302；默认启用。
---@field create? function 创建通信 socket 的工厂。
---@field maxredirects? number|false 最大重定向次数；false 表示无限制。

---@class SocketHTTP
local http = {}

---@field PROXY string? 默认代理。
---@field TIMEOUT number 全部 I/O 操作默认超时秒数，默认 60。
---@field USERAGENT string 默认 User-Agent。

---以字符串形式执行 HTTP GET/POST 请求，或使用 LTN12 执行通用请求。
---@overload fun(url:string, body?:string): body:string?, code:number?, headers:LuaSocketHTTPResponseHeaders?, status:string?
---@param request LuaSocketHTTPRequest 请求描述表。
---@return number? result 成功时为 1。
---@return number|string? code HTTP 状态码或错误信息。
---@return LuaSocketHTTPResponseHeaders? headers 响应头。
---@return string? status 状态行。
function http.request(request) end

---@param host string 目标主机。
---@param port number 目标端口。
---@param create? function socket 创建函数。
---@return table connection 低层 HTTP 连接对象。
function http.open(host, port, create) end

return http
