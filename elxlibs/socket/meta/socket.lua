---@meta

-- LuaSocket 的 EmmyLua 元数据。
-- 仅提供 LSP 类型信息，不包含任何运行时实现。
-- 说明文字使用中文；接口名称、参数名称以及模块层级保持 LuaSocket 原始 API。

---@alias LuaSocketResult number|true
---@alias LuaSocketFamily 'inet'|'inet6'
---@alias LuaSocketTimeoutMode 'b'|'t'
---@alias LuaSocketTCPPattern '*a'|'*l'|number
---@alias LuaSocketTransferType 'a'|'i'
---@alias LuaSocketHeaderValue string|number
---@alias LuaSocketHeaders table<string, LuaSocketHeaderValue>
---@alias LuaSocketFilter fun(chunk: string?): string?
---@alias LuaSocketSource fun(): string?, string?
---@alias LuaSocketSink fun(chunk: string?, err?: string?): LuaSocketResult, string?
---@alias LuaSocketStep fun(source: LuaSocketSource, sink: LuaSocketSink): boolean, string?

---@class LuaSocketFileHandle
---@field read fun(self: LuaSocketFileHandle, ...): any
---@field write fun(self: LuaSocketFileHandle, ...): any
---@field close fun(self: LuaSocketFileHandle): boolean?, string?

---@class LuaSocketAddressInfo
---@field family LuaSocketFamily 地址族。
---@field addr string 地址。

---@class LuaSocketDNSResult
---@field name string 规范主机名。
---@field alias string[] 别名列表。
---@field ip string[] IPv4 地址列表。

---@class LuaSocketDNSResult6
---@field [number] LuaSocketAddressInfo

---@class LuaSocketParsedURL
---@field url string? 原始 URL。
---@field scheme string? 协议方案。
---@field authority string? authority 部分。
---@field path string? 路径。
---@field params string? 参数部分。
---@field query string? 查询字符串。
---@field fragment string? 片段。
---@field userinfo string? 用户信息。
---@field host string? 主机原文。
---@field hosttype ('name'|'ipv4'|'ipv6')? 主机类型。
---@field hostname string? 主机名。
---@field ipv4 string? IPv4 地址。
---@field ipv6 string? IPv6 地址。
---@field port string|number? 端口。
---@field user string? 用户名。
---@field password string? 密码。

---@class LuaSocketLingerOption
---@field on boolean 是否启用 linger。
---@field timeout number 关闭时最多等待的秒数。

---@class LuaSocketMulticastMembership
---@field multiaddr string 多播地址。
---@field interface number|string? 接口索引或相关接口标识。

---@class LuaSocketTCP
local TCP = {}

---关闭 TCP socket。
---@return LuaSocketResult? result
function TCP:close() end

---检查接收缓冲区中是否已有数据。
---@return boolean dirty
function TCP:dirty() end

---获取底层 socket 描述符或句柄。
---@return number fd
function TCP:getfd() end

---获取 TCP socket 选项。
---@param option string 选项名。
---@return any value
---@return string? error
function TCP:getoption(option) end

---获取对端地址信息。
---@return string? address IP 地址。
---@return number? port 端口。
---@return LuaSocketFamily? family 地址族。
function TCP:getpeername() end

---获取本地地址信息。
---@return string? address IP 地址。
---@return number? port 端口。
---@return LuaSocketFamily? family 地址族。
function TCP:getsockname() end

---获取 socket 流量统计信息。
---@return number received 已接收字节数。
---@return number sent 已发送字节数。
---@return number age socket 年龄（秒）。
function TCP:getstats() end

---获取当前 block timeout 与 total timeout。
---@return number block_timeout
---@return number total_timeout
function TCP:gettimeout() end

---设置底层 socket 描述符或句柄。
---@param fd number
function TCP:setfd(fd) end

---读取 TCP socket 选项。
---@param option string 选项名。
---@param value? any 选项值。
---@return LuaSocketResult? result
---@return string? error
function TCP:setoption(option, value) end

---重置 socket 的流量统计信息。
---@param received number 新的已接收字节数。
---@param sent number 新的已发送字节数。
---@param age number 新的年龄（秒）。
---@return LuaSocketResult? result
function TCP:setstats(received, sent, age) end

---设置 I/O 超时。
---@param value? number 秒数；nil 或负数表示无限等待。
---@param mode? LuaSocketTimeoutMode 'b' 表示 block，'t' 表示 total。
---@return LuaSocketResult? result
---@return string? error
function TCP:settimeout(value, mode) end

