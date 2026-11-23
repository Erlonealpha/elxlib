-- Reflection and attribute tools; importing this module does not load std.class.
---@namespace std

local type = type
local rawget = rawget
local rawset = rawset
local pairs = pairs
local ipairs = ipairs
local error = error

---@class InspectClassInfo
---@field name string
---@field parent class?
---@field mro class[]
---@field options ClassOptions
---@field finished boolean
---@field storage ('direct'|'dict')?

---@class InspectCapabilities
---@field state_of fun(cls:any):_ClassState?
---@field finish fun(cls:class):_FinishedClassState
---@field getmetatable fun(value:any):table?
---@field fail fun(message:string)

---@class inspectlib
local M = {}

---@type InspectCapabilities?
local capabilities

local required_capabilities = {
    'state_of',
    'finish',
    'getmetatable',
    'fail',
}

--- Internal installation bridge. A successful installation is accepted once.
---@param name 'std.class'
---@param installed InspectCapabilities
function M.__install(name, installed)
    if name ~= 'std.class' or type(installed) ~= 'table' then
        error('inspect: invalid class capabilities', 2)
    end

    if capabilities then
        error('inspect: class capabilities already installed', 2)
    end

    for _, key in ipairs(required_capabilities) do
        if type(installed[key]) ~= 'function' then
            error('inspect: missing capability ' .. key, 2)
        end
    end

    capabilities = installed
end

---@return InspectCapabilities
local function installed()
    if not capabilities then
        error('inspect: std.class capabilities unavailable', 3)
    end

    return capabilities
end

local function copy_table(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

---@param cls class
---@return _ClassState
local function class_state(cls)
    local access = installed()
    local state = access.state_of(cls)

    if not state then
        access.fail('expected a class type')
        error('inspect: class error handler returned', 2)
    end

    return state
end

---@param obj object
---@return _FinishedClassState
local function object_state(obj)
    local access = installed()
    local cls = type(obj) == 'table' and rawget(obj, '__class')
    local state = access.state_of(cls)

    if not state then
        access.fail('expected a class instance')
        error('inspect: class error handler returned', 2)
    end

    if state.finished then
        return state --[[@as _FinishedClassState]]
    end

    return access.finish(state.cls)
end

--- A shallow snapshot; nested member values remain shared.
---@param cls class
---@return InspectClassInfo
function M.classinfo(cls)
    local state = class_state(cls)
    local storage

    if state.finished then
        storage = state.dict and 'dict' or 'direct'
    end

    return {
        name = rawget(cls, '__name'),
        parent = rawget(cls, '__parent'),
        mro = copy_table(rawget(cls, '__mro')),
        options = copy_table(state.opts),
        finished = state.finished,
        storage = storage,
    }
end

---@param cls class
---@param inherited boolean? Include parent members; default false.
---@return table<string, any>
function M.getmembers(cls, inherited)
    class_state(cls)

    local result = {}

    repeat
        for key, value in pairs(rawget(cls, '__dict')) do
            if result[key] == nil then
                result[key] = value
            end
        end

        cls = inherited and rawget(cls, '__parent') or nil
    until not cls

    return result
end

--- A copy of the actual metatable, with private State omitted.
---@param obj class|object
---@return table
function M.getmetatable(obj)
    local access = installed()

    local state = access.state_of(obj)
    if not state and type(obj) == 'table' then
        state = access.state_of(rawget(obj, '__class'))
    end

    if not state then
        access.fail('expected a class or instance')
        error('inspect: class error handler returned', 2)
    end

    local result = copy_table(access.getmetatable(obj))
    result.__class_state = nil

    return result
end

--- Ordinary Lua read, including custom hooks.
---@param obj object
---@param key any
---@return any
function M.getattr(obj, key)
    return obj[key]
end

--- Ordinary Lua write, including custom hooks.
---@param obj object
---@param key any
---@param value any
function M.setattr(obj, key, value)
    obj[key] = value
end

--- Default read: skip custom hooks, retain descriptor semantics.
---@param obj object
---@param key any
---@return any
function M.getattribute(obj, key)
    local state = object_state(obj)

    if key == '__class' or key == '__dict' then
        local structural = rawget(obj, key)

        if structural ~= nil then
            return structural
        end
    end

    return (state.read(obj, key))
end

--- Default write: skip custom hooks, retain descriptor semantics.
---@param obj object
---@param key any
---@param value any
function M.setattribute(obj, key, value)
    local state = object_state(obj)
    return state.write(obj, key, value)
end

--- Read only instance data, skipping methods, descriptors and hooks.
---@param obj object
---@param key any
---@return any
function M.rawgetattr(obj, key)
    local state = object_state(obj)
    return rawget(state.data(obj), key)
end

--- Trusted data write, skipping descriptors and hooks.
---@param obj object
---@param key any
---@param value any
function M.rawsetattr(obj, key, value)
    local state = object_state(obj)
    rawset(state.data(obj), key, value)
end

return M
