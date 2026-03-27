--- Scribunto mw.message (REL1_43)
--- @meta

--- @class mw.message.static
local message_static = {}

--- Creates a message object.
--- @param key string
--- @param ... string|number
--- @return mw.message
function message_static.new(key, ...) end

--- Creates a message with fallback keys.
--- @param ... string
--- @return mw.message
function message_static.newFallbackSequence(...) end

--- Creates a message from raw text.
--- @param msg string
--- @param ... string|number
--- @return mw.message
function message_static.newRawMessage(msg, ...) end

--- Wraps a value as a raw parameter.
--- @param value string|number
--- @return table
function message_static.rawParam(value) end

--- Wraps a value as a numeric parameter.
--- @param value string|number
--- @return table
function message_static.numParam(value) end

--- Returns the default message language.
--- @return mw.language|string
function message_static.getDefaultLanguage() end

--- @class mw.message
local message = {}

--- Adds parameters.
--- @param ... string|number|table
--- @return mw.message self
function message:params(...) end

--- Adds raw (unprocessed) parameters.
--- @param ... string|number
--- @return mw.message self
function message:rawParams(...) end

--- Adds numeric parameters.
--- @param ... string|number
--- @return mw.message self
function message:numParams(...) end

--- Sets the message language.
--- @param lang string|mw.language
--- @return mw.message self
function message:inLanguage(lang) end

--- Controls whether to look up in the database.
--- @param value boolean
--- @return mw.message self
function message:useDatabase(value) end

--- Returns the message text as plaintext.
--- @return string
function message:plain() end

--- Returns whether the message exists.
--- @return boolean
function message:exists() end

--- Returns whether the message is blank.
--- @return boolean
function message:isBlank() end

--- Returns whether the message is disabled.
--- @return boolean
function message:isDisabled() end
