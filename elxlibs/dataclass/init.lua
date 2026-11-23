-- Independent data classes for LuaJIT; methods are shared by each class.
---@namespace dataclass

local unpack_values = unpack
local setmetatable = setmetatable
local error = error
local type = type
local pairs = pairs
local tostring = tostring
local rawequal = rawequal
local select = select
local rawget = rawget
local ipairs = ipairs
local assert = assert
local rawset = rawset
local getmetatable = getmetatable
local pcall = pcall
local string = string
local table = table

---@class dataclass
local M = {}

---@class Sentinel
local function sentinel(name)
    return setmetatable({}, { __tostring = function () return name end })
end

M.MISSING = sentinel('dataclass.MISSING')
M.NIL = sentinel('dataclass.NIL')

---@class FieldOptions
---@field default   any?
---@field factory   (fun(): any)?
---@field init      boolean?
---@field eq        boolean?
---@field order     boolean?
---@field repr      boolean?
---@field converter (fun(value: any): any)?
---@field validator (fun(self: Object, field: Field, value: any))?
---@field metadata  table?

---@class Field
---@field name      string
---@field default   any
---@field factory   (fun(): any)?
---@field init      boolean
---@field eq        boolean
---@field order     boolean
---@field repr      boolean
---@field converter (fun(value: any): any)?
---@field validator (fun(self: Object, field: Field, value: any))?
---@field metadata  table?
---@field __type    'dataclass.Field'

---@class Options
---@field frozen     boolean? default to `false`
---@field eq         boolean? default to `true`
---@field order      boolean? default to `false`
---@field kw_init    boolean? default to `false`
---@field repr       boolean? default to `true`
---@field init       boolean? default to `nil`
---@field dict       boolean? default to `false`; frozen also selects dict storage without changing this option
---@field fields_set boolean? default to `false`; expose ordered field names on the class

---@class Object
---@field __class          Class
---@field __dict           table<string, any>?       Dict backing storage; raw access is trusted.
---@field __dataclass_init fun(self: self, ...: any)
---@field __pre_init       (fun(self: self))?
---@field __post_init      (fun(self: self))?
---@field __fields_set     (string[])?

---@class Class
---@field __name           string
---@field __parent         Class?
---@field __dataclass      State
---@field __dataclass_init (fun(self: Object, ...: any))?
---@field __init           (fun(self: Object, ...: any))?
---@field __new            (fun(cls: Class, ...: any): Object)?
---@field __fields_set     (string[])?
---@field [string]         any
---@overload fun(...: any): Object

---@class State
---@field fields            Field[]
---@field by_name           table<string, Field>
---@field inputs            Field[]
---@field opts              Options
---@field finished          boolean
---@field mutable_mt        table?
---@field mutable_mt_getter (fun(): table)?
---@field frozen_mt         table?
---@field frozen_mt_getter  (fun(): table)?
---@field initializer       (fun(self: Object, ...: any))?
---@field allocator         (fun(cls: Class, ...: any): Object)?
---@field allocate          (fun(): Object)?
---@field constructor       (fun(cls: Class, ...: any): Object)?
---@field generated_eq      function?
---@field generated_lt      function?
---@field generated_le      function?
---@field less              function?
---@field less_equal        function?

local field_keys = {
    default = true,
    factory = true,
    init = true,
    eq = true,
    order = true,
    repr = true,
    converter = true,
    validator = true,
    metadata = true
}
local option_keys = {
    frozen = true, eq = true, order = true, kw_init = true, repr = true, init = true,
    dict = true, fields_set = true
}

local function fail(message)
    error('dataclass: ' .. message, 3)
end

local raise = fail

---@generic T: table
---@param t T
---@return T
local function copy(t)
    local result = {}
    for k, v in pairs(t) do
        result[k] = v
    end
    return result
end

