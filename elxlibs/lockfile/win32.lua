---@diagnostic disable: inject-field

-- file_lock.lua
local ffi = require("ffi")
local bit = require("bit")

local band, bor = bit.band, bit.bor

ffi.cdef[[
    typedef int32_t BOOL;
    typedef uint32_t DWORD;
    typedef void* PVOID;
    typedef void* HANDLE;
    typedef uintptr_t ULONG_PTR;

    typedef struct _OVERLAPPED {
        ULONG_PTR Internal;
        ULONG_PTR InternalHigh;
        DWORD Offset;
        DWORD OffsetHigh;
        HANDLE    hEvent;
    } OVERLAPPED, *LPOVERLAPPED;

    BOOL LockFileEx(
        HANDLE       hFile,
        DWORD        dwFlags,
        DWORD        dwReserved,
        DWORD        nNumberOfBytesToLockLow,
        DWORD        nNumberOfBytesToLockHigh,
        LPOVERLAPPED lpOverlapped
    );

    BOOL UnlockFileEx(
        HANDLE       hFile,
        DWORD        dwReserved,
        DWORD        nNumberOfBytesToLockLow,
        DWORD        nNumberOfBytesToLockHigh,
        LPOVERLAPPED lpOverlapped
    );

    HANDLE CreateFileA(
        const char* lpFileName,
        DWORD dwDesiredAccess,
        DWORD dwShareMode,
        void* lpSecurityAttributes,
        DWORD dwCreationDisposition,
        DWORD dwFlagsAndAttributes,
        HANDLE hTemplateFile
    );

    BOOL CloseHandle(HANDLE hObject);
    DWORD GetLastError(void);
    DWORD FormatMessageA(
        DWORD dwFlags,
        void* lpSource,
        DWORD dwMessageId,
        DWORD dwLanguageId,
        char* lpBuffer,
        DWORD nSize,
        void* Arguments
    );

    BOOL WriteFile(
        HANDLE       hFile,
        const void*  lpBuffer,
        DWORD        nNumberOfBytesToWrite,
        DWORD*       lpNumberOfBytesWritten,
        void*        lpOverlapped
    );

    BOOL ReadFile(
        HANDLE       hFile,
        void*        lpBuffer,
        DWORD        nNumberOfBytesToRead,
        DWORD*       lpNumberOfBytesRead,
        void*        lpOverlapped
    );

    DWORD SetFilePointer(
        HANDLE       hFile,
        int32_t      lDistanceToMove,
        int32_t*     lpDistanceToMoveHigh,
        DWORD        dwMoveMethod
    );

    BOOL FlushFileBuffers(HANDLE hFile);
    BOOL SetEndOfFile(HANDLE hFile);
]]

local LOCKFILE_EXCLUSIVE_LOCK = 0x00000002
local LOCKFILE_FAIL_IMMEDIATELY = 0x00000001

local GENERIC_READ = 0x80000000
local GENERIC_WRITE = 0x40000000
local FILE_SHARE_READ = 0x00000001
local FILE_SHARE_WRITE = 0x00000002
local MAXWORD = 0xFFFFFFFF
local OPEN_ALWAYS = 4
local FILE_ATTRIBUTE_NORMAL = 0x80
local INVALID_HANDLE_VALUE = ffi.cast("HANDLE", -1)


---@class LockFile
local LockFile = {}
LockFile.__index = LockFile


function LockFile.new(filename)
    local self = setmetatable({}, LockFile)
    self.filename = filename
    self.handle = nil
    self.locked = false
    return self
end

local function get_last_errmsg()
    local err = ffi.C.GetLastError()
    local buf = ffi.new("char[512]")
    local len = ffi.C.FormatMessageA(
        0x00001000,  -- FORMAT_MESSAGE_FROM_SYSTEM
        nil,
        err,
        0,  -- LANG_NEUTRAL
        buf,
        ffi.sizeof(buf),
        nil
    )
    if len > 0 then
        -- 去除末尾的换行/回车
        while len > 0 and (buf[len-1] == 10 or buf[len-1] == 13) do
            len = len - 1
            buf[len] = 0
        end
        return ffi.string(buf, len)
    else
        return string.format("Unknown error %d", err)
    end
end

---@return_overload true
---@return_overload false, string
function LockFile:open()
    if self.handle then
        return true
    end

    self.handle = ffi.C.CreateFileA(
        self.filename,
        bor(GENERIC_READ, GENERIC_WRITE),
        bor(FILE_SHARE_READ, FILE_SHARE_WRITE),
        nil,
        OPEN_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nil
    )

    if self.handle == INVALID_HANDLE_VALUE then
        self.handle = nil
        local errmsg = get_last_errmsg()
        return false, string.format("Failed to open file, %s", errmsg)
    end

    return true
end

-- 获取共享/独占锁（非阻塞）
---@param exclusive boolean?        是否独占锁
---@param offset_low number?        偏移量低字节
---@param offset_high number?       偏移量高字节
---@param lock_whole_file boolean?  是否锁定整个文件，启用后`offset_low`和`offset_high`无效
---@return_overload true            操作成功
---@return_overload false, string, true? 操作失败, 错误信息, 是否被其他进程锁定
function LockFile:try_lock(exclusive, offset_low, offset_high, lock_whole_file)
    if not self.handle then
        local ok, err = self:open()
        if not ok then
            return false, err
        end
    end

    local overlapped = ffi.new("OVERLAPPED")
    if lock_whole_file then
        overlapped.Offset = MAXWORD
        overlapped.OffsetHigh = MAXWORD
    else
        overlapped.Offset = offset_low or 0
        overlapped.OffsetHigh = offset_high or 0
    end

    local dwFlags
    if exclusive then
        dwFlags = bor(LOCKFILE_EXCLUSIVE_LOCK, LOCKFILE_FAIL_IMMEDIATELY)
    else
        dwFlags = LOCKFILE_FAIL_IMMEDIATELY
    end

    local result = ffi.C.LockFileEx(
        self.handle,
        dwFlags,
        0,
        1,  -- 锁定1字节
        0,
        overlapped
    )

    if result ~= 0 then
        self.locked = true
        return true
    else
        return false, "File is locked by another process", true
    end
