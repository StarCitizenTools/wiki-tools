--- Scribunto frame object (REL1_43)
--- @meta

--- @class mw.frame
--- @field args table Table-like accessor for template arguments.
local frame = {}

--- Gets a single argument by name or index.
--- @param opt string|number|{ name: string }
--- @return { expand: fun(): string }|nil
function frame:getArgument(opt) end

--- Returns the parent frame, or nil.
--- @return mw.frame|nil
function frame:getParent() end

--- Creates a new child frame.
--- @param opt { title: string|nil, args: table|nil }
--- @return mw.frame
function frame:newChild(opt) end

--- Expands a template and returns the result.
--- @param opt { title: string, args: table|nil }
--- @return string
function frame:expandTemplate(opt) end

--- Calls a parser function and returns the result.
--- @param name string|{ name: string, args: table }
--- @param args table|string|number|nil
--- @param ... any
--- @return string
function frame:callParserFunction(name, args, ...) end

--- Calls a parser extension tag and returns the result.
--- @param name string|{ name: string, content: string|nil, args: table|nil }
--- @param content string|number|nil
--- @param args string|number|table|nil
--- @return string
function frame:extensionTag(name, content, args) end

--- Preprocesses wikitext and returns the result.
--- @param opt string|{ text: string }
--- @return string
function frame:preprocess(opt) end

--- Creates a parser value object from wikitext.
--- @param opt string|{ text: string }
--- @return { expand: fun(): string }
function frame:newParserValue(opt) end

--- Creates a parser value object from a template.
--- @param opt { title: string, args: table|nil }
--- @return { expand: fun(): string }
function frame:newTemplateParserValue(opt) end

--- Returns the title associated with this frame.
--- @return string
function frame:getTitle() end

--- @deprecated Use pairs(frame.args) instead.
--- @return function
function frame:argumentPairs() end
