---@meta

---@alias LuaSocketDNSFamily 'inet'|'inet6'

---@class LuaSocketDNSAddressInfo
---@field family LuaSocketDNSFamily 地址族。
---@field addr string 地址。

---@class LuaSocketDNSResolved4
---@field name string 规范主机名。
---@field alias string[] 别名列表。
---@field ip string[] IPv4 地址列表。

---@class LuaSocketDNSResolved6
---@field [number] LuaSocketDNSAddressInfo

---@class SocketDNS
local dns = {}

---执行支持 IPv4/IPv6 的通用名称解析。
---@param address string IP 地址或主机名。
---@return LuaSocketDNSResolved6? result 解析器返回的全部地址信息。
---@return string? error 错误信息。
function dns.getaddrinfo(address) end

---获取本机标准主机名。
---@return string hostname
function dns.gethostname() end

---将 IPv4 地址或主机名解析为规范主机名。
---@param address string IP 地址或主机名。
---@return string? hostname 规范主机名。
---@return LuaSocketDNSResolved4? info 解析器返回的详细信息。
---@return string? error 错误信息。
function dns.tohostname(address) end

---将主机名解析为第一个 IPv4 地址。
---@param address string IP 地址或主机名。
---@return string? ip 第一个 IPv4 地址。
---@return LuaSocketDNSResolved4? info 解析器返回的详细信息。
---@return string? error 错误信息。
function dns.toip(address) end

return dns
