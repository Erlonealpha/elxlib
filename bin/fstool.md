# fstool.exe provenance and validation

The executable in this commit is a user-provided build. Its source has not been
published; publication is planned. No source directory or reproducible build
command is currently available. This document records that status only.

SHA-256:
`e0bf0681f0b0b4ca1c2555ea7fc076cf15e59378fca9239a74fa0062d4565136`

Validated on Windows through real mpv.net subprocess calls using
`python test/test_fs/real_host.py --mpv <binary>`: existence, directory creation,
file and recursive copies (bytes independently checked in Python), size/stat,
recursive removal and missing/nonempty-path failures. All paths are isolated in
a temporary directory, including spaces and Chinese characters.

Known build limitation: `mkdir -e` still fails when the directory already
exists; fs/aiofs forward `exists_ok` to this flag and report the tool's failure.
Some Windows error messages are garbled. Stat values use Lua numbers, so inode,
device and nanosecond integers above 2^53 can lose integer precision.
