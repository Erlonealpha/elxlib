local F = require 'mpv_luatest.framework'
local class = require 'elxlibs.std.class'
local inspect = require 'elxlibs.std.inspect'

F.section('class attribute hooks')

F.test('invalid hooks reject completion and data identity queries do not call hooks', function()
    ---@class _std_attr.Invalid : std.object
    local Invalid = class.new('_std_attr.Invalid', nil, {__getattribute = 'invalid'})
    F.raises(function()
        class.finish(Invalid)
    end, 'TypeError', 'nonfunction hook rejected')
    F.eq(inspect.classinfo(Invalid).finished, false, 'completion remains open after invalid hook')
    Invalid.__dict.__getattribute = nil
    class.finish(Invalid)
    F.eq(inspect.classinfo(Invalid).storage, 'direct', 'corrected class can finish')
    ---@class _std_attr.Identity : std.object
    ---@overload fun():self
    local Identity = class.new('_std_attr.Identity')
    local count = 0
    function Identity:__getattribute(key)
        count = count + 1
        return inspect.getattribute(self, key)
    end
    local obj = Identity()
    count = 0
    F.eq(class.kindof(obj), 'object', 'kind reflects raw identity')
    F.eq(class.isinstance(obj, Identity), true, 'instance reflects raw identity')
    F.eq(class.classof(obj), Identity, 'class reflects raw identity')
    F.eq(count, 0, 'identity query avoids custom hooks')
end)

F.test('dict fallback setter handles only missing instance and class members', function()
    local writes = 0
    ---@class _std_attr.DictFallback : std.object
    ---@field value any
    ---@overload fun():self
    local Type = class.new('_std_attr.DictFallback', nil, {value = false}, {dict = true})
    function Type:__setattr(key, value)
        writes = writes + 1
        inspect.setattribute(self, key, value)
    end
    local obj = Type()
    obj.value = 3
    obj.value = false
    obj.value = nil
    F.eq(writes, 0, 'class member writes bypass fallback')
    inspect.setattr(obj, 'new', false)
    inspect.setattr(obj, 'new', 8)
    inspect.setattr(obj, 'new', nil)
    F.eq(writes, 1, 'existing dictionary value/deletion bypass fallback')
    inspect.setattr(obj, 'new', 1)
    F.eq(writes, 2, 'deleted missing value invokes fallback again')
end)

F.test('missing read and new-field write hooks keep direct existing fields native', function()
    local reads, writes = {}, {}
    ---@class _std_attr.Fallback : std.object
    ---@field value any
    ---@field extra any
    ---@overload fun():self
    local Type = class.new('_std_attr.Fallback', nil, {value = false})
    function Type.__getattr(_self, key)
        reads[#reads + 1] = key
        return false
    end
    function Type:__setattr(key, value)
        writes[#writes + 1] = key
        inspect.setattribute(self, key, value)
    end
    local obj = Type()
    F.eq(rawget(obj, '__dict'), nil, 'fallback hooks retain direct storage')
    F.eq(obj.value, false, 'class false is found')
    F.eq(#reads, 0, 'found false avoids fallback')
    F.eq(obj.extra, false, 'missing false result retained')
    F.eq(#reads, 1, 'one missing read')
    F.eq(inspect.getattribute(obj, 'extra'), nil, 'default read skips fallback')
    obj.value = false
    F.eq(#writes, 0, 'existing class member writes normally')
    obj.extra = false
    F.eq(#writes, 1, 'new field hook')
    obj.extra = 3
    F.eq(#writes, 1, 'existing raw field bypasses hook')
    obj.extra = nil
    F.eq(#writes, 1, 'delete existing field is native')
    obj.extra = nil
    F.eq(#writes, 2, 'missing nil write invokes fallback')
    F.eq(inspect.rawgetattr(obj, 'extra'), nil, 'deleted value')
end)

F.test('full read/write automatically select dict and can delegate without recursion', function()
    local reads, writes, missing = 0, 0, 0
    local opts = {dict = false}
    ---@class _std_attr.Full : std.object
    ---@field value any
    ---@overload fun():self
    local Type = class.new('_std_attr.Full', nil, nil, opts)
    function Type.__getattr(_self, _key)
        missing = missing + 1
        return 'missing'
    end
    function Type:__getattribute(key)
        reads = reads + 1
        return inspect.getattribute(self, key)
    end
    function Type:__setattribute(key, value)
        writes = writes + 1
        inspect.setattribute(self, key, value)
    end
    local obj = Type()
    F.eq(opts.dict, false, 'caller option unchanged')
    F.eq(inspect.classinfo(Type).options.dict, false, 'declared option unchanged')
    F.eq(inspect.classinfo(Type).storage, 'dict', 'effective backend upgraded')
    F.eq(obj.__class, Type, 'structural class bypasses hooks')
    obj.value = false
    obj.value = 2
    obj.value = nil
    F.eq(writes, 3, 'existing/new/deletion all intercepted')
    F.eq(obj.value, nil, 'full hook nil is final')
    F.eq(missing, 0, 'full read delegation skips all custom hooks')
    F.eq(reads, 2, 'init lookup and value read intercepted')
    inspect.rawsetattr(obj, 'value', false)
    F.eq(obj.value, false, 'false survives full read')
    F.eq(writes, 3, 'raw write bypasses custom setter')
end)

F.test('read-only/write-only hooks choose independent handlers and propagate errors', function()
    ---@class _std_attr.Read : std.object
    ---@overload fun():self
    local Read = class.new('_std_attr.Read')
    local boom = {}
    function Read:__getattribute(key)
        if key == 'boom' then
            error(boom)
        end
        return inspect.getattribute(self, key)
    end
    local read = Read()
    F.eq(inspect.getmetatable(read).__index, Read.__getattribute, 'direct full read handler')
    F.eq(inspect.getmetatable(read).__newindex ~= nil, true, 'dict write needed for read interception')
    F.eq(select(2, pcall(inspect.getattr, read, 'boom')), boom, 'read error identity')
    ---@class _std_attr.Write : std.object
    ---@overload fun():self
    local Write = class.new('_std_attr.Write')
    function Write:__setattribute(key, value)
        if key == 'boom' then
            error(boom)
        end
        inspect.setattribute(self, key, value)
    end
    local write = Write()
    F.eq(inspect.getmetatable(write).__newindex, Write.__setattribute, 'direct full write handler')
    F.eq(select(2, pcall(inspect.setattr, write, 'boom', 1)), boom, 'write error identity')
end)

F.test('inherited hook caches and disabling hooks obey class completion', function()
    ---@class _std_attr.Parent : std.object
    ---@overload fun():self
    local Parent = class.new('_std_attr.Parent')
    function Parent.__getattr(_self, _key)
        return 'before'
    end
    ---@class _std_attr.Child : _std_attr.Parent
    ---@overload fun():self
    local Child = class.new('_std_attr.Child', Parent)
    class.finish(Child)
    Parent.__dict.__getattr = function()
        return 'after'
    end
    F.eq(inspect.getattr(Child(), 'unknown'), 'before', 'cached inherited hook')
    ---@class _std_attr.Disabled : _std_attr.Parent
    ---@overload fun():self
    local Disabled = class.new('_std_attr.Disabled', Parent, {__getattr = false})
    F.eq(inspect.getattr(Disabled(), 'unknown'), nil, 'false disables parent hook')
    F.eq(inspect.getmetatable(Disabled()).__newindex, nil, 'read fallback does not add writer')
end)
