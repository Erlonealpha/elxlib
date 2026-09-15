--[[@
    同步 WebSocket 服务端。

    服务端采用显式 accept/run 模型：调用方决定何时接受连接，连接处理函数
    在当前线程中直接运行。该模型不提供并发复用，也不依赖 copas、lua-ev。
]]

local socket = require("socket")
local connection = require("websocket.connection")
local handshake = require("websocket.handshake")
local tools = require("websocket.tools")

---@alias WebSocketHandler fun(client: WebSocketConnection): any

---@class WebSocketServerOptions
---@field port? number 监听端口，默认 80。
---@field interface? string 监听地址，默认 `*`。
---@field protocols? table<string, WebSocketHandler> 按子协议分派的处理函数。
---@field default? WebSocketHandler 没有匹配子协议时的处理函数。
---@field timeout? number 客户端 socket 的超时时间。
---@field on_error? fun(server: WebSocketServer, err: string, client: WebSocketConnection|nil)
---@field reuseaddr? boolean 是否启用 `reuseaddr`。

---@class WebSocketServer
---@field socket userdata LuaSocket 监听 socket。
---@field port number 实际监听端口。
---@field interface string
---@field protocols table<string, WebSocketHandler>
---@field default WebSocketHandler|nil
---@field timeout number|nil
---@field on_error fun(server: WebSocketServer, err: string, client: WebSocketConnection|nil)|nil
local Server = {}
Server.__index = Server

local function close_socket(sock)
    if sock then
        pcall(function()
            sock:close()
        end)
    end
end

local function read_upgrade_request(sock)
    local lines = {}
    while true do
        local line, err = sock:receive("*l")
        if not line then
            return nil, err or "读取 HTTP Upgrade 请求失败"
        end
        if #line > 8192 then
            return nil, "HTTP 请求行或请求头过长"
        end
        lines[#lines + 1] = line
        if line == "" then
            break
        end
        if #lines > 100 then
            return nil, "HTTP 请求头数量过多"
        end
    end
    return table.concat(lines, "\r\n")
end

function Server:_report_error(err, client)
    if self.on_error then
        pcall(self.on_error, self, err, client)
    end
end

--- 创建同步 WebSocket 服务端。
---@param options WebSocketServerOptions
---@return WebSocketServer|nil server
---@return string|nil err
function Server.listen(options)
    assert(options, "必须提供服务端配置")
    assert(options.protocols or options.default, "必须至少配置 protocols 或 default")

    local host = options.interface or "*"
    local port = options.port or 80
    local listener, err = socket.bind(host, port)
    if not listener then
        return nil, err
    end

    if options.reuseaddr ~= false then
        pcall(listener.setoption, listener, "reuseaddr", true)
    end

    local actual_host, actual_port = listener:getsockname()
    return setmetatable({
        socket = listener,
        interface = actual_host or host,
        port = actual_port or port,
        protocols = options.protocols or {},
        default = options.default,
        timeout = options.timeout,
        on_error = options.on_error,
    }, Server)
end

--- 接受一个客户端并完成 WebSocket 握手。
---@param self WebSocketServer
---@return WebSocketConnection|nil client
---@return string|nil protocol 实际选择的子协议。
---@return string|nil err
function Server:accept()
    if not self.socket then
        return nil, nil, "server is closed"
    end

    local client_socket, err = self.socket:accept()
    if not client_socket then
        return nil, nil, err
    end

    if self.timeout ~= nil then
        client_socket:settimeout(self.timeout)
    end
    client_socket:setoption("tcp-nodelay", true)

    local request, request_err = read_upgrade_request(client_socket)
    if not request then
        close_socket(client_socket)
        self:_report_error(request_err, nil)
        return nil, nil, request_err
    end

    local protocol_names = {}
    for protocol in pairs(self.protocols) do
        protocol_names[#protocol_names + 1] = protocol
    end
    table.sort(protocol_names)

    local response, protocol, headers_or_error = handshake.accept_upgrade(request, protocol_names)
    if not response then
        local message = tostring(headers_or_error or "无效的 WebSocket 握手")
        local body = "HTTP/1.1 400 Bad Request\r\nContent-Length: " .. #message .. "\r\nConnection: close\r\n\r\n" .. message
        pcall(client_socket.send, client_socket, body)
        close_socket(client_socket)
        self:_report_error(message, nil)
        return nil, nil, message
    end

    local send_position = 1
    while send_position <= #response do
        local last_index, send_err, partial = client_socket:send(response, send_position)
        if last_index then
            send_position = last_index + 1
        elseif partial then
            send_position = partial + 1
        else
            close_socket(client_socket)
            self:_report_error(send_err or "WebSocket 握手响应发送失败", nil)
            return nil, nil, send_err or "WebSocket 握手响应发送失败"
        end
    end

    local handler
    if protocol and self.protocols[protocol] then
        handler = self.protocols[protocol]
    else
        handler = self.default
    end
    if not handler then
        close_socket(client_socket)
        local message = "没有可用的 WebSocket 子协议处理器"
        self:_report_error(message, nil)
        return nil, nil, message
    end

    local client = connection.new({
        socket = client_socket,
        state = "OPEN",
        is_server = true,
        is_closing = false,
        protocol = protocol,
        timeout = self.timeout,
    })

    client.handler = handler
    client.server = self
    return client, protocol
end

--- 接受并依次处理客户端；处理器返回后继续监听下一个客户端。
---@param self WebSocketServer
---@return nil|string err 服务端停止时的错误。
function Server:run()
    while self.socket do
        local client, _, err = self:accept()
        if client then
            local ok, handler_error = xpcall(client.handler, debug.traceback, client)
            if not ok then
                self:_report_error(handler_error, client)
            end
            if client.state ~= "CLOSED" then
                client:close(1000, "")
            end
        elseif err then
            self:_report_error(err, nil)
            if not self.socket then
                break
            end
        end
    end
    return nil
end

--- 关闭监听 socket；可选地关闭当前连接。
---@param self WebSocketServer
function Server:close()
    if self.socket then
        close_socket(self.socket)
        self.socket = nil
    end
end

return Server
