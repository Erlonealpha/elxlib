---@meta

---@class PcrePatternFlags
---@field CASELESS integer PCRE2_CASELESS：忽略大小写匹配[reference:0]
---@field MULTILINE integer PCRE2_MULTILINE：多行模式，^和$匹配行首行尾[reference:1]
---@field DOTALL integer PCRE2_DOTALL：点号匹配所有字符（包括换行符）[reference:2]
---@field EXTENDED integer PCRE2_EXTENDED：忽略模式中的空白字符[reference:3]
---@field UNGREEDY integer PCRE2_UNGREEDY：量词默认非贪婪[reference:4]
---@field EXTRA integer PCRE2_EXTRA：启用PCRE2额外功能[reference:5]
---@field ANCHORED integer PCRE2_ANCHORED：模式仅在起始位置匹配
---@field ENDANCHORED integer PCRE2_ENDANCHORED：模式仅在末尾位置匹配
---@field NOTBOL integer PCRE2_NOTBOL：行起始锚点不匹配字符串起始
---@field NOTEOL integer PCRE2_NOTEOL：行结束锚点不匹配字符串结束
---@field NOTEMPTY integer PCRE2_NOTEMPTY：空匹配无效
---@field NOTEMPTY_ATSTART integer PCRE2_NOTEMPTY_ATSTART：起始位置空匹配无效
---@field PARTIAL_SOFT integer PCRE2_PARTIAL_SOFT：启用软部分匹配
---@field PARTIAL_HARD integer PCRE2_PARTIAL_HARD：启用硬部分匹配
---@field DFA_SHORTEST integer PCRE2_DFA_SHORTEST：DFA模式返回最短匹配
---@field DFA_RESTART integer PCRE2_DFA_RESTART：DFA模式重启匹配
---@field SUBSTITUTE_GLOBAL integer PCRE2_SUBSTITUTE_GLOBAL：全局替换
---@field SUBSTITUTE_EXTENDED integer PCRE2_SUBSTITUTE_EXTENDED：扩展替换
---@field SUBSTITUTE_UNKNOWN_UNSET integer PCRE2_SUBSTITUTE_UNKNOWN_UNSET：未知组替换为空
---@field SUBSTITUTE_OVERFLOW_LENGTH integer PCRE2_SUBSTITUTE_OVERFLOW_LENGTH：返回所需缓冲区长度

---PCRE2 库的标志常量表，可通过 rex.flags() 获取[reference:6]。
---PCRE2 常量的前缀 PCRE2_ 被省略，例如 PCRE2_CASELESS 对应键名为 "CASELESS"[reference:7]。
---@type PcrePatternFlags
local PcrePatternFlags = {}

---@class LrexlibPcre2Pattern
---编译后的 PCRE2 正则表达式对象，由 rex.new() 返回[reference:8]。
---@field __index fun(self: LrexlibPcre2Pattern, key: string): any
local LrexlibPcre2Pattern = {}

---在字符串中搜索第一个匹配项（方法版本）[reference:9]。
---@param subj string 目标字符串
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:10]
---@param ef? integer 执行标志（按位或），默认为 0[reference:11]
---@return any ... 成功时返回所有捕获的子串（按顺序），false 表示未参与匹配的子模式；若模式无捕获则返回整个匹配字符串[reference:12]
---@return nil 失败时返回 nil[reference:13]
function LrexlibPcre2Pattern:match(subj, init, ef) end

---在字符串中搜索第一个匹配项，返回偏移量和捕获（方法版本）[reference:14]。
---@param subj string 目标字符串
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:15]
---@param ef? integer 执行标志（按位或），默认为 0[reference:16]
---@return integer? start 成功时返回匹配起始位置
---@return integer? end 成功时返回匹配结束位置
---@return table? captures 成功时返回捕获子串表（按顺序），false 表示未参与匹配的子模式[reference:17]
---@return nil 失败时返回 nil[reference:18]
function LrexlibPcre2Pattern:find(subj, init, ef) end

---搜索第一个匹配项，返回偏移量和捕获表（方法版本，类似 tfind）[reference:19]。
---@param subj string 目标字符串
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:20]
---@param ef? integer 执行标志（按位或），默认为 0[reference:21]
---@return integer? start 成功时返回匹配起始位置
---@return integer? end 成功时返回匹配结束位置
---@return table? captures 成功时返回捕获子串表（按顺序），false 表示未参与匹配的子模式；若使用命名子模式，表中还包含以名称（字符串）为键的子串匹配[reference:22]
---@return nil 失败时返回 nil[reference:23]
function LrexlibPcre2Pattern:tfind(subj, init, ef) end

