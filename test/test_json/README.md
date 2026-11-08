# json tests

Run `luajit test/run.lua json`. The group covers scalar and nested round trips,
binary/control escapes, Unicode pairs, null placeholders, pretty formatting,
custom codecs and fallback fragments, shared objects, cycles, sparse/mixed
tables, nonfinite numbers and malformed input with source positions.

Validation: **64 assertions passed**; project-root EmmyLua reports no errors or
warnings in the group or json implementation. Repeated `json.null` values and a
false placeholder are preserved. The decoder rejects trailing commas, non-JSON
number syntax and unpaired Unicode surrogates. Default decoded null remains nil;
pass `json.null` to retain null array positions or object fields. Empty Lua tables
encode as arrays; custom fallback output must be a valid JSON fragment.
