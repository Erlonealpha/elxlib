-- std.class.lua
-- This file is part of the standard library of the elxlib.

---@namespace std

local exception = require 'elxlibs.std.exception'

local type = type
local pairs = pairs
local rawget = rawget
local ipairs = ipairs
local string = string
local tostring = tostring
local setmetatable  = setmetatable
local raise = exception.raise

local _STD_CLASS_DEBUG = _G._STD_CLASS_DEBUG


---@class classlib
---@generic T, B: object
---@overload fun(name: `T`, parent?: B, dict?: table<string, any>):T
local M = {}

---@alias __system_class_fields {
---     __type: 'class',
---     __name: string,
---     __abstract: boolean,
---     __final: boolean,
---     __parent: class?,
---     __mro: class[],
---     __addr: string,
---     __metatable: table<string, function>?,
--- }
---@alias __system_object_fields {
---     __type: 'object',
---     __name: string,
---     __class: class,
---     __addr: string,
--- }

-- _register is an ownership table for reflection metadata.
-- As long as class/object (key) is alive, its metadata (value) must stay alive.
-- Therefore: weak keys, strong values.
---@type {class: table<object|class,__system_class_fields>, object: table<object|class,__system_object_fields>}
local _register = {
    class =  setmetatable({}, {__mode = 'k'}),
    object = setmetatable({}, {__mode = 'k'}),
}
local _register_class = _register.class
local _register_object = _register.object

local function _register_cls(cls, mro, parent, opts)
    _register_class[cls] = {
        __type = 'class',
        __name = cls.__name,
        __abstract = opts and opts.abstract or false,
        __final = opts and opts.final or false,
        __parent = parent,
        __mro = mro,
        __addr = tostring(cls), -- Note: here cls's metatable is not set yet, 
                                --       so here is cls's real address string.
    }
end

local function _register_obj(obj, cls)
    _register_object[obj] = {
        __type = 'object', 
        __class = cls, 
        __name = cls.__name,
        __addr = tostring(obj)
    }
end

---@param cls class
---@param key string
local function _lookup_class_attr(cls, key)
    local dict = rawget(cls, '__dict')
    if dict then
        local v = dict[key]
        if v ~= nil then
            return v
        end
    end

    local mro = rawget(cls, '__mro')
    if mro then
        for i = 2, #mro do
            local b = mro[i]
            if b ~= nil then
                local base_dict = rawget(mro[i], '__dict')
                if base_dict then
                    local v = base_dict[key]
                    if v ~= nil then
                        return v
                    end
                end
            end
        end
    end
end

local function _lookup_object_attr(obj, key)
    local dict = rawget(obj, '__dict')
    if dict then
        local v = dict[key]
        if v ~= nil then
            return v
        end
    end

    local cls = rawget(obj, '__class')
    if cls then
        return _lookup_class_attr(cls, key)
    end
end

local lua_version_num = tonumber(_VERSION:match('%d+%.%d+')) or 5.1

local meta_names_basic = {
    '__gc', 
    '__tostring', 
    '__add', 
    '__sub', 
    '__mul', 
    '__div', 
    '__mod', 
    '__pow', 
    '__unm', 
    '__concat', 
    '__lt', 
    '__le', 
    '__len', 
    '__call',
    '__eq'
}
local meta_names_52 = {'__pairs'}
local meta_names_53 = {
    '__idiv', 
    '__band', 
    '__bor', 
    '__bxor', 
    '__bnot', 
    '__shl', 
    '__shr'
}
local meta_names_54 = {'__close'}

