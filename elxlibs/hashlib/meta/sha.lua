---@meta

---@class hashlib.sha
local sha = {}

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.md5(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha1(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha224(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha256(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha512_224(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha512_256(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha384(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha512(message) end


---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha3_224(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha3_256(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha3_384(message) end

---@param message string?
---@return string|fun():string
---@overload fun(message: string):string
---@overload fun():(fun():string)
function sha.sha3_512(message) end

---@param digest_size_in_bytes int
---@param message string?
---@return string|fun():string
---@overload fun(digest_size_in_bytes: int, message: string):string
---@overload fun(digest_size_in_bytes: int):(fun():string)
function sha.shake128(digest_size_in_bytes, message) end

---@param digest_size_in_bytes int
---@param message string?
---@return string|fun():string
---@overload fun(digest_size_in_bytes: int, message: string):string
---@overload fun(digest_size_in_bytes: int):(fun():string)
function sha.shake256(digest_size_in_bytes, message) end

---@alias _hash_function fun(message:string?):string|(fun():string)

---@param hash_func _hash_function
---@param key string
---@param message string?
---@return string|fun():string
---@overload fun(hash_func: _hash_function, key: string, message: string):string
---@overload fun(hash_func: _hash_function, key: string):(fun():string)
function sha.hmac(hash_func, key, message) end

---@param hex_string string
---@return string
local function hex_to_bin(hex_string) end

---@param binary_string string
---@return string
local function bin_to_hex(binary_string) end


---@param binary_string string
---@return string
local function base64_to_bin(binary_string) end

---@param base64_string string
---@return string
local function bin_to_base64(base64_string) end

sha.hex_to_bin = hex_to_bin
sha.bin_to_hex = bin_to_hex
sha.base64_to_bin = base64_to_bin
sha.bin_to_base64 = bin_to_base64

sha.hex2bin = hex_to_bin
sha.bin2hex = bin_to_hex
sha.base642bin = base64_to_bin
sha.bin2base64 = bin_to_base64

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@param digest_size_in_bytes? int integer from 1 to 64, by default 64
---@param XOF_length int? internal use only, user must omit them (or pass nil)
---@param B2_offset int?
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2b(message, key, salt, digest_size_in_bytes, XOF_length, B2_offset) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@param digest_size_in_bytes? int integer from 1 to 64, by default 64
---@param XOF_length int? internal use only, user must omit them (or pass nil)
---@param B2_offset int?
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2s(message, key, salt, digest_size_in_bytes, XOF_length, B2_offset) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@param digest_size_in_bytes? int integer from 1 to 64, by default 64
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2bp(message, key, salt, digest_size_in_bytes) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@param digest_size_in_bytes? int integer from 1 to 64, by default 64
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2sp(message, key, salt, digest_size_in_bytes) end

---@param digest_size_in_bytes int desc:
--- 0..4294967294       = get finite digest as single Lua string
--- (-1)                = get infinite digest in "chunk-by-chunk" output mode
--- (-2)..(-4294967294) = get finite digest in "chunk-by-chunk" output mode
---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(digest_size_in_bytes: int, message: string, ...):string
---@overload fun(digest_size_in_bytes: int, message: nil, ...):(fun():string)
function sha.blake2xb(digest_size_in_bytes, message, key, salt) end

---@param digest_size_in_bytes int desc:
--- 0..65534       = get finite digest as single Lua string
--- (-1)           = get infinite digest in "chunk-by-chunk" output mode
--- (-2)..(-65534) = get finite digest in "chunk-by-chunk" output mode
---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(digest_size_in_bytes: int, message: string, ...):string
---@overload fun(digest_size_in_bytes: int, message: nil, ...):(fun():string)
function sha.blake2xs(digest_size_in_bytes, message, key, salt) end

sha.blake2 = sha.blake2b

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2b_160(message, key, salt) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2b_256(message, key, salt) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2b_384(message, key, salt) end

sha.blake2b_512 = sha.blake2b

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2s_128(message, key, salt) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2s_160(message, key, salt) end

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 64 bytes, by default empty string
---@param salt? string binary string up to 32 bytes, by default empty string
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake2s_224(message, key, salt) end

sha.blake2s_256 = sha.blake2s

---@param message? string binary string to be hashed (or nil for "chunk-by-chunk" input mode)
---@param key? string binary string up to 32 bytes, by default empty string
---@param digest_size_in_bytes? int by default 32
--- 0,1,2,3,4,...  = get finite digest as single Lua string
--- (-1)           = get infinite digest in "chunk-by-chunk" output mode
--- -2,-3,-4,...   = get finite digest in "chunk-by-chunk" output mode
---@param message_flags? int The last three parameters "message_flags", "K" and "return_array" are for internal use only, user must omit them (or pass nil)
---@param K? table<int, int>
---@param return_array? boolean
---@return string|fun():string
---@overload fun(message: string, ...):string
---@overload fun(message: nil, ...):(fun():string)
function sha.blake3(message, key, digest_size_in_bytes, message_flags, K, return_array) end

---@param key_material? string your source of entropy to derive a key from (for example, it can be a master password)
--- set to nil for feeding the key material in "chunk-by-chunk" input mode
---@param context_string string unique description of the derived key
---@param derived_key_size_in_bytes? int by default 32
--- 0,1,2,3,4,...  = get finite derived key as single Lua string
--- (-1)           = get infinite derived key in "chunk-by-chunk" output mode
--- -2,-3,-4,...   = get finite derived key in "chunk-by-chunk" output mode
---@return string|fun():string
---@overload fun(key_material: string, ...):string
---@overload fun(key_material: nil, ...):(fun():string)
function sha.blake3_derive_key(key_material, context_string, derived_key_size_in_bytes) end

return sha
