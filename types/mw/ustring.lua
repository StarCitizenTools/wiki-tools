--- Scribunto mw.ustring — Unicode string library (REL1_43)
--- @meta

--- @class mw.ustring
--- @field maxStringLength number
--- @field maxPatternLength number
local ustring = {}

--- Returns the byte values of characters at positions i through j.
--- @param s string
--- @param i number|nil
--- @param j number|nil
--- @return number ...
function ustring.byte(s, i, j) end

--- Returns a string from Unicode codepoints.
--- @param ... number
--- @return string
function ustring.char(...) end

--- Finds a pattern in a string. Like string.find but for UTF-8.
--- @param s string
--- @param pattern string
--- @param init number|nil
--- @param plain boolean|nil
--- @return number|nil, number|nil, ...
function ustring.find(s, pattern, init, plain) end

--- Formats a string. Like string.format.
--- @param format string
--- @param ... any
--- @return string
function ustring.format(format, ...) end

--- Returns an iterator for pattern matches.
--- @param s string
--- @param pattern string
--- @return fun(): string, ...
function ustring.gmatch(s, pattern) end

--- Returns an iterator yielding Unicode codepoints.
--- @param s string
--- @param i number|nil
--- @param j number|nil
--- @return fun(): number
function ustring.gcodepoint(s, i, j) end

--- Substitutes pattern matches.
--- @param s string
--- @param pattern string
--- @param repl string|table|function
--- @param n number|nil
--- @return string, number
function ustring.gsub(s, pattern, repl, n) end

--- Returns the length in Unicode characters, or nil for invalid UTF-8.
--- @param s string
--- @return number|nil
function ustring.len(s) end

--- Converts to lowercase.
--- @param s string
--- @return string
function ustring.lower(s) end

--- Converts to uppercase.
--- @param s string
--- @return string
function ustring.upper(s) end

--- Finds a pattern match.
--- @param s string
--- @param pattern string
--- @param init number|nil
--- @return string|nil ...
function ustring.match(s, pattern, init) end

--- Repeats a string n times.
--- @param s string
--- @param n number
--- @return string
function ustring.rep(s, n) end

--- Returns a substring by character position.
--- @param s string
--- @param i number
--- @param j number|nil
--- @return string
function ustring.sub(s, i, j) end

--- Returns Unicode codepoints at positions i through j.
--- @param s string
--- @param i number|nil
--- @param j number|nil
--- @return number ...
function ustring.codepoint(s, i, j) end

--- Converts to NFC normalization form.
--- @param s string
--- @return string
function ustring.toNFC(s) end

--- Converts to NFD normalization form.
--- @param s string
--- @return string
function ustring.toNFD(s) end

--- Converts to NFKC normalization form.
--- @param s string
--- @return string
function ustring.toNFKC(s) end

--- Converts to NFKD normalization form.
--- @param s string
--- @return string
function ustring.toNFKD(s) end

--- Tests if a string is valid UTF-8.
--- @param s string
--- @return boolean
function ustring.isUtf8(s) end
