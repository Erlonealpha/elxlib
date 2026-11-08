# std tests

Run `luajit test/run.lua std` from the project root. Tests cover numeric/string
helpers, literal split limits and empty separators, comma trimming, aggregate
identity, direct inheritance, reflection, protected metatables, cached
metamethods, final/abstract guards, super calls, GC metadata and exceptions.

Exception/traceback/catch/finally cases are owned by this group. The shared suite
supplies LuaJIT table shims; std tests need no mpv host.

Validation: **124 assertions passed**, with no errors or warnings in this group
under project-root EmmyLua analysis. Empty separators now raise ValueError;
`split(..., 0)` returns the input unsplit, and comma_split trims comma-delimited
fields while preserving empty fields.