local function check_options(opts, allowed)
    if type(opts) ~= 'table' then
        raise('options must be a table')
    end
    for k in pairs(opts) do
        if not allowed[k] then
            raise('unknown option ' .. tostring(k))
        end
    end
end

local function boolean_option(opts, key, default)
    local value = opts[key]
    if value == nil then
        return default
    end
    if type(value) ~= 'boolean' then
        raise(key .. ' must be a boolean')
    end
    return value
end

local function decode_nil(value)
    if rawequal(value, M.NIL) then
        return nil
    end
    return value
end

--- Omitted default is required; an explicitly passed nil is a nil default.
---@param name string
---@param ...  any
---@return Field
local function new_field(name, ...)
    if type(name) ~= 'string' or name == '' or name:sub(1, 2) == '__' then
        raise('field name must be nonempty and must not begin with __')
    end
    local count = select('#', ...)
    if count > 2 then
        raise('field accepts default and options only')
    end
    local value, supplied_opts = ...
    local opts = supplied_opts
    if opts == nil then
        opts = {}
    end
    check_options(opts, field_keys)
    local has_default = rawget(opts, 'default') ~= nil
    if has_default and opts.factory ~= nil then
        raise('default and factory conflict for ' .. name)
    end
    if value ~= nil and (has_default or opts.factory ~= nil) then
        raise('duplicate default for ' .. name)
    end
    for _, key in ipairs({ 'factory', 'converter', 'validator' }) do
        if opts[key] ~= nil and type(opts[key]) ~= 'function' then
            raise(key .. ' must be a function')
        end
    end
    if opts.metadata ~= nil and type(opts.metadata) ~= 'table' then
        raise('metadata must be a table')
    end
    local default = M.MISSING
    if has_default then
        default = decode_nil(opts.default)
    elseif count > 0 and opts.factory == nil then
        default = decode_nil(value)
    end
    local eq = boolean_option(opts, 'eq', true)
    return {
        __type = 'dataclass.Field',
        name = name,
        default = default,
        factory = opts.factory,
        init = boolean_option(opts, 'init', true),
        eq = eq,
        order = boolean_option(opts, 'order', eq),
        repr = boolean_option(opts, 'repr', true),
        converter = opts.converter,
        validator = opts.validator,
        metadata = opts.metadata
    }
end

-- The implementation needs varargs to distinguish omitted and explicit nil defaults.
---@type fun(name: string, default?: any, opts?: FieldOptions): Field
M.field = new_field

---@param value any
---@return boolean
function M.isclass(value)
    return type(value) == 'table' and type(rawget(value, '__dataclass')) == 'table'
        and type(rawget(value, '__name')) == 'string'
end

---@param cls Class
---@return State
local function state_of(cls)
    if not M.isclass(cls) then
        raise('expected a dataclass class')
    end
    return rawget(cls, '__dataclass')
end

---@param value any
---@return Class?
local function class_of(value)
    if type(value) ~= 'table' then
        return nil
    end
    local cls = rawget(value, '__class')
    if M.isclass(cls) then
        return cls
    end
end

---@param value any
---@return Class
local function require_instance(value)
    local cls = class_of(value)
    if cls == nil then
        raise('expected a dataclass instance')
    end
    return cls
end

---@param cls    table
---@param parent table
---@return boolean
function M.issubclass(cls, parent)
    state_of(cls)
    state_of(parent)
    while cls do
        if rawequal(cls, parent) then
            return true
        end
        cls = rawget(cls, '__parent')
    end
    return false
end

---@param value any
---@param cls   table
---@return boolean
function M.isinstance(value, cls)
    state_of(cls)
    local actual = class_of(value)
    return actual ~= nil and M.issubclass(actual, cls)
end

---@param self Object
local function dict_index(self, key)
    local dict = assert(rawget(self, '__dict'))
    local value = dict[key]
    if value ~= nil then
        return value
    end
    return rawget(self, '__class')[key]
end

