-- ---@meta

-- ---@alias kindType "class"|"object"

-- ---@class std.class
-- ---@overload fun(): std.object
-- ---@overload fun(name?: string, bases?: std.Class, dict?: table): std.Class
-- local class = {}

-- ---@return std.object
-- function class.new() end

-- ---@generic T: std.object
-- ---@param name string?
-- ---@param bases `T`[]?
-- ---@param dict table?
-- ---@return T
-- function class.new(name, bases, dict) end

-- ---@generic T: std.object
-- ---@param obj T
-- ---@return T
-- function class.super(cls) end

-- ---@generic T: std.object, T2: std.object
-- ---@param obj T
-- ---@param obj_or_cls T2
-- ---@return T
-- function class.super(cls, obj_or_cls) end

-- ---@generic T: std.object
-- ---@param obj T
-- ---@return kindType
-- function class.kindof(obj) end

-- ---@param obj table
-- ---@param kind kindType?
-- ---@return nil
-- function class.kindof(obj, kind) end

-- ---@generic T: std.object
-- ---@param obj T
-- ---@param kind kindType
-- ---@return boolean
-- function class.kindof(obj, kind) end

