# std tests

Run `luajit test/run.lua std` from the project root. Tests cover string
helpers, literal split limits and empty separators, comma trimming, aggregate
identity, direct inheritance, reflection, protected metatables, cached
metamethods, final/abstract guards, super calls, GC metadata and exceptions.
Storage/lifecycle tests cover direct/dict layouts, options, explicit completion,
trailing nils and class/closure GC. Attribute tests cover the four hooks and
default/raw delegation; descriptors cover precedence, shadowing, deletion,
readonly setters, inheritance and hook combinations. Super tests cover parent
identity, cached compatibility wrappers and preserved return values.
Identity tests cover classof's class/std exports and boolean kind guards for
plain values and malformed markers.

Exception/traceback/catch/finally cases are owned by this group. The shared suite
supplies LuaJIT table shims; std tests need no mpv host.

Validation: **268 assertions passed**, with no errors or warnings in this group
under project-root EmmyLua analysis. Empty separators now raise ValueError;
`split(..., 0)` returns the input unsplit, and comma_split trims comma-delimited
fields while preserving empty fields.