---搜索第一个匹配项，返回偏移量和捕获偏移量表（方法版本）[reference:24]。
---@param subj string 目标字符串
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:25]
---@param ef? integer 执行标志（按位或），默认为 0[reference:26]
---@return integer? start 成功时返回匹配起始位置
---@return integer? end 成功时返回匹配结束位置
---@return table? offsets 成功时返回捕获偏移量表（按顺序），false 表示未参与匹配的子模式；若使用命名子模式，表中还包含以名称（字符串）为键的偏移量[reference:27]
---@return nil 失败时返回 nil[reference:28]
function LrexlibPcre2Pattern:exec(subj, init, ef) end

---使用 DFA 匹配算法在字符串中搜索匹配（PCRE2 专用）[reference:29]。
---@param subj string 目标字符串[reference:30]
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:31]
---@param ef? integer 执行标志（按位或），默认为 0[reference:32]
---@param ovecsize? integer 结果偏移量数组大小，默认为 100[reference:33]
---@param wscount? integer 工作空间数组元素数量，默认为 50[reference:34]
---@return integer? start 成功时返回匹配起始位置
---@return table? ends 成功时返回包含所有匹配结束位置的表（较长匹配优先）[reference:35]
---@return integer? ret 成功时返回底层 pcre2_dfa_exec 调用的返回值[reference:36]
---@return nil 失败（无匹配）时返回 nil[reference:37]
function LrexlibPcre2Pattern:dfa_exec(subj, init, ef, ovecsize, wscount) end

---编译 JIT（即时编译）以加速匹配（PCRE2 专用）[reference:38]。
---@param options? integer 选项（按位或），默认为 PCRE2_JIT_COMPLETE[reference:39]
---@return boolean success 成功时返回 true[reference:40]
---@return false, string error 失败时返回 false 和错误信息字符串[reference:41]
function LrexlibPcre2Pattern:jit_compile(options) end

---获取编译后模式的信息（PCRE2 专用）[reference:42]。
---参考 PCRE2 文档中的 pcre2_patterninfo。
---@return table info 包含模式信息的表，键为字符串（如 "CAPTURECOUNT"），值为数字[reference:43]
function LrexlibPcre2Pattern:patterninfo() end

---@class LrexlibPcre2
---PCRE2 正则表达式库的 Lua 绑定模块（rex_pcre2）[reference:44]。
---加载方式：`local rex = require("rex_pcre2")`[reference:45]。
---所有函数都接受字符串类型的正则表达式参数，也接受编译后的正则对象[reference:46]。
local LrexlibPcre2 = {}

---编译正则表达式模式[reference:47]。
---@param patt string 正则表达式模式字符串[reference:48]
---@param cf? integer|string 编译标志（按位或），默认为 0；也可以使用字符串指定，如 "i" 表示 PCRE2_CASELESS[reference:49][reference:50]
---@param lo? string|userdata 区域设置，可以是字符串（如 "French_France.1252"）或由 maketables() 返回的用户数据，默认为内置 PCRE2 字符表[reference:51]
---@return LrexlibPcre2Pattern compiled 编译后的正则表达式对象（userdata）[reference:52]
function LrexlibPcre2.new(patt, cf, lo) end

---搜索第一个匹配项（函数版本）[reference:53]。
---@param subj string 目标字符串[reference:54]
---@param patt string|LrexlibPcre2Pattern 正则表达式模式或编译后的正则对象[reference:55]
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:56]
---@param cf? integer|string 编译标志（按位或），默认为 0[reference:57]
---@param ef? integer 执行标志（按位或），默认为 0[reference:58]
---@return any ... 成功时返回所有捕获的子串（按顺序），false 表示未参与匹配的子模式；若模式无捕获则返回整个匹配字符串[reference:59]
---@return nil 失败时返回 nil[reference:60]
function LrexlibPcre2.match(subj, patt, init, cf, ef) end

