# 代码风格

本项目以 LuaJIT 的 Lua 5.1 语法为目标，使用 EmmyLua 类型注解和
`emmylua_check` 检查代码。本规范参考 elxosc 的 `codestyle.md`，适用于本项目
维护的库代码、测试和示例；开发、验证和提交流程见 [AGENTS.md](AGENTS.md)。
第三方代码保留原有风格及来源，修改现有文件时避免无关的全文件重排。

## 排版

- 使用四个空格缩进，不使用 Tab；文件末尾保留一个换行，行末不留空格。
- 项目字符串优先使用单引号；字符串含单引号时可以使用双引号，减少转义。
- 逗号、注解类型冒号后留一个空格，二元运算符两侧留空格。
  函数调用的括号紧跟函数名；匿名函数写作 `function (...)`。
- 非空函数、条件分支、循环和回调保持展开，不压成单行，不用分号拼接语句。
  简单数据表可以写成 `{ key = value }`；包含回调、嵌套结构或较长字段时展开。
- 空行分隔导入、类型声明、函数以及函数内部的逻辑阶段。紧密相关的读取、校验
  和返回可以连续书写，不要求每个语句或每个分支之间都加空行。
- 长调用按参数换行；长条件在逻辑连接处换行，续行保持四个空格缩进。
  不为对齐扩展出很宽的代码，也不把相关内容机械地拆成多层局部变量。
- 实例字段逐项赋值，便于阅读。交换值或接收相关的多个返回值可以使用多重赋值。
- 小范围的 `---@field`、`---@param` 名称和类型列可以用空格对齐；注解块与下一项
  独立声明之间留空行，防止注解关联到错误的声明。

```lua
local options = { dict = false, abstract = false }

local callbacks = {
    on_result = function (value)
        consume(value)
    end
}

local function initialize(self, values)
    self.width = values.width
    self.height = values.height

    if self.width > 0 and
        self.height > 0 then
        return true
    end
    return false
end
```

## 模块导入与局部变量

库内使用完整的 `elxlibs.*` 路径，先导入模块，再提取所需成员。模块局部变量使用
清楚的名称；`M` 可以用于文件末尾返回的模块表。生产别名配置只放在 `init.lua`，
不要在纯库或离线测试里复制入口的 DLL 设置。

```lua
local std = require 'elxlibs.std'
local futures = require 'elxlibs.asyncio.futures'

local Future = futures.Future
local raise = std.raise
```

避免把 `require('path').Member` 作为常规导入形式，也不要用含义不明的单字母别名。
高频调用的函数和成员可以 local 化；低频类定义、配置和冷路径查询不必机械地
逐项 local 化。需要优化时以实际访问频率和测量结果为依据。

命名函数优先使用 `local function name(...)` 或 `function M.name(...)`。
回调、按策略选择的函数和需要前向声明的递归函数可以使用函数表达式。
实例方法使用 `:`；不接收实例的函数使用 `.`，不要仅为外观一致引入无用的 `self`。

聚合模块显式重导出来源模块的同一对象，不重复定义类或创建替代对象。完整重导出
可复用来源模块类型；部分导出只声明实际提供的字段。新增导入不得引入 require 循环。

## 类型声明与 namespace

**不强制使用 `---@namespace` 或 `---@using`。** 可以沿用模块已有的 namespace，
也可以显式声明和引用完整类型名。选择能准确解析、避免重名且便于阅读的方式；
同一模块内保持一致，不为了统一前缀批量修改其他模块。

namespace、using 和类型名前缀只服务于静态类型，不改变运行时类名、模块路径或
对象身份。本项目不采用 elxosc 的 `elxosc.mod.*`、Define 或控件命名规则。

- 实例类型、模块表类型和 Options 类型分别声明；多个模块使用的普通名称应有
  明确归属，避免全局的 `Class`、`Options` 等名称发生冲突。
- 公共函数和可复用局部函数补齐参数及有意义的返回类型；override 或上下文已明确
  的短回调可以复用已知签名。构造函数不加无意义的 `---@return nil`。
- `---@field` 描述实际实例字段和共享成员；使用可见性标记说明内部字段，不通过
  声明任意字符串字段来掩盖不存在的成员。
- 复杂或重复的 Options、参数和返回结构使用命名类型。可选字段按实际合同标记，
  不仅因为调用方可能漏传就把必填字段改成可选。
