# hashlib tests

Run `luajit test/run.lua hashlib`. **145 assertions** cover MD5, SHA1, every SHA2
and SHA3 variant, SHAKE, HMAC, keyed/salted BLAKE2, BLAKE2 aliases and parallel/XOF
streaming, BLAKE3 and context-separated key derivation, conversion aliases and
RFC 4648 Base64 vectors. Binary data crosses compression and 4096-byte Base64
output boundaries. Streaming checks include empty chunks, repeated finalization
and rejection of subsequent input; invalid key/salt/digest limits are tested.

MD5/SHA/BLAKE2/HMAC constants were independently checked using Python
`hashlib`/`hmac` (OpenSSL); the empty BLAKE3 digest is the official known vector.
Parallel BLAKE2, BLAKE2X and key derivation use streaming/one-shot equivalence,
not independent algorithm vectors. Base64 tests use valid padded input; they do
not imply strict rejection of malformed input. Project-root EmmyLua reports no
errors or warnings in this group.
