--[[@
    HTTP/1.1 WebSocket 握手处理。
]]

local tools = require("websocket.tools")

local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
local M = {}

local function header_map(request)
    local headers = {}
    local first_line, rest = request:match("^([^\r\n]+)\r\n(.*)$")
    if not first_line then
        return nil, "无效的 HTTP 请求"
    end

    for line in rest:gmatch("([^\r\n]*)\r\n") do
        if line == "" then
            break
        end
        local name, value = line:match("^([^:]+):%s*(.*)$")
        if not name then
            return nil, "无效的 HTTP 请求头: " .. line
        end
        name = name:lower()
        value = tools.trim(value)
        if headers[name] then
            headers[name] = headers[name] .. "," .. value
        else
            headers[name] = value
        end
    end
    return headers, first_line
end

---@alias WebSocketHandshakeRequest {
---     key: string,
---     host: string,
---     port: int,
---     protocols: string[],
---     uri: string,
---     origin: string,
--- }

--- 生成客户端升级请求。
---@param request WebSocketHandshakeRequest
---@return string
function M.upgrade_request(request)
    local lines = {
        string.format("GET %s HTTP/1.1", request.uri),
        string.format("Host: %s", request.host),
        "Upgrade: websocket",
        "Connection: Upgrade",
        string.format("Sec-WebSocket-Key: %s", request.key),
        string.format("Sec-WebSocket-Version: 13"),
    }
    if request.protocols and #request.protocols > 0 then
        lines[#lines + 1] = "Sec-WebSocket-Protocol: " .. table.concat(request.protocols, ", ")
    end
    if request.origin then
        lines[#lines + 1] = "Origin: " .. request.origin
    end
    table.insert(lines, "")
    return table.concat(lines, "\r\n") .. "\r\n"
end

--- 计算 Sec-WebSocket-Accept。
---@param key string 客户端 Sec-WebSocket-Key。
---@return string
function M.sec_websocket_accept(key)
    return tools.base64.encode(tools.sha1(key .. GUID))
end

--- 解析 HTTP 头。
---@param request string
---@return table<string, string>? headers
---@return string? first_line
---@return string? err
function M.http_headers(request)
    return header_map(request)
end

--- 校验服务端升级请求并生成 101 响应。
---@param request string HTTP 请求。
---@param protocols string[] 支持的子协议列表。
---@return string? response
---@return string? protocol
---@return table<string, string>|string headers_or_error
function M.accept_upgrade(request, protocols)
    local headers, first_line_or_error = header_map(request)
    if not headers then
        return nil, nil, first_line_or_error
    end

    if not first_line_or_error:match("^GET%s+[^%s]+%s+HTTP/1%.1$") then
        return nil, nil, "只接受 HTTP/1.1 GET WebSocket 请求"
    end
    if (headers.upgrade or ""):lower() ~= "websocket"
        or not tools.has_token(headers.connection or "", "upgrade")
        or not headers["sec-websocket-key"]
        or headers["sec-websocket-version"] ~= "13" then
        return nil, nil, "无效的 WebSocket 握手请求"
    end

    local protocol
    local requested = headers["sec-websocket-protocol"]
    if requested then
        for value in requested:gmatch("([^,]+)") do
            value = tools.trim(value)
            for _, supported in ipairs(protocols) do
                if value == supported then
                    protocol = value
                    break
                end
            end
            if protocol then
                break
            end
        end
    end

    local response = {
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Accept: " .. M.sec_websocket_accept(headers["sec-websocket-key"]),
    }
    if protocol then
        response[#response + 1] = "Sec-WebSocket-Protocol: " .. protocol
    end
    response[#response + 1] = ""
    return table.concat(response, "\r\n") .. "\r\n", protocol, headers
end

return {
    upgrade_request = M.upgrade_request,
    sec_websocket_accept = M.sec_websocket_accept,
    http_headers = M.http_headers,
    accept_upgrade = M.accept_upgrade,
}
