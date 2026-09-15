---@meta

---@class LuaSocketSMTPMessage
---@field headers table<string, string|number> 消息头。
---@field body string|Ltn12Source|LuaSocketSMTPMessagePart[] 消息正文；表值表示 multipart。

---@class LuaSocketSMTPMessagePart: LuaSocketSMTPMessage
---@field preamble? string multipart 前导文本。
---@field epilogue? string multipart 尾部文本。

---@class LuaSocketSMTPRequest
---@field from string 发件人地址。
---@field rcpt string|string[] 收件人地址或地址列表。
---@field source Ltn12Source 邮件正文 source。
---@field user? string SMTP 用户名。
---@field password? string SMTP 密码。
---@field server? string SMTP 服务器，默认 localhost。
---@field port? number SMTP 端口，默认 25。
---@field domain? string HELO/EHLO 使用的域名。
---@field step? Ltn12Step LTN12 pump step。
---@field create? function 创建通信 socket 的工厂。

---@class SocketSMTP
local smtp = {}

---@field TIMEOUT number 默认 I/O 超时秒数。
---@field SERVER string 默认 SMTP 服务器。
---@field PORT number 默认 SMTP 端口。
---@field DOMAIN string HELO/EHLO 默认域名。
---@field ZONE string 默认时区。

---创建 SMTP 消息 source。
---@param mesgt LuaSocketSMTPMessage
---@return Ltn12Source
function smtp.message(mesgt) end

---发送 SMTP 邮件。
---@param request LuaSocketSMTPRequest
---@return number? result
---@return string? error
function smtp.send(request) end

---打开低层 SMTP 连接。
---@param server string
---@param port? number
---@param create? function
---@return table connection
function smtp.open(server, port, create) end

return smtp
