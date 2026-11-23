-- std.class: shared methods with per-class storage and attribute policies.
---@namespace std

local exception = require 'elxlibs.std.exception'
local inspect = require 'elxlibs.std.inspect'
local type = type
local rawget = rawget
local rawset = rawset
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local actual_metatable = debug.getmetatable
local raise = exception.raise
local protected = not _G._STD_CLASS_DEBUG

---@class ClassOptions
---@field dict     boolean? Inherit from parent; default false. Full hooks/data descriptors also select dict.
---@field abstract boolean? Not inherited.
---@field final    boolean? Not inherited.

---@class Descriptor
---@field __get (fun(descriptor: self, instance: object?, owner: class): any)?
---@field __set (fun(descriptor: self, instance: object, value: any))?

---@class _class_meta
---@field __tostring     fun(self: self): string
---@field __add          (fun(self: self, other: any): any)?
---@field __sub          (fun(self: self, other: any): any)?
---@field __mul          (fun(self: self, other: any): any)?
---@field __div          (fun(self: self, other: any): any)?
---@field __mod          (fun(self: self, other: any): any)?
---@field __pow          (fun(self: self, other: any): any)?
---@field __unm          (fun(self: self): any)?
---@field __concat       (fun(self: self, other: any): any)?
---@field __lt           (fun(self: self, other: any): boolean)?
---@field __le           (fun(self: self, other: any): boolean)?
---@field __len          (fun(self: self): integer)?
---@field __eq           (fun(self: self, other: any): boolean)?
---@field __getattr      (fun(self: self, key: any): any)?
---@field __getattribute (fun(self: self, key: any): any)?
---@field __setattr      (fun(self: self, key: any, value: any))?
---@field __setattribute (fun(self: self, key: any, value: any))?

---@class class: _class_meta
---@field __name   string
---@field __parent class?
---@field __mro    class[]                              Trusted structural metadata.
---@field __dict   table<string, any>                   Shared class members, independent of instance storage.
---@field __call   fun(self: self, ...: any...): object
---@overload fun(self: self, ...: any...): object

---@class _DescriptorEntry
---@field value Descriptor
---@field get   function?
---@field set   function?

---@class _ClassState
---@field cls         class
---@field opts        ClassOptions
---@field finished    boolean
---@field dict        boolean?
---@field descriptors table<string, _DescriptorEntry>?
---@field metatable   table?
---@field allocate    (fun(): object)?
---@field read        (fun(obj: object, key: any): any)?        Skip custom hooks; include descriptors.
---@field write       (fun(obj: object, key: any, value: any))? Skip custom hooks; include descriptors.
---@field data        (fun(obj: object): table)?

---@class classlib
---@generic T, B: object
---@overload fun(name: `T`, parent?: class, dict?: table<string, any>, opts?: ClassOptions): T
local M = {}

---@not_return
local function fail(message)
    -- During the initial class/exception import, exception types are not ready yet.
    if exception.TypeError then
        raise(exception.TypeError(message))
    end

    error('TypeError: ' .. message, 3)
end

---@param cls any
---@return _ClassState?
local function state_of(cls)
    if type(cls) ~= 'table' then
        return nil
    end

    local mt = actual_metatable(cls)
    if type(mt) ~= 'table' then
        return nil
    end

    local state = rawget(mt, '__class_state')
    if type(state) == 'table' and rawequal(state.cls, cls) then
        return state
    end
end

local function check_class(cls)
    local state = state_of(cls)
    if not state then
        fail('expected a class type')
    end
    return state
end

local function class_of(obj)
    if type(obj) ~= 'table' or state_of(obj) then
        return nil
    end
    local cls = rawget(obj, '__class')
    if state_of(cls) then
        return cls
    end
end

local function lookup(cls, key)
    local value = rawget(cls, '__dict')[key]
    if value ~= nil then
        return value
    end

    local mro = rawget(cls, '__mro')
    for i = 2, #mro do
        value = rawget(mro[i], '__dict')[key]
        if value ~= nil then
            return value
        end
    end
end

local function hook(cls, key)
    local value = lookup(cls, key)
    if value == false then
        return nil
    end
    if value ~= nil and type(value) ~= 'function' then
        fail(key .. ' must be a function or false')
    end
    return value
end