---@class LuaSocketTCPMaster: LuaSocketTCP
---@class LuaSocketTCPClient: LuaSocketTCP
---@class LuaSocketTCPServer: LuaSocketTCP

---将 master socket 绑定到本地地址。
---@param address string 本地地址或主机名。
---@param port number 本地端口；0 表示自动分配临时端口。
---@return LuaSocketResult? result
---@return string? error
function TCP:bind(address, port) end

---将 master socket 转换为 server socket。
---@param backlog number 连接等待队列长度。
---@return LuaSocketResult? result
---@return string? error
function TCP:listen(backlog) end

---等待服务器上的客户端连接。
---@return LuaSocketTCPClient? client
---@return string? error
function TCP:accept() end

---连接远端服务器并将 master socket 转换为 client socket。
---@param address string 远端地址或主机名。
---@param port number 远端端口。
---@return LuaSocketResult? result
---@return string? error
function TCP:connect(address, port) end

---按指定模式从 TCP client 读取数据。
---@param pattern? LuaSocketTCPPattern '*a'、'*l' 或要读取的字节数。
---@param prefix? string 拼接到返回数据前的前缀。
---@param maxsize? number 限制本次最多累积的 payload 长度。
---@return string? data
---@return string? error
---@return string? partial 已经读取的部分数据。
function TCP:receive(pattern, prefix, maxsize) end

---向 TCP client 发送数据。
---@param data string 要发送的数据。
---@param i? number 起始索引。
---@param j? number 结束索引。
---@return number? last_index 最后发送的索引。
---@return string? error
---@return number? partial_index 出错前最后发送的索引。
function TCP:send(data, i, j) end

---关闭全双工连接的一部分。
---@param mode? 'both'|'send'|'receive' 默认 both。
---@return LuaSocketResult result
function TCP:shutdown(mode) end

---@class LuaSocketUDP
local UDP = {}

---关闭 UDP socket。
---@return LuaSocketResult? result
function UDP:close() end

---获取 UDP socket 选项。
---@param option string 选项名。
---@return any value
---@return string? error
function UDP:getoption(option) end

---获取连接 UDP 对象的对端信息。
---@return string? address IP 地址。
---@return number? port 端口。
---@return LuaSocketFamily? family 地址族。
function UDP:getpeername() end

---获取本地地址信息。
---@return string? address IP 地址。
---@return number? port 端口。
---@return LuaSocketFamily? family 地址族。
function UDP:getsockname() end

---获取当前 UDP 超时。
---@return number timeout
function UDP:gettimeout() end

---接收一个 UDP 数据报。
---@param size? number 最大数据报长度；默认使用 socket._DATAGRAMSIZE。
---@return string? datagram
---@return string? error
function UDP:receive(size) end

---接收一个 UDP 数据报，同时返回发送方地址和端口。
---@param size? number 最大数据报长度。
---@return string? datagram
---@return string? error
---@return string? ip 发送方 IP。
---@return number? port 发送方端口。
function UDP:receivefrom(size) end

---向连接的 UDP 对端发送数据报。
---@param datagram string
---@return LuaSocketResult? result
---@return string? error
function UDP:send(datagram) end

---向指定 IP 和端口发送数据报。
---@param datagram string
---@param ip string 目标 IP；不接受主机名。
---@param port number 目标端口。
---@return LuaSocketResult? result
---@return string? error
function UDP:sendto(datagram, ip, port) end

---设置 UDP socket 选项。
---@param option string 选项名。
---@param value? any 选项值。
---@return LuaSocketResult? result
---@return string? error
function UDP:setoption(option, value) end

---改变 UDP 对象的对端；对连接对象传 '*' 可解除连接。
---@param address string
---@param port? number
---@return LuaSocketResult? result
---@return string? error
function UDP:setpeername(address, port) end

---绑定 UDP 对象到本地地址。
---@param address string 本地地址。
---@param port number 本地端口；0 表示自动分配临时端口。
---@return LuaSocketResult? result
---@return string? error
function UDP:setsockname(address, port) end

---设置 UDP 接收超时。
---@param value? number 秒数；nil 或负数表示无限等待。
---@return LuaSocketResult? result
---@return string? error
function UDP:settimeout(value) end

---@class LuaSocketUDPConnected: LuaSocketUDP
---@class LuaSocketUDPUnconnected: LuaSocketUDP

---@alias LuaSocketObject LuaSocketTCP|LuaSocketUDP

