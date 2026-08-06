-- std.class.lua
-- This file is part of the standard library of the libsElx library.

local exception = require("elxlibs.std.exception")

---@class std.class
local M = {}

---@alias __system_class_fields {
---     __system: {
---         __type: "class",
---         __name: string,
---         __abstract: boolean,
---         __final: boolean,
---         __bases: std.Class[],
---         __mro: std.Class[],
---         __addr: string,
---     }
--- }
---@alias __system_object_fields {
---     __system: {
---         __type: "object",
---         __class: std.Class,
---         __addr: string,
---     }
--- }

-- _register is an ownership table for reflection metadata.
-- As long as class/object (key) is alive, its metadata (value) must stay alive.
-- Therefore: weak keys, strong values.
---@type {class: table<std.object|std.Class,__system_class_fields>, object: table<std.object|std.Class,__system_object_fields>}
local _register = {
    class =  setmetatable({}, {__mode = "k"}),
    object = setmetatable({}, {__mode = "k"}),
}

local function _register_cls(cls, bases, mro, opts)
    _register.class[cls] = {
        __system = {
            __type = "class",
            __name = cls.__name,
            __abstract = opts and opts.abstract or false,
            __final = opts and opts.final or false,
            __bases = bases,
            __mro = mro,
            __addr = tostring(cls), -- Note: here cls's metatable is not yet set, 
                                    --       so here is cls's real address string.
        }
    }
end

local function _register_obj(obj, cls)
    _register.object[obj] = {
        __system = {
            __type = "object", 
            __class = cls, 
            __addr = tostring(obj)
        }
    }
end

local function _lookup_class_attr(cls, key)
    local dict = rawget(cls, "__dict")
    if dict then
        local v = dict[key]
        if v ~= nil then
            return v
        end
    end

    local mro = rawget(cls, "__mro")
    if mro then
        for i = 2, #mro do
            local base_dict = rawget(mro[i], "__dict")
            if base_dict then
                local v = base_dict[key]
                if v ~= nil then
                    return v
                end
            end
        end
    end
end

local function _lookup_object_attr(obj, key)
    local dict = rawget(obj, "__dict")
    if dict then
        local v = dict[key]
        if v ~= nil then
            return v
        end
    end

    local cls = rawget(obj, "__class")
    if cls then
        return _lookup_class_attr(cls, key)
    end
end

local function _lookup_meta_method(self, name)
    if _register.object[self] then
        return _lookup_object_attr(self, name)
    elseif _register.class[self] then
        return _lookup_class_attr(self, name)
    end
end

local function _meta_wrap(name, fn)
    return function(self,...)
        local v = _lookup_meta_method(self, name)
        if v ~= nil then
            return v(self,...)
        end
        if fn then
            return fn(self,...)
        end
        exception.raise(exception.AttributeError(string.format("%s has no meta method '%s'", tostring(self), name)))
    end
end

local function __tostring(t)
    local kind = M.kindof(t)
    local _system
    if kind == "class" then
        _system = _register.class[t].__system
    else
        _system = _register.object[t].__system
    end
    if _system.__name then
        return string.format("%s: %s", kind, _system.__name)
    else
        return string.format("%s: %s", kind, _system.__addr)
    end
end

local META_RUNTIME = {
    __tostring = _meta_wrap("__tostring", __tostring),
    __add      = _meta_wrap("__add"),
    __sub      = _meta_wrap("__sub"),
    __mul      = _meta_wrap("__mul"),
    __div      = _meta_wrap("__div"),
    __mod      = _meta_wrap("__mod"),
    __pow      = _meta_wrap("__pow"),
    __unm      = _meta_wrap("__unm"),
    -- Lua 5.3+ ----------------------------
    __idiv     = _meta_wrap("__idiv"),
    __band     = _meta_wrap("__band"),
    __bor      = _meta_wrap("__bor"),
    __bxor     = _meta_wrap("__bxor"),
    __bnot     = _meta_wrap("__bnot"),
    __shl      = _meta_wrap("__shl"),
    __shr      = _meta_wrap("__shr"),
    ----------------------------------------
    __concat   = _meta_wrap("__concat"),
    __len      = _meta_wrap("__len"),
        -- function(self)        return rawlen(self) end), -- Lua 5.2+
    __eq       = _meta_wrap("__eq",  function(self, other) return rawequal(self, other) end),
    __lt       = _meta_wrap("__lt"),
    __le       = _meta_wrap("__le"),
}

------------------------------------------------------------------
-- Metatable defines the behavior of the class and its instances.
------------------------------------------------------------------

local class_mt = {}

if not _G._STD_CLASS_DEBUG then
    class_mt.__metatable = "protected"
end

function class_mt.__index(cls, key)
    return _lookup_class_attr(cls, key)
end