---搜索第一个匹配项，返回偏移量和捕获（函数版本）[reference:61]。
---@param subj string 目标字符串[reference:62]
---@param patt string|LrexlibPcre2Pattern 正则表达式模式或编译后的正则对象[reference:63]
---@param init? integer 起始偏移位置（可为负数），默认为 1[reference:64]
---@param cf? integer|string 编译标志（按位或），默认为 0[reference:65]
---@param ef? integer 执行标志（按位或），默认为 0[reference:66]
---@return integer? start 成功时返回匹配起始位置
---@return integer? end 成功时返回匹配结束位置
---@return table? captures 成功时返回捕获子串表（按顺序），false 表示未参与匹配的子模式[reference:67]
---@return nil 失败时返回 nil[reference:68]
function LrexlibPcre2.find(subj, patt, init, cf, ef) end

---返回一个迭代器，用于全局匹配[reference:69]。
---@param subj string 目标字符串[reference:70]
---@param patt string|LrexlibPcre2Pattern 正则表达式模式或编译后的正则对象[reference:71]
---@param cf? integer|string 编译标志（按位或），默认为 0[reference:72]
---@param ef? integer 执行标志（按位或），默认为 0[reference:73]
---@return fun():any... 迭代器函数，每次迭代返回所有捕获（按顺序），若模式无捕获则返回整个匹配[reference:74]
function LrexlibPcre2.gmatch(subj, patt, cf, ef) end

---全局替换[reference:75]。
---@param subj string 目标字符串[reference:76]
---@param patt string|LrexlibPcre2Pattern 正则表达式模式或编译后的正则对象[reference:77]
---@param repl string|table|fun(...):string 替换源：字符串模板、函数或表[reference:78]
---@param n? integer|fun(start:integer, finish:integer, repl_out:string):boolean|string, boolean|integer|nil 最大匹配次数或控制函数，默认为无限制[reference:79][reference:80]
---@param cf? integer|string 编译标志（按位或），默认为 0[reference:81]
---@param ef? integer 执行标志（按位或），默认为 0[reference:82]
---@return string result 替换后的字符串[reference:83]
---@return integer matches 匹配到的数量[reference:84]
---@return integer substitutions 实际替换的数量[reference:85]
function LrexlibPcre2.gsub(subj, patt, repl, n, cf, ef) end

---返回一个迭代器，用于分割字符串[reference:86]。
---@param subj string 目标字符串[reference:87]
---@param sep string|LrexlibPcre2Pattern 分隔符正则表达式模式或编译后的正则对象[reference:88]
---@param cf? integer|string 编译标志（按位或），默认为 0[reference:89]
---@param ef? integer 执行标志（按位或），默认为 0[reference:90]
---@return fun():string, any... 迭代器函数，每次迭代返回一个子串及所有捕获（按顺序）；若无匹配，最后一次仅返回剩余子串[reference:91]
function LrexlibPcre2.split(subj, sep, cf, ef) end

---统计模式匹配的次数[reference:92]。
---@param subj string 目标字符串[reference:93]
---@param patt string|LrexlibPcre2Pattern 正则表达式模式或编译后的正则对象[reference:94]
---@param cf? integer|string 编译标志（按位或），默认为 0[reference:95]
---@param ef? integer 执行标志（按位或），默认为 0[reference:96]
---@return integer count 匹配数量[reference:97]
function LrexlibPcre2.count(subj, patt, cf, ef) end

---返回包含所用正则库常量数值的表[reference:98]。
---@param tb? table 用于存放结果的表，若未提供则创建新表[reference:99]
---@return table flags 包含常量名称到数值的映射表[reference:100]
function LrexlibPcre2.flags(tb) end

---创建与当前区域设置对应的字符表（PCRE2 专用）[reference:101]。
---参考 PCRE2 文档中的 pcre2_maketables。
---@return userdata tables 字符表用户数据，可传递给接受 locale 参数的函数[reference:102]
function LrexlibPcre2.maketables() end

---返回 PCRE2 库构建时的配置参数表（PCRE2 专用）[reference:103]。
---参考 PCRE2 文档中的 pcre2_config。
---@param tb? table 用于存放结果的表，若未提供则创建新表[reference:104]
---@return table config 配置参数表，键为字符串（如 "JIT"），值为数字[reference:105]
function LrexlibPcre2.config(tb) end

---返回 PCRE2 库的版本信息字符串（PCRE2 专用）[reference:106]。
---参考 PCRE2 文档中的 pcre2_config(PCRE2_CONFIG_VERSION)。
---@return string version PCRE2 库版本及发布日期[reference:107]
function LrexlibPcre2.version() end

return LrexlibPcre2