local meta_names = {}
do
    for _, v in ipairs(meta_names_basic) do
        meta_names[#meta_names+1] = v
    end
    if lua_version_num > 5.19 then
        for _, v in ipairs(meta_names_52) do
            meta_names[#meta_names+1] = v
        end
    end
    if lua_version_num > 5.29 then
        for _, v in ipairs(meta_names_53) do
            meta_names[#meta_names+1] = v
        end
    end
    if lua_version_num > 5.39 then
        for _, v in ipairs(meta_names_54) do
            meta_names[#meta_names+1] = v
        end
    end
end

------------------------------------------------------------------
-- Metatable defines the behavior of the class and its instances.
------------------------------------------------------------------

local class_mt = {}

if not _STD_CLASS_DEBUG then
    class_mt.__metatable = 'protected'
end

function class_mt.__index(cls, key)
    return _lookup_class_attr(cls, key)
end

function class_mt.__newindex(cls, key, val)
    rawget(cls, '__dict')[key] = val
end

function class_mt.__call(cls,...)
    return cls:__new(...)
end

function class_mt.__tostring(cls)
    local _system = _register_class[cls]
    if _system.__name then
        return string.format('class(%s)', _system.__name)
    else
        return string.format('class(%s)', _system.__addr)
    end
end

local instance_mt = {}

if not _STD_CLASS_DEBUG then
    instance_mt.__metatable = 'protected'
end

instance_mt.__index = _lookup_object_attr

function instance_mt.__newindex(obj, key, value)
    rawget(obj, '__dict')[key] = value
end

local function _object_tostring(obj)
    local _system = _register_object[obj]
    if _system.__name then
        return string.format('object(%s)', _system.__name)
    else
        return string.format('object(%s)', _system.__addr)
    end
end

local function _check_final(cls)
    if _register_class[cls].__final then
        raise(exception.TypeError('class is final'))
    end
end

local function _compute_mro(mro, cls, parent, base_object)
    mro[1] = cls
    if not base_object then
        for i, b in ipairs(_register_class[parent].__mro) do
            mro[i+1] = b
        end
    end
end

local function _new_class(name, parent, dict, opts)
    opts = opts or {}
    if parent ~= nil then
        _check_final(parent)
    elseif not opts.base_object then
        parent = M.object
    end
    local mro = setmetatable({}, {__mode = 'v'})
    local cls = {
        __name = name,
        __mro = mro,
        __parent = parent,
        __dict = dict or {}
    }
    _compute_mro(mro, cls, parent, opts.base_object)
    _register_cls(cls, mro, parent, opts)
    return setmetatable(cls, class_mt)
end

---@class _class_meta : table
---@field __gc? fun(self:self)
---@field __tostring fun(self:self):string
---@field __add? fun(self:self, other):any
---@field __sub? fun(self:self, other):any
---@field __mul? fun(self:self, other):any
---@field __div? fun(self:self, other):any
---@field __mod? fun(self:self, other):any
---@field __pow? fun(self:self, other):any
---@field __unm? fun(self:self):any
---@field __concat? fun(self:self, other):any
---@field __lt? fun(self:self, other):boolean
---@field __le? fun(self:self, other):boolean
---@field __len? fun(self:self):int
---@field __eq? fun(self:self, other):any
---@field __pairs? fun(self:self):((fun(self:self, k, v): any, any), any, any)
---@field __idiv? fun(self:self, other):any
---@field __band? fun(self:self, other):any
---@field __bor? fun(self:self, other):any
---@field __bxor? fun(self:self, other):any
---@field __bnot? fun(self:self):any
---@field __shl? fun(self:self, other):any
---@field __shr? fun(self:self, other):any
---@field __close? fun(self:self, error_obj):any

---@class class : _class_meta
---@field __name string
---@field __parent class
---@field __dict table<string, any>
---@field __call fun(self: self, ...:any...): object
---@overload fun(self: self, ...:any...): object

---@class object : class
---@field __name string
---@field __class class
---@field __new fun(cls: class): self
local object = _new_class('object', nil, {}, {base_object=true})

---@param cls class
local function _check_abstract(cls)
    if _register_class[cls].__abstract then
        raise(exception.TypeError('class is abstract'))
    end
end

local function _collect_class_metatable(cls)
    local t = {}
    for _, name in ipairs(meta_names) do
        local v = _lookup_class_attr(cls, name)
        if v ~= nil then
            t[name] = v
        end
    end
    return t
end

---@return object
local function _new_object(cls)
    _check_abstract(cls)
    local obj = {
        __name = cls.__name,
        __class = cls,
        __dict = {},
    }
    if _register_class[cls].__metatable == nil then
        local mt = _collect_class_metatable(cls)
        for k, v in pairs(instance_mt) do
            mt[k] = v
        end
        -- set default __tostring
        if mt['__tostring'] == nil then
            mt['__tostring'] = _object_tostring
        end
        _register_class[cls].__metatable = mt
    end
    _register_obj(obj, cls)
    return setmetatable(obj, _register_class[cls].__metatable)
end

function object:__new(...)
    local obj = _new_object(self)
    obj:__init(...)
    return obj
end

function object:__init(...) end

-- Note: `__del` do not set the GC hook, just delete object reference from register table
--       need rename ?
-- function object:__del(...)
--     _register_object[self] = nil
-- end

---@generic T, B: object
---@[constructor('__init', 'object')]
---@param name `T`
---@param parent? B
---@param dict? table<string, any>
---@return T
function M.new(name, parent, dict)
    return _new_class(name, parent, dict)
end

function M.new_abstract(name, parent)
    return _new_class(name, parent, {}, {abstract = true})
end

function M.new_final(name, parent)
    return _new_class(name, parent, {}, {final = true})
end

---@param obj any
---@param kind 'object'|'class'?
---@overload fun(obj: any): 'object'|'class'?
---@overload fun(obj: any, kind: 'object'|'class'): boolean
function M.kindof(obj, kind)
    if _register_object[obj] then
        if kind then
            return 'object' == kind
        else
            return 'object'
        end
    elseif _register_class[obj] then
        if kind then
            return 'class' == kind
        else
            return 'class'
        end
    else
        return nil
    end
end

function M.isabstract(cls)
    local _sys = _register_class[cls]
    if _sys == nil then
        raise(exception.TypeError(string.format('class %s is not a class type', cls)))
    end
    return _sys.__abstract
end

function M.isfinal(cls)
    local _sys = _register_class[cls]
    if _sys == nil then
        raise(exception.TypeError(string.format('class %s is not a class type', cls)))
    end
    return _sys.__final
end

---@generic T: class
---@param cls T
---@param clsinfo T
---@return boolean
function M.issubclass(cls, clsinfo)
    if not M.kindof(cls, 'class') then
        raise(exception.TypeError('cls must be a class type'))
    end
    if not M.kindof(clsinfo, 'class') then
        raise(exception.TypeError('clsinfo must be a class type'))
    end
    if cls == clsinfo then
        return true
    end

    local mro = _register_class[cls].__mro
    for i = 1, #mro do
        if mro[i] == clsinfo then
            return true
        end
    end
    return false
end

---@generic T: class
---@param obj any
---@param cls T|[T...]
---@return TypeGuard<T>
---@overload fun(obj: any, cls: T): TypeGuard<T>
---@overload fun(obj: any, cls: [T...]): TypeGuard<T...>
function M.isinstance(obj, cls)
    if not M.kindof(obj, 'object') then
        return false
    end
    local obj_cls = _register_object[obj].__class
    if M.kindof(cls) == nil then
        ---@cast cls [T...]
        for _, c in ipairs(cls) do
            if M.issubclass(obj_cls, c) then
                return true
            end
        end
        return false
    else
        ---@cast cls T
        return M.issubclass(obj_cls, cls)
    end
end

---@diagnostic disable-next-line: unused
---@generic T : class
---@param cls any
---@param obj any
---@param target_type T
---@return T
local function _super_proxy(cls, obj, target_type)
    local self = obj or cls -- if obj is nil, then cls is the target class
    local proxy
    local mt = {
        __index = function(_, k)
            local v = cls[k]
            if type(v) == 'function' then
                return function(arg1,...)
                    if arg1 == proxy then
                        return v(self,...)
                    else
                        return v(arg1,...)
                    end
                end
            end
            return v
        end,
        __newindex = function(...)
            raise(exception.TypeError('cannot modify super class'))
        end
    }
    if not _STD_CLASS_DEBUG then
        mt.__metatable = 'protected'
    end
    proxy = setmetatable({}, mt) --[[@as T]]
    return proxy
end

-- Note: `super` returns a proxy type, not class type.
---@generic R extends class
---@generic T extends R
---@param cls T
---@param obj_or_cls? object|class
---@param target_type R? only for type check
---@return R
function M.super(cls, obj_or_cls, target_type)
    if not M.kindof(cls, 'class') then
        raise(exception.TypeError('cls must be a class type'))
    end
    if cls == object then
        raise(exception.TypeError('object has no super class'))
    end

    local obj
    local target_mro
    if obj_or_cls ~= nil then
        local kind = M.kindof(obj_or_cls)
        if kind == 'object' then
            obj = obj_or_cls
            target_mro = _register_class[_register_object[obj_or_cls].__class].__mro
        elseif kind == 'class' then
            target_mro = _register_class[obj_or_cls].__mro
        else
            raise(exception.TypeError('obj_or_cls must be an object or class'))
        end
    else
        target_mro = _register_class[cls].__mro
    end

    local len = #target_mro
    for i, base in ipairs(target_mro) do
        if base == cls then
            if i < len then
                return _super_proxy(target_mro[i+1], obj, target_type--[[@cast -?]])
            end
            raise(exception.TypeError(string.format('%s has no super class in target hierarchy', tostring(cls))))
        end
    end

    raise(exception.TypeError(string.format('%s is not in target hierarchy', tostring(cls))))
end

M.object = object

local _M_mt = {__call = M.new}
if not _STD_CLASS_DEBUG then
    _M_mt.__metatable = 'protected'
end
---@type classlib
local _M = setmetatable(M, _M_mt)
return _M
