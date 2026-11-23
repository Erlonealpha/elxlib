local F = require 'mpv_luatest.framework'
local class = require 'elxlibs.std.class'
local inspect = require 'elxlibs.std.inspect'
local S = require 'test_std.support'

F.section('class storage, lifecycle and state')

F.test('failed initialization does not retain instance or class closure cycle', function()
    local weak = setmetatable({}, {__mode = 'v'})
    local boom = {}
    do
        ---@class _std_storage.Failing : std.object
        ---@overload fun():self
        local Type = class.new('_std_storage.Failing')
        function Type:__init()
            weak[2] = self
            error(boom)
        end
        Type.__dict.cycle = function()
            return Type
        end
        weak[1] = Type
        F.eq(select(2, pcall(Type)), boom, 'initializer preserves error identity')
    end
    for _ = 1, 4 do
        collectgarbage('collect')
    end
    F.eq(weak[1], nil, 'failed class cycle collects')
    F.eq(weak[2], nil, 'failed instance collects')
end)

F.test('direct default and explicit dict isolate data and preserve false/deletion', function()
    for _, dict in ipairs({false, true}) do
        ---@class _std_storage.Record : std.object
        ---@field value any
        ---@overload fun(value:any):self
        local Record = class.new('_std_storage.Record', nil, nil, {dict = dict})
        function Record:__init(value)
            self.value = value
        end
        local first, second = Record(false), Record(3)
        F.eq(first.value, false, 'false is data')
        if dict then
            F.eq(rawget(first, 'value'), nil, 'dict value is not raw')
        else
            F.eq(rawget(first, 'value'), false, 'direct false is raw')
        end
        F.eq(inspect.classinfo(Record).storage, dict and 'dict' or 'direct', 'selected backend')
        local mt = inspect.getmetatable(first)
        F.eq(type(mt.__index), 'function', 'shared member reader')
        F.eq(type(mt.__newindex), dict and 'function' or 'nil', 'write policy')
        if not dict then
            F.eq(first.__dict, nil, 'class dictionary is not instance data')
        end
        first.value = nil
        F.eq(first.value, nil, 'delete')
        first.value = 5
        F.eq(second.value, 3, 'other instance isolated')
        F.eq(inspect.rawgetattr(first, 'value'), 5, 'backend-independent raw read')
        inspect.rawsetattr(first, 'value', false)
        F.eq(first.value, false, 'backend-independent raw write')
        F.eq(inspect.getmetatable(Record).__class_state, nil, 'private state not exposed')
        mt.__newindex = function()
            error('snapshot mutation')
        end
        first.value = 7
        F.eq(first.value, 7, 'metatable query is a snapshot')
    end
end)

F.test('custom constructors stay dynamic and preserve all return values', function()
    ---@class _std_storage.Custom : std.object
    ---@overload fun(...):self
    local Custom = class.new('_std_storage.Custom')
    local initial = Custom()
    Custom.__dict.__new = function(cls, ...)
        F.eq(cls, Custom, 'constructor receives class')
        return initial, select('#', ...), false, nil
    end
    local result = table.pack(S.runtime(Custom)(nil, nil))
    ---@cast result {n:integer, [integer]:any}
    F.eq(result.n, 4, 'custom constructor retains trailing nil')
    F.eq(result[1], initial, 'custom allocation result')
    F.eq(result[2], 2, 'custom arguments retain nils')
    F.eq(result[3], false, 'custom false result')
end)

F.test('options inherit storage, copy caller configuration and validate at definition', function()
    local opts = {dict = true}
    ---@class _std_storage.Parent : std.object
    ---@overload fun():self
    local Parent = class.new('_std_storage.Parent', nil, nil, opts)
    opts.dict = false
    ---@class _std_storage.Child : _std_storage.Parent
    ---@overload fun():self
    local Child = class.new('_std_storage.Child', Parent)
    ---@class _std_storage.Direct : _std_storage.Parent
    ---@overload fun():self
    local Direct = class.new('_std_storage.Direct', Parent, nil, {dict = false})
    F.eq(inspect.classinfo(Parent).options.dict, true, 'copied options')
    F.eq(inspect.classinfo(Child).options.dict, true, 'inherited explicit storage')
    F.eq(rawget(Child(), '__dict') ~= nil, true, 'child uses dict')
    F.eq(rawget(Direct(), '__dict'), nil, 'explicit false overrides parent')
    local info = inspect.classinfo(Child)
    info.options.dict, info.mro[1] = false, Parent
    F.eq(inspect.classinfo(Child).options.dict, true, 'option snapshot isolated')
    F.eq(inspect.classinfo(Child).mro[1], Child, 'mro snapshot isolated')
    F.raises(function()
        S.runtime(class.new)('Bad', nil, nil, {dict = 1})
    end, 'TypeError', 'bad option value')
    F.raises(function()
        S.runtime(class.new)('Bad', nil, nil, {unknown = true})
    end, 'TypeError', 'unknown option')
    F.raises(function()
        S.runtime(class.new)('', nil)
    end, 'TypeError', 'empty name')
    F.raises(function()
        S.runtime(class.new)('Bad', {})
    end, 'TypeError', 'invalid parent')
    F.raises(function()
        S.runtime(class.new)('Bad', nil, 1)
    end, 'TypeError', 'invalid members')
end)

F.test('finish is explicit/idempotent and init remains dynamic with trailing nils', function()
    ---@class _std_storage.Args : std.object
    ---@field count integer
    ---@field first any
    ---@overload fun(...):self
    local Args = class.new('_std_storage.Args')
    function Args:__init(...)
        self.count = select('#', ...)
        self.first = ...
    end
    F.eq(inspect.classinfo(Args).finished, false, 'definition open')
    F.eq(class.finish(Args), Args, 'finish returns class')
    F.eq(class.finish(Args), Args, 'finish idempotent')
    local obj = Args(false, nil, nil)
    F.eq(obj.count, 3, 'trailing nil constructor args')
    F.eq(obj.first, false, 'false constructor arg')
    Args.__dict.__init = function(self, ...)
        self.count = select('#', ...) + 10
    end
    F.eq(Args(nil).count, 11, 'ordinary initializer stays dynamic')
    local mt = inspect.getmetatable(obj)
    F.eq(mt.__gc, nil, 'no unsupported table finalizer')
end)

F.test('class/state/meta closure cycles collect and live instances retain class', function()
    local weak = setmetatable({}, {__mode = 'v'})
    do
        ---@class _std_storage.Collectible : std.object
        ---@overload fun():self
        local Type = class.new('_std_storage.Collectible')
        Type.__dict.capture = function()
            return Type
        end
        Type.__dict.__tostring = function()
            return Type.__name
        end
        local obj = Type()
        weak[1], weak[2] = Type, obj
    end
    for _ = 1, 4 do
        collectgarbage('collect')
    end
    F.eq(weak[1], nil, 'class closure cycle released')
    F.eq(weak[2], nil, 'instance released')
    ---@class _std_storage.Live : std.object
    ---@overload fun():self
    local Type = class.new('_std_storage.Live')
    local live = Type()
    weak[3] = Type
    Type = nil
    collectgarbage('collect')
    F.eq(class.classof(live), weak[3], 'live instance retains class')
    F.eq(class.kindof(S.runtime({__class = {}})), nil, 'malformed identity rejected')
    F.eq(class.kindof(S.runtime({__class = weak[3]})), 'object', 'identity follows trusted convention')
end)
