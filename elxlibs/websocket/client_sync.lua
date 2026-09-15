--[[@
    同步 WebSocket 客户端。

    所有网络操作均为阻塞调用，不依赖 copas、lua-ev 或协程调度器。
]]

local std = require 'elxlibs.std'
local socket = require 'socket'
local ssl = nil
local connection = require 'websocket.connection'
local handshake = require 'websocket.handshake'
local tools = require 'websocket.tools'

---@class WebSocketClientOptions
---@field timeout number? TCP 连接及 I/O 超时时间（秒）。
---@field ssl table? LuaSec `ssl.wrap` 参数。
---@field origin string? 可选 Origin 请求头。

---@class WebSocketClient : WebSocketConnection
---@field timeout number?
---@field ssl table?
---@field origin string?
---@overload fun(options?: WebSocketClientOptions):self
local Client = std.class.new('WebSocketClient', {connection})

---@param options? WebSocketClientOptions
function Client:__init(options)
    options = options or {}
    self.state = "CLOSED"
    self.is_server = false
    self.is_closing = false
    self.timeout = options.timeout
    self.ssl = options.ssl
    self.origin = options.origin
    self.socket = nil
end

local function socket_error(client, err)
    if client.socket then
        pcall(function()
            client.socket:close()
        end)
        client.socket = nil
    end
    client.state = "CLOSED"
    return nil, err
end

local function read_http_response(client)
    local lines = {}
    while true do
        local line, err = client.socket:receive("*l")
        if not line then
            return nil, err or "读取 WebSocket 握手响应失败"
        end
        lines[#lines + 1] = line
        if line == "" then
            break
        end
    end
    return table.concat(lines, "\r\n")
end

--- 连接 WebSocket 服务端并完成 HTTP Upgrade 握手。
---@param url string `ws://` 或 `wss://` URL。
---@param protocol? string|string[] 希望使用的子协议；数组用于声明多个候选协议。
---@param ssl_params? table LuaSec `ssl.wrap` 参数，覆盖构造器中的配置。
---@return true ok
---@return string? protocol 实际协商的子协议。
---@return table<string, string>? headers 服务端响应头。
---@return string? err 失败原因。
---@return_overload false, string
function Client:connect(url, protocol, ssl_params)
    if self.state ~= "CLOSED" then
        return false, "wrong state"
    end

    local scheme, host, port, uri = tools.parse_url(url)
    if not scheme then
        return false, host
    end

    local tcp = socket.tcp()
    if not tcp then
        return false, "无法创建 TCP socket"
    end
    self.socket = tcp

    if self.timeout ~= nil then
        tcp:settimeout(self.timeout)
    end
    tcp:setoption("tcp-nodelay", true)

    local ok, err = tcp:connect(host, port)
    if not ok then
        return socket_error(self, err)
    end

    if scheme == "wss" then
        ssl = ssl or require("ssl")
        local params = ssl_params or self.ssl or {}
        params.mode = params.mode or "client"
        params.protocol = params.protocol or "tlsv1.2"
        params.verify = params.verify or "none"
        params.options = params.options or "all"
        local wrapped, wrap_err = ssl.wrap(tcp, params)
        if not wrapped then
            return socket_error(self, wrap_err)
        end
        self.socket = wrapped
        local handshake_ok, handshake_err = self.socket:dohandshake()
        if not handshake_ok then
            return socket_error(self, handshake_err)
        end
    end

    local protocols
    if type(protocol) == "string" then
        protocols = { protocol }
    elseif type(protocol) == "table" then
        protocols = protocol
    else
        protocols = {}
    end

    local key = tools.generate_key()
    local request = handshake.upgrade_request({
        key = key,
        host = host,
        port = port,
        protocols = protocols,
        uri = uri,
        origin = self.origin,
    })

    local sent, send_err = self:_send_all(request)
    if not sent then
        return socket_error(self, send_err or "WebSocket 握手请求发送失败")
    end

    local response, response_err = read_http_response(self)
    if not response then
        return socket_error(self, response_err)
    end

    local headers, first_line = handshake.http_headers(response)
    if not headers then
        return socket_error(self, first_line)
    end
    if not first_line:match("^HTTP/1%.1%s+101") then
        return socket_error(self, "WebSocket 握手失败: 服务端没有返回 101")
    end

    if (headers.upgrade or ""):lower() ~= "websocket"
        or not tools.has_token(headers.connection or "", "upgrade") then
        return socket_error(self, "WebSocket 握手失败: 无效的 Upgrade/Connection 响应")
    end

    local expected = handshake.sec_websocket_accept(key)
    if headers["sec-websocket-accept"] ~= expected then
        return socket_error(
            self,
            string.format(
                "WebSocket 握手失败: Sec-WebSocket-Accept 不匹配（期望 %s，得到 %s）",
                expected,
                headers["sec-websocket-accept"] or "nil"
            )
        )
    end

    local negotiated_protocol = headers["sec-websocket-protocol"]
    if negotiated_protocol and #protocols > 0 then
        local found = false
        for _, requested in ipairs(protocols) do
            if requested == negotiated_protocol then
                found = true
                break
            end
        end
        if not found then
            return socket_error(self, "WebSocket 握手失败: 服务端返回了未请求的子协议")
        end
    end

    self.protocol = negotiated_protocol
    self.state = "OPEN"
    self.is_closing = false
    return true, self.protocol, headers
end

return Client.new