---@class LuaSocket
local socket = {}

---@field _VERSION string LuaSocket 版本字符串。
---@field _DEBUG boolean 是否启用调试模式。
---@field _DATAGRAMSIZE number UDP 默认数据报大小。
---@field _SETSIZE number socket 集合容量。
---@field _SOCKETINVALID number 无效 socket 的操作系统值。
---@field BLOCKSIZE number socket source/sink 使用的默认块大小。
---@field dns SocketDNS
---@field headers SocketHeaders
---@field sourcet table<string, function>
---@field sinkt table<string, function>

---创建 TCP 服务器 socket 的快捷方式。
---@param address string 本地地址。
---@param port number 本地端口。
---@param backlog? number listen backlog，默认 32。
---@return LuaSocketTCPServer? server
---@return string? error
function socket.bind(address, port, backlog) end

---创建并连接 TCP 客户端 socket。
---@param address string 远端地址。
---@param port number 远端端口。
---@param locaddr? string 本地绑定地址。
---@param locport? number 本地绑定端口。
---@param family? LuaSocketFamily 地址族。
---@return LuaSocketTCPClient? client
---@return string? error
function socket.connect(address, port, locaddr, locport, family) end

---创建并连接 IPv4 TCP 客户端 socket。
---@param address string 远端地址。
---@param port number 远端端口。
---@param locaddr? string 本地绑定地址。
---@param locport? number 本地绑定端口。
---@return LuaSocketTCPClient? client
---@return string? error
function socket.connect4(address, port, locaddr, locport) end

---创建并连接 IPv6 TCP 客户端 socket。
---@param address string 远端地址。
---@param port number 远端端口。
---@param locaddr? string 本地绑定地址。
---@param locport? number 本地绑定端口。
---@return LuaSocketTCPClient? client
---@return string? error
function socket.connect6(address, port, locaddr, locport) end

---创建 TCP master socket。
---@return LuaSocketTCPMaster socket
function socket.tcp() end

---创建 IPv4 TCP master socket。
---@return LuaSocketTCPMaster socket
function socket.tcp4() end

---创建 IPv6 TCP master socket。
---@return LuaSocketTCPMaster socket
function socket.tcp6() end

---创建未连接 UDP socket。
---@return LuaSocketUDPUnconnected socket
function socket.udp() end

---创建 IPv4 UDP socket。
---@return LuaSocketUDPUnconnected socket
function socket.udp4() end

---创建 IPv6 UDP socket。
---@return LuaSocketUDPUnconnected socket
function socket.udp6() end

---等待多个 socket 的状态发生变化。
---@param recvt LuaSocketObject[]|nil 等待读取的 socket 数组。
---@param sendt LuaSocketObject[]|nil 等待可写的 socket 数组。
---@param timeout? number 等待秒数；nil 或负数表示无限等待。
---@return LuaSocketObject[] readable 已就绪的读 socket。
---@return LuaSocketObject[] writable 已就绪的写 socket。
---@return string? error
function socket.select(recvt, sendt, timeout) end

---暂停当前程序指定秒数。
---@param time number 秒数。
function socket.sleep(time) end

---获取当前高精度时间。
---@return number seconds 时间戳。
function socket.gettime() end

---将抛出 LuaSocket 异常的函数包装成安全函数。
---@generic F: function
---@param func F
---@return F protected
function socket.protect(func) end

---创建 LuaSocket 的 finalized exception 处理函数。
---@param finalizer? fun() 发生异常时执行的清理函数。
---@return fun(first: any, ...: any): any, ...
function socket.newtry(finalizer) end

---第一个返回值为假时抛出 LuaSocket 异常。
---@generic T
---@param first T
---@param ... any
---@return T, ...
function socket.try(first, ...) end

---丢弃前 d 个返回值，返回剩余值。
---@param d number 丢弃的返回值数量。
---@param ... any 原始返回值。
---@return any ...
function socket.skip(d, ...) end

---根据模式将 stream socket 包装成 LTN12 source。
---@param mode 'default'|'by-length'|'until-closed'|'http-chunked'
---@param sock LuaSocketTCP
---@param length? number by-length 模式的长度。
---@return LuaSocketSource source
function socket.source(mode, sock, length) end

---根据模式将 stream socket 包装成 LTN12 sink。
---@param mode 'default'|'http-chunked'|'close-when-done'|'keep-open'
---@param sock LuaSocketTCP
---@return LuaSocketSink sink
function socket.sink(mode, sock) end

return socket
