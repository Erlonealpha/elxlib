---@class hashlib : hashlib.sha
local M = {version = "1.0.0"}

local sha = require "elxlibs.hashlib.sha"
local base64 = require "elxlibs.hashlib.base64"

setmetatable(M, {__index = sha})

M.base64_encode = base64.Encode
M.base64_decode = base64.Decode

return M