function class_mt.__newindex(cls, key, val)
    rawget(cls, "__dict")[key] = val
end

function class_mt.__call(cls,...)
    local class_call = _lookup_class_attr(cls, "__call")
    if class_call ~= nil then
        return class_call(cls,...)
    end
    return cls:__new(...)
end

do
    for k, v in pairs(META_RUNTIME) do
        class_mt[k] = v
    end
end

local instance_mt = {}

if not _G._STD_CLASS_DEBUG then
    instance_mt.__metatable = "protected"
end

function instance_mt.__index(obj, key)
    return _lookup_object_attr(obj, key)
end

function instance_mt.__newindex(obj, key, value)
    rawget(obj, "__dict")[key] = value
end

function instance_mt.__call(obj,...)
    local obj_call = _lookup_object_attr(obj, "__call")
    if obj_call ~= nil then
        return obj_call(obj,...)
    end
    exception.raise(exception.TypeError(string.format("%s object is not callable", tostring(obj))))
end

do
    for k, v in pairs(META_RUNTIME) do
        instance_mt[k] = v
    end
end


local function _c3_mro_merge(seqs)
    local result = {}
    while true do
        local candidate = nil
        for _, seq in ipairs(seqs) do
            if #seq > 0 then
                local first = seq[1]
                local valid = true
                
                for _, other_seq in ipairs(seqs) do
                    for i = 2, #other_seq do
                        if other_seq[i] == first then
                            valid = false
                            break
                        end
                    end
                    if not valid then break end
                end
                
                if valid then
                    candidate = first
                    break
                end
            end
        end
        
        if not candidate then
            exception.raise(exception.TypeError("Inconsistent hierarchy"))
        end
        
        table.insert(result, candidate)
        
        for _, seq in ipairs(seqs) do
            if #seq > 0 and seq[1] == candidate then
                table.remove(seq, 1)
            end
        end
        
        local i = 1
        while i <= #seqs do
            if #seqs[i] == 0 then
                table.remove(seqs, i)
            else
                i = i + 1
            end
        end
        
        if #seqs == 0 then
            break
        end
    end
    return result
end
local function _copy_list(t)
    local r = {}
    for i = 1, #t do r[i] = t[i] end
    return r
end
local function _c3_get_mro(cls)
    if cls.__mro then
        return cls.__mro
    end
    local bases = cls.__bases
    local seqs = {}
    for _, base in ipairs(bases) do
        table.insert(seqs, _copy_list(_c3_get_mro(base)))
    end
    table.insert(seqs, bases)
    local mro = _c3_mro_merge(seqs)
    if mro[1] ~= cls then
        table.insert(mro, 1, cls)
    end
    return mro
end
local function _compute_c3_mro(cls)
    return _c3_get_mro(cls)
end

-- local function _create_gc_sentinel(obj)
--     -- luajit / lua 5.1
--     local ud = newproxy(true)

--     local mt = getmetatable(ud)

--     mt.__gc = function()
--         _register.object[obj] = nil

--         local dict = rawget(obj, "__dict")
--         local gc_fn = dict and dict.__gc
--         if type(gc_fn) == "function" then
--             pcall(gc_fn, obj)
--         end
--     end

--     return ud
-- end

local function _check_final(cls)
    if _register.class[cls].__system.__final then
        exception.raise(exception.TypeError("class is final"))
    end
end

local function _new_class(name, bases, dict, opts)
    opts = opts or {}
    if bases and #bases > 0 then
        for _, base in ipairs(bases) do
            _check_final(base)
        end
    end
    if bases ~= nil and #bases == 0 then
        table.insert(bases, M.object)
    elseif bases == nil then
        bases = {M.object}
    end
    local cls = {
        __name = name,
        __bases = bases,
        __dict = dict or {}
    }
    if opts.base_object then
        cls.__mro = {cls}
    else
        cls.__mro = _compute_c3_mro(cls)
    end
    _register_cls(cls, cls.__bases, cls.__mro, opts)
    return setmetatable(cls, class_mt)
end

---@class std.object : table
---@field __init fun(self: std.Class,...)
---@field __new  fun(self: std.Class,...): std.object
---@field __call fun(self: std.Class,...): std.object
---@overload fun(self: std.Class,...): std.object
local object = _new_class("object", {}, {}, {base_object=true})

---@class std._ClassType : std.object
---@alias std.Class std._ClassType
---@description Type of class objects.

local function _check_abstract(cls)
    if _register.class[cls].__system.__abstract then
        exception.raise(exception.TypeError("class is abstract"))
    end
end

---@return std.Class
local function _new_object(cls,...)
    _check_abstract(cls)
    local obj = {
        __name = cls.__name,
        __class = cls,
        __dict = {},
    }
    _register_obj(obj, cls)
    return setmetatable(obj, instance_mt)
