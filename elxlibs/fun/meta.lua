---@diagnostic disable: missing-return, duplicate-set-field
---@meta


---@class FunLib
local fun = {}


---@alias FunLib._Gen<T> fun():T...
---@alias FunLib._Gen1<T> fun():T
---@alias FunLib._Gen2<T1, T2> fun():(T1, T2)
---@alias FunLib._Gen3<T1, T2, T3> fun():(T1, T2, T3)

---@alias FunLib.FunGenerator<T..., P=any, S=any> fun(param: P, state: S):T...
---@alias FunLib.FunGenerator1<T, P=any, S=any> fun(param: P, state: S):T
---@alias FunLib.FunGenerator2<T1, T2, P=any, S=any> fun(param: P, state: S):(T1, T2)
---@alias FunLib.FunGenerator3<T1, T2, T3, P=any, S=any> fun(param: P, state: S):(T1, T2, T3)

---@class FunLib.Iterator<T..., P=any, S=any>
---@field param P
---@field state S
---@field gen FunLib.FunGenerator<T, P, S>
---@overload fun(s:self, param: P, state: S):T...
local methods = {}

---@class FunLib.Iterator1<T, P=any, S=any>
---@field param P
---@field state S
---@field gen FunLib.FunGenerator1<T, P, S>
---@overload fun(s:self, param: P, state: S):T
local methods1 = {}

---@class FunLib.Iterator2<T1, T2, P=any, S=any>
---@field param P
---@field state S
---@field gen FunLib.FunGenerator2<T1, T2, P, S>
---@overload fun(s:self, param: P, state: S):(T1, T2)
local methods2 = {}

---@class FunLib.Iterator3<T1, T2, T3, P=any, S=any>
---@field param P
---@field state S
---@field gen FunLib.FunGenerator3<T1, T2, T3, P, S>
---@overload fun(s:self, param: P, state: S):(T1, T2, T3)
local methods3 = {}

---@alias FunLib.Generator<T..., P=any, S=any>
--- | FunLib._Gen<T>
--- | FunLib.FunGenerator<T, P, S>
--- | FunLib.Iterator<T, P, S>
---@alias FunLib.Generator1<T, P=any, S=any>
--- | FunLib._Gen1<T>
--- | FunLib.FunGenerator1<T, P, S>
--- | FunLib.Iterator1<T, P, S>
---@alias FunLib.Generator2<T1, T2, P=any, S=any>
--- | FunLib._Gen2<T1, T2>
--- | FunLib.FunGenerator2<T1, T2, P, S>
--- | FunLib.Iterator2<T1, T2, P, S>
---@alias FunLib.Generator3<T1, T2, T3, P=any, S=any>
--- | FunLib._Gen3<T1, T2, T3>
--- | FunLib.FunGenerator3<T1, T2, T3, P, S>
--- | FunLib.Iterator3<T1, T2, T3, P, S>

--- *wrap*

---@generic T..., P, S
---@param gen FunLib.FunGenerator<T>
---@param param? P
---@param state? S
---@return FunLib.Iterator<T, P, S>
function fun.wrap(gen, param, state) end

---@generic T, P, S
---@param gen FunLib.FunGenerator1<T>
---@param param? P
---@param state? S
---@return FunLib.Iterator1<T, P, S>
function fun.wrap(gen, param, state) end

---@generic T1, T2, P, S
---@param gen FunLib.FunGenerator2<T1, T2>
---@param param? P
---@param state? S
---@return FunLib.Iterator2<T1, T2, P, S>
function fun.wrap(gen, param, state) end

---@generic T1, T2, T3, P, S
---@param gen FunLib.FunGenerator3<T1, T2, T3>
---@param param? P
---@param state? S
---@return FunLib.Iterator3<T1, T2, T3, P, S>
function fun.wrap(gen, param, state) end

--- *unwrap*

---@return FunLib.FunGenerator<T, P, S>
function methods:unwrap() end

---@return FunLib.FunGenerator1<T, P, S>
function methods1:unwrap() end

---@return FunLib.FunGenerator2<T1, T2, P, S>
function methods2:unwrap() end

---@return FunLib.FunGenerator3<T1, T2, T3, P, S>
function methods3:unwrap() end

--------------------------------------------------------------------------------
--region Basic Functions
--------------------------------------------------------------------------------

--- *iter*

---@generic T..., P, S
---@param obj FunLib.Generator<T, P, S>
---@param param? P
---@param state? S
---@return FunLib.Iterator<T, P, S>
function fun.iter(obj, param, state) end

---@generic T, P, S
---@param obj FunLib.Generator1<T, P, S>
---@param param? P
---@param state? S
---@return FunLib.Iterator1<T, P, S>
function fun.iter(obj, param, state) end

---@generic T1, T2, P, S
---@param obj FunLib.Generator2<T1, T2, P, S>
---@param param? P
---@param state? S
---@return FunLib.Iterator2<T1, T2, P, S>
function fun.iter(obj, param, state) end

---@generic T1, T2, T3, P, S
---@param obj FunLib.Generator3<T1, T2, T3, P, S>
---@param param? P
---@param state? S
---@return FunLib.Iterator3<T1, T2, T3, P, S>
function fun.iter(obj, param, state) end

---@generic T
---@param obj T[]
---@return FunLib.Iterator2<int, T>
function fun.iter(obj) end

---@generic K, V
---@param obj table<K, V>
---@return FunLib.Iterator3<int, K, V>
function fun.iter(obj) end

--- *each*

---@generic T..., P, S
---@param func fun(...: T...)
---@param gen FunLib.Generator<T, P, S>
---@param param? P
---@param state? S
function fun.each(func, gen, param, state) end

---@generic T, P, S
---@param func fun(item: T)
---@param gen FunLib.Generator1<T, P, S>
---@param param? P
---@param state? S
function fun.each(func, gen, param, state) end

---@generic T1, T2, P, S
---@param func fun(item1: T1, item2: T2)
---@param gen FunLib.Generator2<T1, T2, P, S>
---@param param? P
---@param state? S
function fun.each(func, gen, param, state) end

---@generic T1, T2, T3, P, S
---@param func fun(item1: T1, item2: T2, item3: T3)
---@param gen FunLib.Generator3<T1, T2, T3, P, S>
---@param param? P
---@param state? S
function fun.each(func, gen, param, state) end

---@generic T
---@param func fun(it: int, item: T)
---@param gen T[]
function fun.each(func, gen) end

---@generic K, V
---@param func fun(it: int, key: K, val: V)
---@param gen table<K, V>
function fun.each(func, gen) end

---@param func fun(...: T...)
function methods:each(func) end
---@param func fun(item: T)
function methods1:each(func) end
---@param func fun(item1: T1, item2: T2)
function methods2:each(func) end
---@param func fun(item1: T1, item2: T2, item3: T3)
function methods3:each(func) end

fun.for_each = fun.each
fun.foreach = fun.each
methods.for_each = methods.each
methods.foreach = methods.each

--endregion

--------------------------------------------------------------------------------
--region Generators
--------------------------------------------------------------------------------

---@param start int
---@param stop? int
---@param step? int
---@return FunLib.Iterator<std.Unpack<[int, int]>>
function fun.range(start, stop, step) end

---@generic T
---@param ... T...
---@return FunLib.Iterator<T...>
function fun.duplicate(...) end

fun.replicate = fun.duplicate
fun.xrepeat = fun.duplicate

function fun.tabulate(func)
    
end

--endregion
