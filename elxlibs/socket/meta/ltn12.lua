---@meta

---@alias Ltn12Filter fun(chunk: string?): string?
---@alias Ltn12Source fun(): string?, string?
---@alias Ltn12Sink fun(chunk: string?, err?: string?): boolean|number|string, string?
---@alias Ltn12Step fun(source: Ltn12Source, sink: Ltn12Sink): boolean, string?

---@class Ltn12FilterNamespace
local filter = {}

---@param low fun(ctx:any, chunk:string?, extra?:any): string?, any
---@param ctx? any 初始上下文。
---@param extra? any 额外参数。
---@return Ltn12Filter
function filter.cycle(low, ctx, extra) end

---@param ... Ltn12Filter 要依次串联的过滤器。
---@return Ltn12Filter
function filter.chain(...) end

---@class Ltn12PumpNamespace
local pump = {}

---@param source Ltn12Source
---@param sink Ltn12Sink
---@param step? Ltn12Step
---@return boolean|number ok
---@return string? error
function pump.all(source, sink, step) end

---@param source Ltn12Source
---@param sink Ltn12Sink
---@return boolean|number ok
---@return string? error
function pump.step(source, sink) end

---@class Ltn12SinkNamespace
local sink = {}

---@param filter Ltn12Filter
---@param target Ltn12Sink
---@return Ltn12Sink
function sink.chain(filter, target) end

---@param message string
---@return Ltn12Sink
function sink.error(message) end

---@param handle LuaSocketFileHandle|nil
---@param message? string
---@return Ltn12Sink
function sink.file(handle, message) end

---@return Ltn12Sink
function sink.null() end

---@param target? table<string|number, string>
---@return Ltn12Sink
---@return table<string|number, string> chunks
function sink.table(target) end

---@param target Ltn12Sink
---@return Ltn12Sink
function sink.simplify(target) end

---@class Ltn12SourceNamespace
local source = {}

---@param ... Ltn12Source 要按顺序串联的 source。
---@return Ltn12Source
function source.cat(...) end

---@param source Ltn12Source
---@param filter Ltn12Filter
---@param ... Ltn12Filter 额外过滤器。
---@return Ltn12Source
function source.chain(source, filter, ...) end

---@return Ltn12Source
function source.empty() end

---@param message string
---@return Ltn12Source
function source.error(message) end

---@param handle LuaSocketFileHandle|nil
---@param message? string
---@return Ltn12Source
function source.file(handle, message) end

---@param source Ltn12Source
---@return Ltn12Source
function source.simplify(source) end

---@param value? string
---@return Ltn12Source
function source.string(value) end

---@param values string[]
---@return Ltn12Source
function source.table(values) end

---@param source Ltn12Source
---@return fun(chunk?: string): string?, string?
function source.rewind(source) end

---@class Ltn12
local ltn12 = {}
---@field BLOCKSIZE number 默认数据块大小，当前实现为 2048。
---@field _VERSION string 模块版本。
---@field filter Ltn12FilterNamespace
---@field pump Ltn12PumpNamespace
---@field sink Ltn12SinkNamespace
---@field source Ltn12SourceNamespace

ltn12.filter = filter
ltn12.pump = pump
ltn12.sink = sink
ltn12.source = source

return ltn12