end

function object:__new(...)
    local obj = _new_object(self,...)
    obj:__init(...)
    return obj
end

function object:__init(...) end

-- Note: `__del` do not set the GC hook, just delete object reference from register table
--       need rename ?
-- function object:__del(...)
--     _register.object[self] = nil
-- end

function M.new(name, bases, dict)
    return _new_class(name, bases, dict)
end

function M.new_abstract(name, bases)
    return _new_class(name, bases, {}, {abstract = true})
end

function M.new_final(name, bases)
    return _new_class(name, bases, {}, {final = true})
end

local function _super_proxy(cls, obj)
    local self = obj or cls -- if obj is nil, then cls is the target class
    local mt = {
        __index = function(_, k)
            local v = cls[k]
            if type(v) == "function" then
                return function(_,...)
                    return v(self,...)
                end
            end
            return v
        end,
        __newindex = function(...)
            exception.raise(exception.TypeError("cannot modify super class"))
        end
    }
    if not _G._STD_CLASS_DEBUG then
        mt.__metatable = "protected"
    end
    return setmetatable({}, mt)
end

-- Note: `super` returns a proxy type, not class type.
---@generic T: std.object
---@param cls T
---@param obj_or_cls? std.object|std.Class
---@return any
function M.super(cls, obj_or_cls)
    if not M.kindof(cls, "class") then
        exception.raise(exception.TypeError("cls must be a class type"))
    end
    if cls == object then
        exception.raise(exception.TypeError("object has no super class"))
    end

    ---@type std.Class[]
    local target_mro
    local obj
    if obj_or_cls ~= nil then
        local kind = M.kindof(obj_or_cls)
        if kind == "object" then
            obj = obj_or_cls
            target_mro = _register.class[_register.object[obj_or_cls].__system.__class].__system.__mro
        elseif kind == "class" then
            target_mro = _register.class[obj_or_cls].__system.__mro
        else
            exception.raise(exception.TypeError("obj_or_cls must be an object or class"))
        end
    else
        target_mro = _register.class[cls].__system.__mro
    end

    local len = #target_mro
    for i, base in ipairs(target_mro) do
        if base == cls then
            if i < len then
                return _super_proxy(target_mro[i+1], obj)
            end
            exception.raise(exception.TypeError(string.format("%s has no super class in target hierarchy", tostring(cls))))
        end
    end

    exception.raise(exception.TypeError(string.format("%s is not in target hierarchy", tostring(cls))))
end

function M.kindof(obj, kind)
    if type(obj) ~= "table" then
        exception.raise(exception.TypeError("object must be a table"))
    end
    if _register.object[obj] then
        local typ = _register.object[obj].__system.__type
        if kind then
            return typ == kind
        else
            return typ
        end
    elseif _register.class[obj] then
        local typ = _register.class[obj].__system.__type
        if kind then
            return typ == kind
        else
            return typ
        end
    else
        return nil
    end
end

function M.isabstract(cls)
    if type(cls) ~= "table" then
        exception.raise(exception.TypeError("class must be a table"))
    end
    if not _register.class[cls] then
        exception.raise(exception.TypeError("class is not a class type"))
    end
    return _register.class[cls].__system.__abstract
end

function M.isfinal(cls)
    if type(cls) ~= "table" then
        exception.raise(exception.TypeError("class must be a table"))
    end
    if not _register.class[cls] then
        exception.raise(exception.TypeError("class is not a class type"))
    end
    return _register.class[cls].__system.__final
end

---@generic T: std.object
---@param cls T
---@param clsinfo T
---@return boolean
function M.issubclass(cls, clsinfo)
    if not M.kindof(cls, "class") then
        exception.raise(exception.TypeError("cls must be a class type"))
    end
    if not M.kindof(clsinfo, "class") then
        exception.raise(exception.TypeError("clsinfo must be a class type"))
    end
    if cls == clsinfo then
        return true
    end

    local mro = _register.class[cls].__system.__mro
    for i = 1, #mro do
        if mro[i] == clsinfo then
            return true
        end
    end
    return false
end

---@generic T: std.object
---@param obj T
---@param cls T|T[]
---@return boolean
function M.isinstance(obj, cls)
    if not M.kindof(obj, "object") then
        exception.raise(exception.TypeError("expected an object"))
    end
    local obj_cls = _register.object[obj].__system.__class
    if M.kindof(cls) == nil then
        for _, c in ipairs(cls) do
            if M.issubclass(obj_cls, c) then
                return true
            end
        end
        return false
    end
    return M.issubclass(obj_cls, cls)
end


M.object = object

local _M_mt = {__call = M.new}
if not _G._STD_CLASS_DEBUG then
    _M_mt.__metatable = "protected"
end
---@type std.class
local _M = setmetatable(M, _M_mt)
return _M
