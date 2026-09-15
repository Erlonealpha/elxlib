---@meta

---@class LuaSocketFTPRequest
---@field host string FTP 服务器主机。
---@field sink LuaSocketSink 下载数据的 sink。
---@field source? LuaSocketSource 上传数据的 source。
---@field argument? string 传给 FTP 命令的资源参数；优先于 path。
---@field path? string 资源路径。
---@field user? string 用户名，默认 ftp。
---@field password? string 密码，默认 anonymous@anonymous.org。
---@field command? string FTP 命令；get 默认 retr，put 默认 stor。
---@field port? number 控制连接端口，默认 21。
---@field type? LuaSocketTransferType 传输类型：a 或 i。
---@field step? LuaSocketStep LTN12 pump step。
---@field create? function 创建通信 socket 的工厂。

---@class SocketFTP
local ftp = {}

---@field TIMEOUT number I/O 超时秒数，默认 60。
---@field USER string 默认匿名用户名。
---@field PASSWORD string 默认匿名密码。

---打开低层 FTP 控制连接。
---@param server string 服务器地址。
---@param port? number 控制连接端口。
---@param create? function socket 创建函数。
---@return table connection 低层 FTP 连接对象。
function ftp.open(server, port, create) end

---生成可用于 FTP 高层请求的参数表。
---@param url string FTP URL。
---@return table request
function ftp.genericform(url) end

---下载 FTP URL 内容。
---@overload fun(url:string): string?, string?
---@param request LuaSocketFTPRequest
---@return number|string? result 成功时通常为 1，或成功读取的字节数相关结果。
---@return string? error 错误信息。
function ftp.get(request) end

---上传字符串到 FTP URL，或执行通用上传。
---@overload fun(url:string, body:string): number?, string?
---@param request LuaSocketFTPRequest
---@return number? sent 发送的字节数。
---@return string? error 错误信息。
function ftp.put(request) end

---执行低层 FTP 命令。
---@class LuaSocketFTPCommandRequest
---@field host string 服务器地址。
---@field command string|string[] FTP 命令或命令列表。
---@field argument? string|string[] 命令参数。
---@field check? string|number|string[] 与 command 对应的期望响应码。
---@field user? string 用户名。
---@field password? string 密码。
---@field port? number 控制连接端口。
---@field create? function socket 创建函数。

---@param request LuaSocketFTPCommandRequest
---@return number? result
---@return string? error
function ftp.command(request) end

return ftp
