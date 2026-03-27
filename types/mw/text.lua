--- Scribunto mw.text (REL1_43)
--- @meta

--- @class mw.text
--- @field JSON_PRESERVE_KEYS number
--- @field JSON_TRY_FIXING number
--- @field JSON_PRETTY number
local text = {}

--- Trims whitespace (or custom charset) from both ends.
--- @param s string
--- @param charset string|nil
--- @return string
function text.trim(s, charset) end

--- HTML-encodes characters in the string.
--- @param s string
--- @param charset string|nil
--- @return string
function text.encode(s, charset) end

--- Decodes HTML entities.
--- @param s string
--- @param decodeNamedEntities boolean|nil
--- @return string
function text.decode(s, decodeNamedEntities) end

--- Escapes wikitext-significant characters.
--- @param s string
--- @return string
function text.nowiki(s) end

--- Creates an HTML tag string.
--- @param name string|{ name: string, attrs: table|nil, content: string|number|nil|false }
--- @param attrs table|nil
--- @param content string|number|nil|false False = self-closing, nil = unclosed.
--- @return string
function text.tag(name, attrs, content) end

--- Removes all strip markers.
--- @param s string
--- @return string
function text.unstrip(s) end

--- Removes nowiki strip markers.
--- @param s string
--- @return string
function text.unstripNoWiki(s) end

--- Removes all strip markers.
--- @param s string
--- @return string
function text.killMarkers(s) end

--- Splits a string by pattern.
--- @param text string
--- @param pattern string
--- @param plain boolean|nil
--- @return string[]
function text.split(text, pattern, plain) end

--- Returns an iterator that splits a string by pattern.
--- @param text string
--- @param pattern string
--- @param plain boolean|nil
--- @return fun(): string
function text.gsplit(text, pattern, plain) end

--- Joins a list into a human-readable string.
--- @param list table
--- @param separator string|nil
--- @param conjunction string|nil
--- @return string
function text.listToText(list, separator, conjunction) end

--- Truncates text to a given length with ellipsis.
--- @param text string
--- @param length number
--- @param ellipsis string|nil
--- @param adjustLength boolean|nil
--- @return string
function text.truncate(text, length, ellipsis, adjustLength) end

--- Encodes a value as JSON.
--- @param value any
--- @param flags number|nil
--- @return string
function text.jsonEncode(value, flags) end

--- Decodes a JSON string.
--- @param json string
--- @param flags number|nil
--- @return any
function text.jsonDecode(json, flags) end
