# inspect tests

Run `luajit test/run.lua inspect` from the project root. Coverage includes
one-time primitive installation/retry/conflict, std aggregate identity, shallow
private-information views, default/raw/ordinary attribute access and invalid
class/instance boundaries. Tests build tools from a primitive-only fixture and
verify that State and metatable views do not expose mutable configuration.
Validation: **35 assertions passed**.

Fresh-process import checks run separately:

```sh
luajit test/test_inspect/fixtures/import_order.lua inspect
luajit test/test_inspect/fixtures/import_order.lua class
luajit test/test_inspect/fixtures/import_order.lua exception
luajit test/test_inspect/fixtures/import_order.lua capabilities
luajit test/test_inspect/fixtures/import_order.lua dataclass
```

These fixtures verify import order, no host loading, later capability installation,
the exact four primitives installed by class, exception identity and independent
dataclass imports. They are not discovered
as test files by the shared runner. Class GC/storage/hooks/descriptors and parent
access are covered in [std tests](../test_std/README.md).
