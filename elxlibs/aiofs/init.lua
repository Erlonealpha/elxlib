local asyncio = require("elxlibs.asyncio")
local fs = require("elxlibs.aiofs.fs")

---@class aiofs
local M = {version = "0.1.0"}

---@param func fun(..., cb:fun(ok:boolean, err:string))
---@param args any[]
local function wrap(func, args)
    return asyncio.event(function(resolve, reject)
        func(table.unpack(args), function(ok, val_err)
            if ok then
                resolve(val_err)
            else
                reject(val_err)
            end
        end)
    end)
end

---@param func fun(..., cb:fun(ok:boolean, err:string))
---@param args any[]
local function wrap_no_err(func, args, err_val)
    err_val = err_val or false
    return asyncio.event(function(resolve)
        func(table.unpack(args), function(ok, val_err)
            if ok then
                resolve(val_err)
            else
                resolve(err_val)
            end
        end)
    end)
end

---@async
---@param path string
function M.exists(path) return wrap_no_err(fs.exists, {path}) end

---@async
---@param path string
---@param recursive boolean
---@param exists_ok boolean
function M.mkdir(path, recursive, exists_ok) return wrap(fs.create_dir, {path, recursive, exists_ok}) end

---@async
---@param path string
---@param recursive boolean
function M.rmdir(path, recursive) return wrap(fs.remove_dir, {path, recursive}) end

---@async
---@param path string
function M.remove(path) return wrap(fs.remove, {path}) end

---@async
---@param src string
---@param dst string
---@param recursive boolean
function M.copy(src, dst, recursive) return wrap(fs.copy, {src, dst, recursive}) end

---@async
---@param src string
---@param dst string
function M.move(src, dst) return wrap(fs.move, {src, dst}) end

---@async
---@param path string
function M.stat(path) return wrap_no_err(fs.stat, {path}, nil) end


function M.read_stream(path, mode, chunk_size)
    
end

M.fs = fs

return M