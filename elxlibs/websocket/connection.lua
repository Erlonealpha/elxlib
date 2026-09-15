--[[@
    同步 WebSocket 连接状态机。

    客户端和服务端共享这里的消息收发、分片、控制帧和关闭握手逻辑。
]]

local frame = require("websocket.frame")

---@class WebSocketConnection
---@field state "CLOSED"|"CONNECTING"|"OPEN"|"CLOSING"
---@field is_server boolean
---@field is_closing boolean
---@field protocol string|nil 已协商的子协议。
---@field socket userdata LuaSocket TCP/SSL socket。
---@field timeout number|nil socket 超时时间。
local Connection = {}
Connection.__index = Connection

---@param options table
---@return WebSocketConnection
function Connection.new(options)
    return setmetatable(options, Connection)
end

function Connection:_close_transport()
    if self.socket then
        pcall(function()
            self.socket:close()
        end)
        self.socket = nil
    end
end

function Connection:_send_all(data)
    local position = 1
    while position <= #data do
        local last_index, err, partial = self.socket:send(data, position)
        if last_index then
            position = last_index + 1
        elseif partial then
            position = partial + 1
        else
            return nil, err or "发送数据失败"
        end
    end
    return true
end

function Connection:_receive_exact(length)
    local chunks = {}
    local remaining = length
    while remaining > 0 do
        local chunk, err, partial = self.socket:receive(remaining)
        if chunk then
            chunks[#chunks + 1] = chunk
            remaining = remaining - #chunk
        elseif partial and #partial > 0 then
            chunks[#chunks + 1] = partial
            remaining = remaining - #partial
            if err ~= "timeout" then
                return nil, err or "接收数据失败"
            end
        else
            return nil, err or "连接已关闭"
        end
    end
    return table.concat(chunks)
end

function Connection:_receive_frame()
    local header, err = self:_receive_exact(2)
    if not header then
        return nil, err
    end

    local first = header:byte(1)
    local second = header:byte(2)
    local opcode = first % 16
    local fin = first >= 128
    local masked = second >= 128
    local length_code = second % 128
    local length_bytes = ""

    if length_code == 126 then
        length_bytes, err = self:_receive_exact(2)
        if not length_bytes then
            return nil, err
        end
    elseif length_code == 127 then
        length_bytes, err = self:_receive_exact(8)
        if not length_bytes then
            return nil, err
        end
    end

    local required_header = string.char(first, second) .. length_bytes
    local payload, _, decoded_opcode, rest, decoded_masked, protocol_error = frame.decode(required_header)
    if protocol_error then
        return nil, protocol_error
    end

    local payload_length
    if length_code < 126 then
        payload_length = length_code
    elseif length_code == 126 then
        local _, value = require("websocket.tools").read_int16(length_bytes, 1)
        payload_length = value
    else
        local _, high = require("websocket.tools").read_uint32(length_bytes, 1)
        local _, low = require("websocket.tools").read_uint32(length_bytes, 5)
        if high > 0x1fffff then
            return nil, "WebSocket 负载长度过大"
        end
        payload_length = high * 0x100000000 + low
    end

    local mask_key = ""
    if masked then
        mask_key, err = self:_receive_exact(4)
        if not mask_key then
            return nil, err
        end
    end

    local raw_payload = self:_receive_exact(payload_length)
    if not raw_payload then
        return nil, "WebSocket 负载接收失败"
    end

    local encoded = required_header .. mask_key .. raw_payload
    payload, _, decoded_opcode, _, decoded_masked, protocol_error = frame.decode(encoded)
    if protocol_error then
        return nil, protocol_error
    end
    if not payload then
        return nil, "WebSocket 帧解析失败"
    end

    return {
        payload = payload,
        fin = fin,
        opcode = decoded_opcode or opcode,
        masked = decoded_masked or masked,
    }
end

local function fail(self, reason)
    self.state = "CLOSED"
    self:_close_transport()
    if self.on_close then
        pcall(self.on_close, self, false, 1006, reason)
    end
    return nil, nil, false, 1006, reason
end

---@param self WebSocketConnection
---@return string|nil message
---@return integer|nil opcode
---@return boolean|nil clean
---@return integer|nil code
---@return string|nil reason
function Connection:receive()
    if self.state ~= "OPEN" and not self.is_closing then
        return fail(self, "wrong state")
    end

    local fragments
    local message_opcode
    while true do
        local current, err = self:_receive_frame()
        if not current then
            return fail(self, err)
        end

        local is_control = current.opcode >= 0x8
        if is_control then
            if not current.fin then
                return fail(self, "控制帧不能分片")
            end
            if self.is_server and not current.masked then
                return fail(self, "客户端发送的帧必须带掩码")
            end
            if not self.is_server and current.masked then
                return fail(self, "服务端发送的帧不应带掩码")
            end

            if current.opcode == frame.PING then
                local ok, send_error = self:_send_frame(current.payload, frame.PONG)
                if not ok then
                    return fail(self, send_error)
                end
            elseif current.opcode == frame.PONG then
                -- PONG 不是应用消息，继续读取下一个数据帧。
            elseif current.opcode == frame.CLOSE then
                local code, reason = frame.decode_close(current.payload)
                if code == nil and #current.payload == 1 then
                    return fail(self, reason)
                end
                if not self.is_closing then
                    local response = frame.encode_close(code, reason)
                    local ok = self:_send_raw(response, frame.CLOSE)
                    self.state = "CLOSED"
                    self:_close_transport()
                    if self.on_close then
                        pcall(self.on_close, self, true, code or 1005, reason or "")
                    end
                    return nil, nil, ok == true, code or 1005, reason or ""
                end
                return current.payload, frame.CLOSE
            end
        else
            if self.is_server and not current.masked then
                return fail(self, "客户端发送的帧必须带掩码")
            end
            if not self.is_server and current.masked then
                return fail(self, "服务端发送的帧不应带掩码")
            end

            if current.opcode == frame.CONTINUATION then
                if not fragments then
                    return fail(self, "收到意外的 CONTINUATION 帧")
                end
                fragments[#fragments + 1] = current.payload
            elseif current.opcode == frame.TEXT or current.opcode == frame.BINARY then
                if fragments then
                    return fail(self, "在消息分片结束前收到新的数据帧")
                end
                message_opcode = current.opcode
                if current.fin then
                    return current.payload, current.opcode
                end
                fragments = { current.payload }
            else
                return fail(self, "无效的数据帧操作码")
            end

            if current.fin and fragments then
                return table.concat(fragments), message_opcode
            end
        end
    end
end

function Connection:_send_raw(data, opcode)
    local encoded = frame.encode(data, opcode, not self.is_server, true)
    return self:_send_all(encoded)
end

function Connection:_send_frame(data, opcode)
    if self.state ~= "OPEN" then
        return nil, "wrong state"
    end
    return self:_send_raw(data, opcode)
end

---@param data string 消息内容。
---@param opcode? integer `TEXT` 或 `BINARY`。
---@return boolean|nil ok
---@return boolean|nil clean
---@return integer|nil code
---@return string|nil reason
function Connection:send(data, opcode)
    if self.state ~= "OPEN" then
        return nil, false, 1006, "wrong state"
    end
    if opcode ~= nil and opcode ~= frame.TEXT and opcode ~= frame.BINARY then
        return nil, false, 1002, "send 只允许 TEXT 或 BINARY 操作码"
    end
    local ok, err = self:_send_frame(data, opcode or frame.TEXT)
    if not ok then
        local clean, code, reason = self:close(1006, err)
        return nil, clean, code, reason
    end
    return true
end

---@param code? integer 关闭码，默认为 1000。
---@param reason? string 关闭原因。
---@return boolean clean
---@return integer code
---@return string reason
function Connection:close(code, reason)
    if self.state == "CLOSED" then
        return false, 1006, "wrong state"
    end
    if self.state ~= "OPEN" and not self.is_closing then
        return false, 1006, "wrong state"
    end

    code = code or 1000
    reason = reason or ""
    self.is_closing = true
    self.state = "CLOSING"

    local encoded = frame.encode_close(code, reason)
    local ok, err = self:_send_raw(encoded, frame.CLOSE)
    if not ok then
        self.state = "CLOSED"
        self:_close_transport()
        return false, 1006, err or "发送关闭帧失败"
    end

    local message, opcode, clean_code, close_code, close_reason = self:receive()
    if message and opcode == frame.CLOSE then
        self.state = "CLOSED"
        self:_close_transport()
        return true, frame.decode_close(message)
    end

    self.state = "CLOSED"
    self:_close_transport()
    return clean_code == true, close_code or 1005, close_reason or ""
end

return Connection
