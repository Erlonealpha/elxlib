--[[@
    WebSocket 客户端入口。

    仅保留同步客户端实现；`new` 为 `sync` 的兼容别名。
]]

local sync = require("websocket.client_sync")

return {
    sync = sync,
    new = sync,
}
