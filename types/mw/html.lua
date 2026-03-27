--- Scribunto mw.html builder (REL1_43)
--- @meta

--- @class mw.html.static
local html_static = {}

--- Creates a new HTML builder node.
--- @param tagName string|nil Tag name, or nil/empty for a tagless container.
--- @param args { selfClosing: boolean|nil, parent: mw.html|nil }|nil
--- @return mw.html
function html_static.create(tagName, args) end

--- @class mw.html
--- @field nodes table Child nodes.
--- @field attributes table Attribute entries.
--- @field styles table Style entries.
--- @field tagName string|nil
--- @field parent mw.html|nil
--- @field selfClosing boolean
local html = {}

--- Appends a child node.
--- @param builder mw.html|nil
--- @return mw.html self
function html:node(builder) end

--- Appends wikitext strings as children.
--- @param ... string|number
--- @return mw.html self
function html:wikitext(...) end

--- Appends a newline.
--- @return mw.html self
function html:newline() end

--- Creates and appends a child tag. Returns the new child.
--- @param tagName string
--- @param args table|nil
--- @return mw.html child
function html:tag(tagName, args) end

--- Gets an attribute value.
--- @param name string
--- @return string|nil
function html:getAttr(name) end

--- Sets attribute(s). Pass a table to set multiple.
--- @param name string|table<string, string|number|nil>
--- @param val string|number|nil
--- @return mw.html self
function html:attr(name, val) end

--- Appends a CSS class.
--- @param class string|number|nil
--- @return mw.html self
function html:addClass(class) end

--- Sets CSS property. Pass a table to set multiple.
--- @param name string|number|table<string, string|number|nil>
--- @param val string|number|nil
--- @return mw.html self
function html:css(name, val) end

--- Appends raw CSS text.
--- @param css string|number|nil
--- @return mw.html self
function html:cssText(css) end

--- Returns the parent node, or self if no parent.
--- @return mw.html
function html:done() end

--- Traverses to the root node and returns it.
--- @return mw.html
function html:allDone() end
