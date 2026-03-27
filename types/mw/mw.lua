--- Scribunto mw global API (REL1_43)
--- @see https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual
--- @meta

--- @class mw
--- @field html mw.html.static
--- @field text mw.text
--- @field uri mw.uri.static
--- @field ustring mw.ustring
--- @field language mw.language.static
--- @field message mw.message.static
--- @field title mw.title.static
--- @field hash mw.hash
--- @field ext mw.ext
mw = {}

--- Converts all arguments to strings and concatenates with tab separator.
--- @param ... any
--- @return string
function mw.allToString(...) end

--- Appends all arguments (as strings) to the log buffer.
--- @param ... any
function mw.log(...) end

--- Dumps an object to the log buffer with an optional prefix.
--- @param object any
--- @param prefix string|nil
function mw.logObject(object, prefix) end

--- Returns a human-readable string representation of an object.
--- @param object any
--- @return string
function mw.dumpObject(object) end

--- Clears the internal log buffer.
function mw.clearLogBuffer() end

--- Returns the contents of the log buffer.
--- @return string
function mw.getLogBuffer() end

--- Returns true if the current invocation is being substed.
--- @return boolean
function mw.isSubsting() end

--- Increments the expensive function counter.
function mw.incrementExpensiveFunctionCount() end

--- Adds a warning to parser output.
--- @param text string
function mw.addWarning(text) end

--- Loads a data module and returns a read-only table proxy. Cached per module.
--- @param module string
--- @return table
function mw.loadData(module) end

--- Loads a JSON data page and returns a read-only table proxy.
--- @param module string
--- @return table
function mw.loadJsonData(module) end

--- Returns the current frame object.
--- @return mw.frame
function mw.getCurrentFrame() end

--- Deep-clones a value.
--- @param val any
--- @return any
function mw.clone(val) end

--- Returns a language object for the given code.
--- @param code string
--- @return mw.language
function mw.getLanguage(code) end

--- Returns a language object for the wiki's content language.
--- @return mw.language
function mw.getContentLanguage() end

--- @class mw.ext
--- @field tabber mw.ext.tabber

--- @class mw.ext.tabber
mw.ext.tabber = {}

--- Renders tabber content.
--- @param data table Array of { label: string, content: string }.
--- @return mw.html|string
function mw.ext.tabber.render(data) end
