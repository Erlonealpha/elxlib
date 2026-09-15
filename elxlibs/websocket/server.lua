--[[@
    WebSocket 服务端入口。

    仅保留同步服务端；`new` 和 `listen` 都指向同步实现。
]]

local sync = require("websocket.server_sync")

return {
    sync = sync,
    new = sync,
    listen = sync.listen,
}
