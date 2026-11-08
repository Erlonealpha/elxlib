# fs tests

Run `luajit test/run.lua fs`. **83 assertions** exercise every public filesystem
operation through the real mptl adapter and a deterministic host: platform tool
paths, quoted/Unicode paths kept as individual arguments, default/recursive flags,
mkdir alias, success/missing values, transport/nonzero failures and stat fields.
Stat parsing preserves signed timestamps and names containing multiple underscores.
Project-root EmmyLua reports no errors or warnings in the group or fs module.

Optional Windows integration:

```sh
python test/test_fs/real_host.py --mpv <mpv-or-mpvnet-binary>
```

The isolated headless host calls the actual bundled fstool; Python independently
checks file and recursive-copy bytes. Creation, existence, size/stat, removal and
failure paths passed. User configuration is disabled and fixtures live outside
the repository. See [fstool provenance and limitations](../../bin/fstool.md),
including the current build's failure on existing directories despite `-e`,
garbled error text and Lua number precision for large stat integers.
