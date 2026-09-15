---@meta

---@class LuaExpat
local LuaExpat = {}

---Creates a new XML parser.
---@param callbacks LuaExpatCallbacks Table of callback functions for handling XML events
---@param separator? string Separator character for namespace expanded element names
---@param merge_character_data? boolean If false, do not combine multiple CharacterData calls into one
---@return LuaExpatParser
function LuaExpat.new(callbacks, separator, merge_character_data) end

---Callback table for XML parser events
---@class LuaExpatCallbacks
---@field AttlistDecl? fun(parser: LuaExpatParser, elementName: string, attrName: string, attrType: string, default: string?, required: boolean)
---@field CharacterData? fun(parser: LuaExpatParser, s: string)
---@field Comment? fun(parser: LuaExpatParser, data: string)
---@field Default? fun(parser: LuaExpatParser, s: string)
---@field DefaultExpand? fun(parser: LuaExpatParser, s: string)
---@field ElementDecl? fun(parser: LuaExpatParser, elementName: string, model: string)
---@field EndCdataSection? fun(parser: LuaExpatParser)
---@field EndDoctypeDecl? fun(parser: LuaExpatParser)
---@field EndElement? fun(parser: LuaExpatParser, elementName: string)
---@field EndNamespaceDecl? fun(parser: LuaExpatParser, namespaceName: string)
---@field EntityDecl? fun(parser: LuaExpatParser, entityName: string, is_parameter: boolean, value: string?, base: string?, systemId: string?, publicId: string?, notationName: string?)
---@field ExternalEntityRef? fun(parser: LuaExpatParser, subparser: LuaExpatParser, base: string?, systemId: string, publicId: string?)
---@field NotStandalone? fun(parser: LuaExpatParser): boolean
---@field NotationDecl? fun(parser: LuaExpatParser, notationName: string, base: string?, systemId: string, publicId: string?)
---@field ProcessingInstruction? fun(parser: LuaExpatParser, target: string, data: string)
---@field SkippedEntity? fun(parser: LuaExpatParser, name: string, isParameter: boolean)
---@field StartCdataSection? fun(parser: LuaExpatParser)
---@field StartDoctypeDecl? fun(parser: LuaExpatParser, name: string, sysid: string?, pubid: string?, has_internal_subset: boolean)
---@field StartElement? fun(parser: LuaExpatParser, elementName: string, attributes: table)
---@field StartNamespaceDecl? fun(parser: LuaExpatParser, namespaceName: string?, namespaceUri: string)
---@field UnparsedEntityDecl? fun(parser: LuaExpatParser, entityName: string, base: string?, systemId: string, publicId: string?, notationName: string)
---@field XmlDecl? fun(parser: LuaExpatParser, version: string, encoding: string, standalone: boolean?)
---@field _nonstrict? boolean

---@class LuaExpatParser
local LuaExpatParser = {}

---Closes the parser, freeing all memory used by it.
---@return LuaExpatParser
function LuaExpatParser:close() end

---Returns the base for resolving relative URIs.
---@return string?
function LuaExpatParser:getbase() end

---Returns the callbacks table.
---@return LuaExpatCallbacks
function LuaExpatParser:getcallbacks() end

---Parse some more of the document. When called without arguments, closes the document.
---@param s? string Part (or all) of the document to parse
---@return LuaExpatParser? parser
---@return string? msg Error message if parsing failed
---@return number? line Line number of error
---@return number? col Column number of error
---@return number? pos Absolute position of error
function LuaExpatParser:parse(s) end

---Returns the current parsing position.
---@return number line
---@return number col
---@return number pos
function LuaExpatParser:pos() end

---Returns the number of bytes of input corresponding to the current event.
---@return number
function LuaExpatParser:getcurrentbytecount() end

---Instructs the parser to return namespaces in triplet or duo format.
---@param return_triplet boolean
---@return LuaExpatParser
function LuaExpatParser:returnnstriplet(return_triplet) end

---Sets the base for resolving relative URIs in system identifiers.
---@param base string
---@return LuaExpatParser
function LuaExpatParser:setbase(base) end

---Sets the maximum amplification to protect against Billion Laughs Attack.
---@param max_amp number
---@return LuaExpatParser
function LuaExpatParser:setblamaxamplification(max_amp) end

---Sets the threshold after which Billion Laughs Attack protection starts.
---@param threshold number
---@return LuaExpatParser
function LuaExpatParser:setblathreshold(threshold) end

---Sets the encoding to be used by the parser.
---@param encoding "US-ASCII"|"UTF-8"|"UTF-16"|"ISO-8859-1"
---@return LuaExpatParser
function LuaExpatParser:setencoding(encoding) end

---Aborts the parser and prevents it from parsing any further.
function LuaExpatParser:stop() end

return LuaExpat
