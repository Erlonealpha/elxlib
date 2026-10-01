---@meta

---@class cjson
---Lua CJSON 模块，提供 JSON 编解码支持。
---加载方式：`local cjson = require("cjson")`
---安全版本：`local cjson_safe = require("cjson.safe")`
---所有函数均支持 `cjson` 和 `cjson.safe` 两个模块。
local cjson = {}

---Lua CJSON 模块名称（"cjson"）。
---@type string
cjson._NAME = "cjson"

---Lua CJSON 模块版本号（"2.1.0"）。
---@type string
cjson._VERSION = "2.1.0"

---JSON null 值对应的 lightuserdata NULL 指针，用于与 cjson.decode 返回的 null 值比较。
---@type lightuserdata
cjson.null = nil

---将 Lua 值序列化为 JSON 字符串。
---支持的 Lua 类型：boolean、lightuserdata（仅 NULL）、nil、number、string、table。
---其余类型（function、thread、userdata、非 NULL 的 lightuserdata）将产生错误。
---默认数字以 14 位有效数字编码。
---@param value any 待编码的 Lua 值
---@return string json_text JSON 格式字符串
function cjson.encode(value) end

---将 JSON 字符串反序列化为 Lua 值或表。
---支持 UTF-8 编码的 JSON，不支持 UTF-16 和 UTF-32。
---JSON null 会被转换为 NULL lightuserdata 值，可通过 cjson.null 比较。
---@param json_text string JSON 格式字符串
---@return any value 反序列化后的 Lua 值或表
function cjson.decode(json_text) end

---获取或设置无效数字（infinity、NaN、十六进制）的解码行为。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param setting? boolean 是否允许解码无效数字，默认为 true
---@return boolean setting 当前（或更新后的）设置值
function cjson.decode_invalid_numbers(setting) end

---获取或设置无效数字（infinity、NaN）的编码行为。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param setting? boolean|"null" 编码设置：true 允许编码、false 抛出错误（默认）、"null" 编码为 JSON null
---@return boolean|"null" setting 当前（或更新后的）设置值
function cjson.encode_invalid_numbers(setting) end

---获取或设置是否保留编码缓冲区以提升性能。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param keep? boolean true 保留缓冲区（默认），false 每次编码后释放缓冲区
---@return boolean keep 当前（或更新后的）设置值
function cjson.encode_keep_buffer(keep) end

---获取或设置编码时允许的最大嵌套深度。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param depth? integer 最大深度，必须为正整数，默认为 1000
---@return integer depth 当前（或更新后的）设置值
function cjson.encode_max_depth(depth) end

---获取或设置解码时允许的最大嵌套深度。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param depth? integer 最大深度，必须为正整数，默认为 1000
---@return integer depth 当前（或更新后的）设置值
function cjson.decode_max_depth(depth) end

---获取或设置编码数字时的有效数字位数。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param precision? integer 有效数字位数，范围 1-14，默认为 14
---@return integer precision 当前（或更新后的）设置值
function cjson.encode_number_precision(precision) end

---获取或设置稀疏数组的编码行为。
---无参数时返回当前设置；提供参数时更新设置并返回新值。
---@param convert? boolean 是否将过度稀疏的数组转换为 JSON 对象，默认为 false
---@param ratio? integer 比率阈值，必须为正整数，默认为 2
---@param safe? integer 安全阈值，必须为正整数，默认为 10
---@return boolean convert 当前（或更新后的）convert 设置值
---@return integer ratio 当前（或更新后的）ratio 设置值
---@return integer safe 当前（或更新后的）safe 设置值
function cjson.encode_sparse_array(convert, ratio, safe) end

---创建 Lua CJSON 模块的独立副本。
---新模块拥有独立的持久编码缓冲区和默认设置，适用于多线程环境。
---@return cjson new_module 新的独立模块表
function cjson.new() end

---@class cjson.safe
---cjson.safe 模块，行为与 cjson 模块相同，但在编解码出错时不会抛出异常，
---而是返回 nil 和错误信息字符串。
---加载方式：`local cjson_safe = require("cjson.safe")`
local cjson_safe = {}

---安全版本的序列化函数，出错时返回 nil 和错误信息。
---@param value any 待编码的 Lua 值
---@return string? json_text 成功时返回 JSON 字符串
---@return nil|string error 失败时返回错误信息
function cjson_safe.encode(value) end

---安全版本的反序列化函数，出错时返回 nil 和错误信息。
---@param json_text string JSON 格式字符串
---@return any value 成功时返回反序列化后的 Lua 值或表
---@return nil|string error 失败时返回错误信息
function cjson_safe.decode(json_text) end

return cjson