- 类型断言和 `---@cast` 只用于已经验证的边界或分析器无法推导的关系，不替代
  运行时校验，也不把对象转成无关的 `table`、`any` 或可调用类型。

重复使用的闭合字符串集合提取成语义化 alias，较长集合逐行列出，字面量使用单引号。
只有真正可扩展的开放集合才使用 `string`，并说明扩展方式；闭合集合不要追加
`| string`，否则会丢失非法值检查。

```lua
---@alias TransferState
---| 'pending'
---| 'finished'
---| 'cancelled'

---@generic T
---@param value T
---@return T[]
local function singleton(value)
    return { value }
end
```

泛型、`TypeGuard<T>`、`Partial<T>` 和 `---@return_overload` 用于表达真实的类型
关系。成功与失败关联返回、多返回值及尾部 nil 应按实际行为声明；单纯返回布尔值
的守卫不要写成可空布尔值。类型注解不能代替公开参数边界的运行时检查。

## class 与 dataclass

`std.class.new` 定义的类型应显式声明继承自 `std.object` 或已有的 std 类，列出
实例字段，并用 `---@overload fun(...): self` 描述构造调用。Options 表使用具名类型，
如 `_TransferOptions`；跨接口复用时可以使用 `TransferOptions` 等公开名称。

```lua
local std = require 'elxlibs.std'

---@class _TransferOptions
---@field name string
---@field size number?

---@class Transfer: std.object
---@field name string
---@field size number
---@overload fun(options: _TransferOptions): self
local Transfer = std.class.new('Transfer')

---@param options _TransferOptions
function Transfer:__init(options)
    self.name = options.name
    self.size = options.size or 0
end

---@return number
function Transfer:remaining()
    return self.size
end
```

构造 overload 与实际 `__init` 参数一致；类型声明不修改运行时类名。定义元方法、
属性 hook 和描述符时遵守类结束周期，放在 `class.finish` 或首次构造之前。
`std.inspect` 使用 `require 'elxlibs.std.inspect'` 或 std 聚合入口，class 只安装
底层能力，工具实现留在 inspect；详细合同见 [class 文档](elxlibs/std/README.md)。

独立 `elxlibs.dataclass` 显式声明实例字段和构造 overload，按需使用
`dataclass.Object` 注解基类。运行时字段声明不自动生成静态注解；其对象身份和
继承接口独立于 std.class，不标成 `std.object` 或假称兼容 std 反射。
详细用法见 [dataclass 文档](elxlibs/dataclass/README.md)。

## 配置、错误与运行时边界

- 应用默认值时写入新对象，或先浅复制配置；不修改调用方传入的 options 表。
  nil 和 false 含义不同，布尔默认值需要显式判断 nil，不用 `value or default`
  覆盖有效的 false。
- 默认路径只承担必要功能；可选存储和分派策略尽量在定义或类完成阶段选择，
  不为方便实现把所有判断都放进每次属性访问。
- 错误行为按所属模块合同处理。std 异常路径保留类型、cause 和 traceback，纯工具
  不因抛错而无故加载宿主或额外依赖。
- 纯库导入保持宿主无关。mpv 事件泵、日志桩和脚本行为由明确的宿主模块或测试组
  负责；文件系统和子进程测试使用隔离路径及自己创建的进程。
- 分析器提供的内置类型或 Lua 5.2+ API 不代表 LuaJIT 5.1 支持这些运行时能力。
  不使用不受支持的运算符、复合赋值或 table finalizer。

## 诊断、验证与修改范围

优先补全局部类型信息，不使用文件级 diagnostic 禁用或修改全局分析器设置来隐藏
生产代码问题。已确认的分析器或第三方限制可以在具体表达式附近局部禁用，注明原因。
测试中的动态或非法输入通过组内明确的辅助函数表达，不扩大生产 API 类型来容纳负例。

新增或改变公共行为时，测试可观察结果、失败边界、生命周期及模块 identity。
风格文档或纯排版变更不增加只重复实现的测试。验证从项目根运行，提交前执行
[AGENTS.md](AGENTS.md) 中的必需检查；改动宿主、入口或依赖时执行相应的额外检查。
检查未运行或已有诊断必须如实说明。

已有工作区修改视为用户有意的工作。只修改本次任务需要的文件，不为了符合本规范
重排第三方代码或批量改写其他模块。公共合同文档放在所属模块或现有 README 中，
不把未实现 API 描述为已经提供的功能。