---@param self Object
---@param key  string
---@param val  any
local function index_write(self, key, val)
    local dict = assert(rawget(self, '__dict'))
    rawset(dict, key, val)
end

local function frozen_write(_, key)
    raise('cannot assign frozen instance field ' .. tostring(key))
end

---@param self Object
local function data_of(self)
    return rawget(self, '__dict') or self
end

---@param cls    Class
---@param fields Field[]
local function schema(cls, fields)
    if type(fields) ~= 'table' then
        raise('fields must be an ordered array')
    end
    local count = 0
    for k in pairs(fields) do
        if type(k) ~= 'number' or k < 1 or k % 1 ~= 0 then
            raise('fields must be a dense ordered array')
        end
        count = count + 1
    end
    for i = 1, count do
        if rawget(fields, i) == nil then
            raise('fields must be a dense ordered array')
        end
    end
    local state = state_of(cls)
    local positions = {}
    local parent = rawget(cls, '__parent')
    if parent then
        for i, f in ipairs(state_of(parent).fields) do
            state.fields[i] = copy(f)
            positions[f.name] = i
        end
    end
    local own = {}
    for _, f in ipairs(fields) do
        if type(f) ~= 'table' or f.__type ~= 'dataclass.Field' then
            raise('expected Field declarations')
        end
        -- Revalidate caller-visible Field descriptors, then snapshot their configuration.
        local opts = copy(f)
        opts.name, opts.__type = nil, nil
        if f.factory ~= nil then
            if not rawequal(f.default, M.MISSING) then
                raise('default and factory conflict for ' .. f.name)
            end
            opts.default = nil
        end
        local checked = M.field(f.name, nil, opts)
        if own[f.name] then
            raise('duplicate field ' .. f.name)
        end
        own[f.name] = true
        local index = positions[f.name] or (#state.fields + 1)
        positions[f.name] = index
        state.fields[index] = checked
    end
    local saw_default = false
    for _, f in ipairs(state.fields) do
        state.by_name[f.name] = f
        if f.init then
            state.inputs[#state.inputs + 1] = f
            local required = rawequal(f.default, M.MISSING) and f.factory == nil
            if not state.opts.kw_init and required and saw_default then
                raise('required field follows default field: ' .. f.name .. '; use kw_init=true')
            end
            if not required then
                saw_default = true
            end
        end
    end
end

---@param field Field
local function default_value(field)
    if field.factory then
        return field.factory()
    end
    if not rawequal(field.default, M.MISSING) then
        return field.default
    end
    if field.init then
        raise('missing required field ' .. field.name)
    end
    return nil
end

---@param state State
local function check_named(state, values)
    if type(values) ~= 'table' then
        raise('named initialization requires a table')
    end
    for key in pairs(values) do
        local f = state.by_name[key]
        if not f then
            raise('unknown field ' .. tostring(key))
        end
        if not f.init then
            raise('field is not an init field: ' .. key)
        end
    end
end

---@param fields Field[]
local function make_fields_set(fields)
    local set = {}
    for i = 1, #fields do
        set[i] = fields[i].name
    end
    return set
end

---@param cls   Class
---@param state State
---@return fun(self: Object, ...: any)
local function make_initializer(cls, state)
    local pre, post = cls.__pre_init, cls.__post_init
    local keyword = state.opts.kw_init
    local fields = state.fields
    ---@type Field[]
    local validators = {}
    local field_count, input_count = #fields, #state.inputs
    for _, f in ipairs(fields) do
        if f.validator then
            validators[#validators + 1] = f
        end
    end
    return function (self, ...)
        local n = select('#', ...)
        local values
        if keyword then
            if n > 1 then
                raise('named initialization accepts one table')
            end
            values = n == 0 and {} or (...)
            check_named(state, values)
        else
            if n > input_count then
                raise('too many positional arguments')
            end
            values = { ... }
        end
        if pre then
            pre(self)
        end
        local data = data_of(self)
        local index = 0
        for i = 1, field_count do
            local f = fields[i] --[[@as Field]] -- Dense schema was validated at definition.
            local value, present
            if f.init then
                index = index + 1
                if keyword then
                    value = rawget(values, f.name)
                    present = value ~= nil and not rawequal(value, M.MISSING)
                else
                    value = values[index]
                    present = index <= n and not rawequal(value, M.MISSING)
                end
            end
            if present then
                value = decode_nil(value)
            else
                value = default_value(f)
            end
            if f.converter then
                value = f.converter(value)
            end
            rawset(data, f.name, value)
        end
        for _, f in ipairs(validators) do
            assert(f.validator)(self, copy(f), data[f.name])
        end
        if post then
            post(self)
        end
    end
end

---@param cls   Class
---@param state State
local function make_eq(cls, state)
    return function (a, b)
        if not rawequal(class_of(a), cls) or not rawequal(class_of(b), cls) then
            return false
        end
        for _, f in ipairs(state.fields) do
            if f.eq and a[f.name] ~= b[f.name] then
                return false
            end
        end
        return true
    end
end

---@param cls   Class
---@param state State
local function make_order(cls, state, inclusive)
    return function (a, b)
        if not rawequal(class_of(a), cls) or not rawequal(class_of(b), cls) then
            raise('ordering requires instances of the same class')
        end
        for _, f in ipairs(state.fields) do
            if f.order then
                local x, y = a[f.name], b[f.name]
                if x ~= y then
                    return x < y
                end
            end
        end
        return inclusive
    end
end

-- LuaJIT requires the same order metamethod on both operands before dispatch.
local function generated_less(a, b)
    local cls = require_instance(a)
    return assert(state_of(cls).less)(a, b)
end

local function generated_less_equal(a, b)
    local cls = require_instance(a)
    return assert(state_of(cls).less_equal)(a, b)
end

---@param cls   Class
---@param state State
local function make_repr(cls, state)
    local active = {}
    local function render(self)
        local parts = {}
        for _, f in ipairs(state.fields) do
            if f.repr then
                local v = self[f.name]
                local text = type(v) == 'string' and string.format('%q', v) or tostring(v)
                parts[#parts + 1] = f.name .. '=' .. text
            end
        end
        return cls.__name .. '(' .. table.concat(parts, ', ') .. ')'
    end
    return function (self)
        if active[self] then
            return '...'
        end
        active[self] = true
        local ok, result = pcall(render, self)
        active[self] = nil
        if not ok then
            error(result, 0)
        end
        return result
    end
end

local metamethods = {
    '__tostring', '__add', '__sub', '__mul', '__div', '__mod', '__pow', '__unm', '__concat', '__lt', '__le', '__len',
    '__call', '__eq'
}

---@param cls Class
local function custom_meta(cls, key)
    while cls do
        local value = rawget(cls, key)
        local state = state_of(cls)
        if value ~= nil and value ~= state.generated_eq and value ~= state.generated_lt and value ~= state.generated_le then
            return value
        end
        cls = rawget(cls, '__parent')
    end
end

---@param cls  Class
---@param mt   table
---@param dict boolean?
local function make_allocator(cls, mt, dict)
    if dict then
        return function ()
            return setmetatable({ __class = cls, __dict = {} }, mt)
        end
    end
    return function ()
        return setmetatable({ __class = cls }, mt)
    end
end

---@param cls         Class
---@param allocate    fun(): Object
---@param init        fun(self: Object, ...: any)
---@param custom_new? fun(cls: Class, ...: any): Object
local function make_constructor(cls, allocate, init, custom_new)
    if custom_new then
        return function (_, ...)
            local self = custom_new(cls, ...)
            if not rawequal(class_of(self), cls) then
                raise('__new must return an instance of its class')
            end
            init(self, ...)
            return self
        end
    end
    return function (_, ...)
        local self = allocate()
        init(self, ...)
        return self
    end
end

local function_check_fields = { '__pre_init', '__post_init', '__new', '__init' }

---@generic T: Class
---@param cls   T
---@param state State?
---@return T
local function _finish(cls, state)
    state = state or state_of(cls)
    if state.finished then
        return cls
    end

    for _, key in ipairs(function_check_fields) do
        if cls[key] ~= nil and type(cls[key]) ~= 'function' then
            raise(key .. ' must be a function')
        end
    end

    local opts = state.opts
    local own_init = rawget(cls, '__init') --[[@as (fun(self:Object, ...:any))?]]
    if opts.init == true and own_init then
        raise('init=true conflicts with custom __init')
    end
    local init = make_initializer(cls, state)
    local selected_init = init
    if opts.init == false or (opts.init == nil and own_init) then
        selected_init = own_init or function () end
    end

    local mt = {}
    for _, key in ipairs(metamethods) do
        local value = custom_meta(cls, key)
        if value ~= nil then
            if type(value) ~= 'function' then
                raise(key .. ' must be a function')
            end
            mt[key] = value
        end
    end
    if opts.eq then
        if mt.__eq then
            raise('eq=true conflicts with custom __eq; use eq=false')
        end
        mt.__eq = make_eq(cls, state)
    end
    if opts.order then
        if mt.__lt or mt.__le then
            raise('order=true conflicts with custom ordering')
        end
        mt.__lt, mt.__le = generated_less, generated_less_equal
    end
    if opts.repr and not mt.__tostring then
        mt.__tostring = make_repr(cls, state)
    end

    if opts.frozen then
        mt.__index = dict_index
        mt.__newindex = frozen_write
        state.frozen_mt = mt
        state.mutable_mt_getter = function ()
            local mt_ = copy(state.frozen_mt)
            mt_.__index = dict_index
            mt_.__newindex = index_write
            return mt_
        end
    else
        mt.__index = opts.dict and dict_index or cls
        mt.__newindex = opts.dict and index_write or nil
        state.mutable_mt = mt
        state.frozen_mt_getter = function ()
            local mt_ = copy(state.mutable_mt)
            mt_.__index = dict_index
            mt_.__newindex = frozen_write
            return mt_
        end
    end

    state.initializer = selected_init
    state.allocator = cls.__new
    state.generated_eq = opts.eq and mt.__eq or nil
    state.generated_lt = opts.order and mt.__lt or nil
    state.generated_le = opts.order and mt.__le or nil
    if opts.order then
        state.less = make_order(cls, state, false)
        state.less_equal = make_order(cls, state, true)
    end
    rawset(cls, '__dataclass_init', init)
    if selected_init == init then
        rawset(cls, '__init', init)
    end
    if state.generated_eq then
        rawset(cls, '__eq', state.generated_eq)
    end
    if state.generated_lt then
        rawset(cls, '__lt', state.generated_lt)
    end
    if state.generated_le then
        rawset(cls, '__le', state.generated_le)
    end
    if opts.fields_set then
        rawset(cls, '__fields_set', make_fields_set(state.fields))
    end

    local allocate = make_allocator(cls, mt, opts.dict or opts.frozen)
    state.allocate = allocate
    state.constructor = make_constructor(cls, allocate, selected_init, state.allocator)
    state.finished = true
    getmetatable(cls).__call = state.constructor
    return cls
end

--- Cache initializers and instance metamethods. Ordinary methods stay dynamic.
---@generic T: table
---@param cls T
---@return T
function M.finish(cls)
    return _finish(cls)
end

--- Allocate without initializing; intended for a custom __new.
---@generic T: table
---@param cls T
---@return T
function M.allocate(cls)
    local state = state_of(cls)
    _finish(cls, state)
    return assert(state.allocate)()
end

---@param cls Class
local function construct(cls, ...)
    local state = state_of(cls)
    _finish(cls, state)
    return assert(state.constructor)(cls, ...)
end

--- Define an independent class with an ordered Field array, then add shared methods.
---@generic T
---@param name    `T`
---@param parent? table
---@param opts?   Options
---@return fun(fields: Field[]): T
function M.new(name, parent, opts)
    if type(name) ~= 'string' or name == '' then
        raise('class name must be a nonempty string')
    end
    local parent_state = parent ~= nil and state_of(parent) or nil
    if opts == nil then
        opts = {}
    end
    check_options(opts, option_keys)
    local config = {
        frozen = boolean_option(opts, 'frozen', false) or (parent_state and parent_state.opts.frozen) or false,
        eq = boolean_option(opts, 'eq', true),
        order = boolean_option(opts, 'order', false),
        kw_init = boolean_option(opts, 'kw_init', false),
        repr = boolean_option(opts, 'repr', true),
        init = boolean_option(opts, 'init', nil),
        dict = boolean_option(opts, 'dict', false),
        fields_set = boolean_option(opts, 'fields_set', false)
    }
    if config.order and not config.eq then
        raise('order requires eq=true')
    end
    local used = false
    return function (fields)
        if used then
            raise('class definition builder has already been used')
        end
        ---@type Class
        local cls = {
            __name = name,
            __parent = parent,
            __dataclass = { fields = {}, by_name = {}, inputs = {}, opts = config, finished = false }
        }
        schema(cls, fields)
        used = true
        return setmetatable(cls, { __index = parent, __call = construct })
    end
end

--- Return shallow descriptor copies in constructor/declaration order.
---@param cls table
---@return Field[]
function M.fields(cls)
    local result = {}
    for i, f in ipairs(state_of(cls).fields) do
        result[i] = copy(f)
    end
    return result
end

---@param self table
---@return boolean
function M.isfrozen(self)
    local state = state_of(require_instance(self))
    return state.frozen_mt ~= nil and rawequal(getmetatable(self), state.frozen_mt)
end

--- Move raw public fields to frozen storage, preserving identity and nested values.
---@generic T: table
---@param self T
---@return T
function M.freeze(self)
    local state = state_of(require_instance(self))
    if state.frozen_mt ~= nil and rawequal(getmetatable(self), state.frozen_mt) then
        return self
    end
    if state.frozen_mt == nil then
        state.frozen_mt = assert(state.frozen_mt_getter)()
    end
    local dict = rawget(self, '__dict')
    if dict == nil then
        dict = {}
        for key, value in pairs(self) do
            if key ~= '__class' then
                dict[key] = value
            end
        end
        for key in pairs(dict) do
            rawset(self, key, nil)
        end
        rawset(self, '__dict', dict)
    end
    setmetatable(self, state.frozen_mt)
    return self
end

--- Shallow export of declared fields. keep_nil encodes nil as dataclass.NIL.
---@param self      table
---@param keep_nil? boolean
---@return table<string, any>
function M.asdict(self, keep_nil)
    local state = state_of(require_instance(self))
    local result = {}
    for _, f in ipairs(state.fields) do
        local value = self[f.name]
        if value == nil and keep_nil then
            value = M.NIL
        end
        result[f.name] = value
    end
    return result
end

--- Reconstruct with init fields and changes; converters, validators and hooks rerun.
---@generic T
---@param self     T
---@param changes? table<string, any>
---@return T
function M.replace(self, changes)
    local cls = require_instance(self)
    local state = state_of(cls)
    if changes == nil then
        changes = {}
    end
    check_named(state, changes)
    local values = {}
    for i, f in ipairs(state.inputs) do
        local value = rawget(changes, f.name)
        if value == nil then
            value = self[f.name]
        end
        if value == nil then
            value = M.NIL
        end
        if state.opts.kw_init then
            values[f.name] = value
        else
            values[i] = value
        end
    end
    if state.opts.kw_init then
        return cls(values)
    end
    return cls(unpack_values(values, 1, #state.inputs))
end

return M