local meta_names = {
    '__tostring', '__add', '__sub', '__mul', '__div', '__mod', '__pow', '__unm', '__concat', '__lt', '__le', '__len',
    '__call', '__eq'
}
-- Do not collect table finalizers on LuaJIT's Lua 5.1 runtime.
local version = tonumber(_VERSION:match('%d+%.%d+')) or 5.1
if version >= 5.2 then
    meta_names[#meta_names + 1] = '__pairs'
    meta_names[#meta_names + 1] = '__gc'
end
if version >= 5.3 then
    for _, name in ipairs({ '__idiv', '__band', '__bor', '__bxor', '__bnot', '__shl', '__shr' }) do
        meta_names[#meta_names + 1] = name
    end
end
if version >= 5.4 then
    meta_names[#meta_names + 1] = '__close'
end

local function collect_descriptors(cls)
    local seen, result = {}, nil
    local base = cls

    while base do
        for key, value in pairs(rawget(base, '__dict')) do
            if not seen[key] then
                seen[key] = true
                if type(value) == 'table' then
                    local getter, setter = value.__get, value.__set
                    if getter ~= nil or setter ~= nil then
                        if getter ~= nil and type(getter) ~= 'function' then
                            fail('descriptor __get must be a function')
                        end
                        if setter ~= nil and type(setter) ~= 'function' then
                            fail('descriptor __set must be a function')
                        end
                        result = result or {}
                        result[key] = { value = value, get = getter, set = setter }
                    end
                end
            end
        end
        base = rawget(base, '__parent')
    end

    return result
end

local function direct_data(obj)
    return obj
end

local function dict_data(obj)
    return rawget(obj, '__dict')
end

-- These builders run once per class. Ordinary access does not test storage mode.
local function build_read(cls, data, dict, descriptors)
    if descriptors then
        return function (obj, key)
            local descriptor = descriptors[key]
            if descriptor and descriptor.set and descriptor.get then
                return descriptor.get(descriptor.value, obj, cls), true
            end

            local value = rawget(data(obj), key)
            if value ~= nil then
                return value
            end
            if descriptor then
                if descriptor.get then
                    return descriptor.get(descriptor.value, obj, cls), true
                end
                return descriptor.value, true
            end

            return lookup(cls, key)
        end
    elseif dict then
        return function (obj, key)
            local value = rawget(obj, '__dict')[key]
            if value ~= nil then
                return value
            end
            return lookup(cls, key)
        end
    end

    return function (obj, key)
        local value = rawget(obj, key)
        if value ~= nil then
            return value
        end
        return lookup(cls, key)
    end
end

local function build_write(data, dict, descriptors)
    if descriptors then
        return function (obj, key, value)
            local descriptor = descriptors[key]
            if descriptor and descriptor.set then
                return descriptor.set(descriptor.value, obj, value)
            end
            rawset(data(obj), key, value)
        end
    end

    if dict then
        return function (obj, key, value)
            rawget(obj, '__dict')[key] = value
        end
    end

    return function (obj, key, value)
        rawset(obj, key, value)
    end
end

---@type fun(cls: class): _FinishedClassState
local finish
local default_new

---@class _FinishedClassState: _ClassState
---@field allocate fun(): object
---@field read     fun(obj: object, key: any): any
---@field write    fun(obj: object, key: any, value: any)
---@field data     fun(obj: object): table

---@param cls class
---@return _FinishedClassState
finish = function (cls)
    local state = check_class(cls)
    if state.finished then
        return state --[[@as _FinishedClassState]]
    end

    local parent = rawget(cls, '__parent')
    if parent then
        finish(parent)
    end

    local getattr = hook(cls, '__getattr')
    local setattr = hook(cls, '__setattr')
    local getattribute = hook(cls, '__getattribute')
    local setattribute = hook(cls, '__setattribute')
    local descriptors = collect_descriptors(cls)
    local has_setter = false

    if descriptors then
        for _, descriptor in pairs(descriptors) do
            if descriptor.set then
                has_setter = true
                break
            end
        end
    end

    local dict = state.opts.dict or getattribute ~= nil or setattribute ~= nil or has_setter
    local data = dict and dict_data or direct_data
    local read = build_read(cls, data, dict, descriptors)
    local write = build_write(data, dict, has_setter and descriptors or nil)
    local mt = {}

    for _, name in ipairs(meta_names) do
        local value = lookup(cls, name)
        if value ~= nil then
            mt[name] = value
        end
    end

    if protected then
        mt.__metatable = 'protected'
    end
    if not mt.__tostring then
        mt.__tostring = function ()
            return 'object(' .. rawget(cls, '__name') .. ')'
        end
    end

    -- Existing direct fields use native access; missing fields only search members.
    if getattribute then
        mt.__index = getattribute
    elseif getattr then
        mt.__index = function (obj, key)
            local value, found = read(obj, key)
            if found or value ~= nil then
                return value
            end

            return getattr(obj, key)
        end
    elseif dict or descriptors then
        mt.__index = read
    else
        mt.__index = function (_, key)
            return lookup(cls, key)
        end
    end

    if setattribute then
        mt.__newindex = setattribute
    elseif setattr then
        mt.__newindex = function (obj, key, value)
            if rawget(data(obj), key) ~= nil or lookup(cls, key) ~= nil then
                return write(obj, key, value)
            end

            return setattr(obj, key, value)
        end
    elseif dict or has_setter then
        mt.__newindex = write
    end

    ---@type fun(): object
    local allocate

    if dict then
        allocate = function ()
            local obj = { __class = cls, __dict = {} }
            return setmetatable(obj, mt)
        end
    else
        allocate = function ()
            return setmetatable({ __class = cls }, mt)
        end
    end

    local cls_mt = actual_metatable(cls) --[[@as table<string, any>]]

    if descriptors then
        cls_mt.__index = function (_, key)
            local descriptor = descriptors[key]

            if descriptor and descriptor.get then
                return descriptor.get(descriptor.value, nil, cls)
            end

            return lookup(cls, key)
        end
    end

    state.dict = dict
    state.data = data
    state.read = read
    state.write = write
    state.descriptors = descriptors
    state.metatable = mt
    state.allocate = allocate
    state.finished = true

    -- Allocation policy is cached; user-defined constructors remain dynamic.
    if state.opts.abstract then
        cls_mt.__call = function (_cls, ...)
            fail('class is abstract')
        end
    else
        cls_mt.__call = function (_, ...)
            local constructor = lookup(cls, '__new')
            if constructor ~= default_new then
                return constructor(cls, ...)
            end
            local obj = allocate() --[[@as object]]
            obj:__init(...)
            return obj
        end
    end

    return state --[[@as _FinishedClassState]]
end

local option_keys = { dict = true, abstract = true, final = true }

local function options(parent, supplied)
    if supplied ~= nil and type(supplied) ~= 'table' then
        fail('options must be a table')
    end

    local result = {
        dict = parent and check_class(parent).opts.dict or false,
        abstract = false,
        final = false
    }

    for key, value in pairs(supplied or {}) do
        if not option_keys[key] then
            fail('unknown class option ' .. tostring(key))
        end
        if type(value) ~= 'boolean' then
            fail(key .. ' must be a boolean')
        end
        result[key] = value
    end

    return result
end

local function new_class(name, parent, dict, opts, root)
    if type(name) ~= 'string' or name == '' then
        fail('class name must be a nonempty string')
    end

    if parent ~= nil then
        if check_class(parent).opts.final then
            fail('class is final')
        end
    elseif not root then
        parent = M.object
    end

    if dict ~= nil and type(dict) ~= 'table' then
        fail('class members must be a table')
    end

    local cls = {
        __name = name,
        __parent = parent,
        __dict = dict or {},
        __mro = {},
    }
    ---@cast cls class
    local state = {
        cls = cls,
        opts = options(parent, opts),
        finished = false,
    }

    cls.__mro[1] = cls
    if parent then
        for i, base in ipairs(parent.__mro) do
            cls.__mro[i + 1] = base
        end
    end

    local mt = {
        __class_state = state,
        __index = function (_, key)
            return lookup(cls, key)
        end,
        __newindex = function (_, key, value)
            cls.__dict[key] = value
        end,
        __call = function (_, ...)
            finish(cls)
            return (actual_metatable(cls) --[[@as table]]).__call(cls, ...)
        end,
        __tostring = function ()
            return 'class(' .. rawget(cls, '__name') .. ')'
        end
    }

    if protected then
        mt.__metatable = 'protected'
    end

    return setmetatable(cls, mt)
end

---@class object: class
---@field __class class
---@field __new   fun(cls: class): self
local object = new_class('object', nil, {}, nil, true)

function object:__new(...)
    local state = finish(self)

    if state.opts.abstract then
        fail('class is abstract')
    end

    local obj = state.allocate()
    obj:__init(...)

    return obj
end
default_new = object.__new

function object.__init(_self, ...)
end

M.object = object

---@generic T, B: object
---@[constructor('__init', 'object')]
---@param name    `T`
---@param parent? B
---@param dict?   table<string, any>
---@param opts?   ClassOptions
---@return T
---@overload fun(name: `T`, parent: nil, dict?: table<string, any>, opts?: ClassOptions): T
function M.new(name, parent, dict, opts)
    return new_class(name, parent, dict, opts)
end

---@generic T
---@param name    `T`
---@param parent? class
---@param dict?   table<string, any>
---@param opts?   ClassOptions
---@return T
function M.new_abstract(name, parent, dict, opts)
    local copied = options(parent, opts)
    copied.abstract = true
    return new_class(name, parent, dict, copied)
end

---@generic T
---@param name    `T`
---@param parent? class
---@param dict?   table<string, any>
---@param opts?   ClassOptions
---@return T
function M.new_final(name, parent, dict, opts)
    local copied = options(parent, opts)
    copied.final = true
    return new_class(name, parent, dict, copied)
end

---@generic T: class
---@param cls T
---@return T
function M.finish(cls)
    finish(cls)
    return cls
end

---@param obj  any
---@param kind ('object' | 'class')?
---@overload fun(obj: any): 'object' | 'class' | nil
---@overload fun(obj: any, kind: 'object' | 'class'): boolean
function M.kindof(obj, kind)
    local found

    if state_of(obj) then
        found = 'class'
    elseif class_of(obj) then
        found = 'object'
    elseif kind then
        return false
    end

    if kind then
        return found == kind
    end

    return found
end

---@param cls class
---@return boolean
function M.isabstract(cls)
    return check_class(cls).opts.abstract
end

---@param cls class
---@return boolean
function M.isfinal(cls)
    return check_class(cls).opts.final
end

---@generic T: class
---@param cls     T
---@param clsinfo T
---@return boolean
function M.issubclass(cls, clsinfo)
    check_class(cls)
    check_class(clsinfo)

    while cls do
        if rawequal(cls, clsinfo) then
            return true
        end

        cls = rawget(cls, '__parent')
    end

    return false
end

---@generic T: class
---@param obj any
---@param cls T | [T...]
---@return TypeGuard<T>
---@overload fun(obj: any, cls: T): TypeGuard<T>
---@overload fun(obj: any, cls:[T...]): TypeGuard<T...>
function M.isinstance(obj, cls)
    local obj_cls = class_of(obj)

    if not obj_cls then
        return false
    end

    if state_of(cls) then
        return M.issubclass(
            obj_cls,
            cls --[[@as class]]
        )
    end

    if type(cls) ~= 'table' then
        fail('expected a class or class list')
    end

    ---@cast cls [T...]
    for _, candidate in ipairs(cls) do
        if M.issubclass(obj_cls, candidate) then
            return true
        end
    end

    return false
end

local function super_proxy(parent, obj)
    local state = finish(parent)
    local proxy
    local cache = {}

    local mt = {
        __index = function (_, key)
            local descriptor = state.descriptors and state.descriptors[key]
            local value

            if descriptor and descriptor.get then
                value = descriptor.get(descriptor.value, obj, parent)
            else
                value = lookup(parent, key)
            end
            if type(value) ~= 'function' or not obj then
                return value
            end

            local entry = cache[key]

            if not entry or entry.value ~= value then
                entry = {
                    value = value,
                    bound = function (arg1, ...)
                        if arg1 == proxy then
                            return value(obj, ...)
                        end

                        return value(arg1, ...)
                    end
                }
                cache[key] = entry
            end

            return entry.bound
        end,
        __newindex = function ()
            fail('cannot modify super class')
        end
    }

    if protected then
        mt.__metatable = 'protected'
    end

    proxy = setmetatable({}, mt)
    return proxy
end

--- With no receiver, return the actual parent class (no proxy or method wrappers).
--- With a receiver, preserve bound and explicit-self calls through a readonly proxy.
---@generic R extends class
---@generic T extends R
---@param cls           T
---@param obj_or_cls?   object | class
---@param _target_type? R              Only for type inference.
---@return R
function M.super(cls, obj_or_cls, _target_type)
    check_class(cls)
    local parent = rawget(cls, '__parent')

    if not parent then
        fail('object has no super class')
    end

    if obj_or_cls == nil then
        return parent --[[@as R]]
    end

    local target = state_of(obj_or_cls) and obj_or_cls or class_of(obj_or_cls)

    if not target then
        fail('obj_or_cls must be an object or class')
    end

    if not M.issubclass(target, cls) then
        fail('class is not in target hierarchy')
    end

    return super_proxy(parent, class_of(obj_or_cls) and obj_or_cls or nil) --[[@as R]]
end

-- Install private primitives. Reflection and attribute tools belong to inspect.
inspect.__install('std.class', {
    state_of = state_of,
    finish = finish,
    getmetatable = actual_metatable,
    fail = fail
})

local module_mt = {
    __call = function (_, ...)
        return M.new(...)
    end
}

if protected then
    module_mt.__metatable = 'protected'
end

---@type classlib
local module = setmetatable(M, module_mt)
return module