end

-- 获取共享/独占锁（阻塞）
---@param exclusive boolean?        是否独占锁
---@param offset_low number?        偏移量低字节，默认为0
---@param offset_high number?       偏移量高字节，默认为0
---@param lock_whole_file boolean?  是否锁定整个文件，启用后`offset_low`和`offset_high`无效
---@return_overload true     操作成功
---@return_overload false, string 操作失败, 错误信息
function LockFile:lock(exclusive, offset_low, offset_high, lock_whole_file)
    if not self.handle then
        local ok, err = self:open()
        if not ok then
            return false, err
        end
    end

    local overlapped = ffi.new("OVERLAPPED")
    if lock_whole_file then
        overlapped.Offset = MAXWORD
        overlapped.OffsetHigh = MAXWORD
    else
        overlapped.Offset = offset_low or 0
        overlapped.OffsetHigh = offset_high or 0
    end
    
    local dwFlags
    if exclusive then
        dwFlags = LOCKFILE_EXCLUSIVE_LOCK
    else
        dwFlags = 0
    end

    local result = ffi.C.LockFileEx(
        self.handle,
        dwFlags,
        0,
        1,
        0,
        overlapped
    )

    if result ~= 0 then
        self.locked = true
        return true
    else
        local errmsg = get_last_errmsg()
        return false, string.format("Failed to acquire lock, %s", errmsg)
    end
end

-- 释放锁
---@return_overload true
---@return_overload false, string
function LockFile:unlock()
    if not self.handle or not self.locked then
        return false
    end

    local overlapped = ffi.new("OVERLAPPED")
    overlapped.Offset = 0
    overlapped.OffsetHigh = 0

    local result = ffi.C.UnlockFileEx(
        self.handle,
        0,
        1,
        0,
        overlapped
    )
    
    if result ~= 0 then
        self.locked = false
        return true
    else
        local errmsg = get_last_errmsg()
        return false, string.format("Failed to unlock file, %s", errmsg)
    end
end

---@param data string
---@return_overload int
---@return_overload nil, string
function LockFile:write(data)
    if not self.handle then
        local ok, err = self:open()
        if not ok then
            return nil, err
        end
    end

    local len = #data
    local bytes_written = ffi.new("DWORD[1]")
    local result = ffi.C.WriteFile(
        self.handle,
        data,
        len,
        bytes_written,
        nil
    )

    if result ~= 0 then
        ---@diagnostic disable-next-line
        return tonumber(bytes_written[0])
    else
        local errmsg = get_last_errmsg()
        return nil, string.format("Failed to write file, %s", errmsg)
    end
end

---@param n int
---@return_overload int
---@return_overload nil, string
function LockFile:seek(n)
    if not self.handle then
        return nil, "File not opened"
    end

    local new_ptr = ffi.new("int32_t[1]")
    local result = ffi.C.SetFilePointer(
        self.handle,
        n,
        new_ptr,
        0  -- FILE_BEGIN
    )

    if result ~= ffi.cast("DWORD", -1) or ffi.C.GetLastError() == 0 then
        ---@diagnostic disable-next-line
        return tonumber(result)
    else
        local errmsg = get_last_errmsg()
        return nil, string.format("Failed to seek file, %s", errmsg)
    end
end

---@return_overload true
---@return_overload false, string
function LockFile:flush()
    if not self.handle then
        return false, "File not opened"
    end

    local result = ffi.C.FlushFileBuffers(self.handle)
    if result ~= 0 then
        return true
    else
        local errmsg = get_last_errmsg()
        return false, string.format("Failed to flush file, %s", errmsg)
    end
end

---@param n? int
---@return_overload string
---@return_overload nil, string
function LockFile:read(n)
    if not self.handle then
        local ok, err = self:open()
        if not ok then
            return nil, err
        end
    end

    n = n or 4096
    local buf = ffi.new("char[?]", n)
    local bytes_read = ffi.new("DWORD[1]")
    local result = ffi.C.ReadFile(
        self.handle,
        buf,
        n,
        bytes_read,
        nil
    )

    if result ~= 0 then
        ---@diagnostic disable-next-line
        return ffi.string(buf, tonumber(bytes_read[0]))
    else
        local errmsg = get_last_errmsg()
        return nil, string.format("Failed to read file, %s", errmsg)
    end
end

---@param n? int 截断到指定位置，默认为当前文件指针位置
---@return_overload true
---@return_overload false, string
function LockFile:truncate(n)
    if not self.handle then
        return false, "File not opened"
    end

    if n then
        -- 先 seek 到指定位置
        local _, err = self:seek(n)
        if err then
            return false, err
        end
    end

    local result = ffi.C.SetEndOfFile(self.handle)
    if result ~= 0 then
        return true
    else
        local errmsg = get_last_errmsg()
        return false, string.format("Failed to truncate file, %s", errmsg)
    end
end

-- 关闭文件
function LockFile:close()
    if self.handle then
        if self.locked then
            self:unlock()
        end
        ffi.C.CloseHandle(self.handle)
        self.handle = nil
    end
end

function LockFile:__gc()
    self:close()
end

return LockFile