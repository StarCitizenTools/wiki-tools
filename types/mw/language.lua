--- Scribunto mw.language (REL1_43)
--- @meta

--- @class mw.language.static
local language_static = {}

--- @param code string
--- @return boolean
function language_static.isSupportedLanguage(code) end

--- @param code string
--- @return boolean
function language_static.isKnownLanguageTag(code) end

--- @param code string
--- @return boolean
function language_static.isValidCode(code) end

--- @param code string
--- @return boolean
function language_static.isValidBuiltInCode(code) end

--- @param code string
--- @param inLanguage string|nil
--- @return string
function language_static.fetchLanguageName(code, inLanguage) end

--- @param inLanguage string|nil
--- @param include string|nil
--- @return table<string, string>
function language_static.fetchLanguageNames(inLanguage, include) end

--- @param code string
--- @return string[]
function language_static.getFallbacksFor(code) end

--- Creates a language object.
--- @param code string
--- @return mw.language
function language_static.new(code) end

--- Returns a language object for the wiki's content language.
--- @return mw.language
function language_static.getContentLanguage() end

--- @class mw.language
--- @field code string
local language = {}

--- @return string
function language:toBcp47Code() end

--- @param s string
--- @return string
function language:lcfirst(s) end

--- @param s string
--- @return string
function language:ucfirst(s) end

--- @param s string
--- @return string
function language:lc(s) end

--- @param s string
--- @return string
function language:uc(s) end

--- @param s string
--- @return string
function language:caseFold(s) end

--- @param n number|string
--- @return string
function language:formatNum(n) end

--- @param format string
--- @param ... any
--- @return string
function language:formatDate(format, ...) end

--- @param seconds number
--- @param ... any
--- @return string
function language:formatDuration(seconds, ...) end

--- @param seconds number
--- @param ... any
--- @return table
function language:getDurationIntervals(seconds, ...) end

--- @param n number
--- @param ... string
--- @return string
function language:convertPlural(n, ...) end

--- Alias for convertPlural.
--- @param n number
--- @param ... string
--- @return string
function language:plural(n, ...) end

--- @param word string
--- @param case string
--- @return string
function language:convertGrammar(word, case) end

--- Parser function compat (reversed arg order from convertGrammar).
--- @param case string
--- @param word string
--- @return string
function language:grammar(case, word) end

--- @param what string
--- @param ... string
--- @return string
function language:gender(what, ...) end

--- @return boolean
function language:isRTL() end

--- @return string
function language:getCode() end

--- @return 'rtl'|'ltr'
function language:getDir() end

--- @param opposite boolean|nil
--- @return string
function language:getDirMark(opposite) end

--- @param opposite boolean|nil
--- @return string
function language:getDirMarkEntity(opposite) end

--- @param direction string|nil 'forwards'|'backwards'|'left'|'right'|'up'|'down'
--- @return string
function language:getArrow(direction) end

--- @return string[]
function language:getFallbackLanguages() end

--- @param s string
--- @return number
function language:parseFormattedNumber(s) end
