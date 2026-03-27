--- Scribunto mw.title (REL1_43)
--- @meta

--- @class mw.title.static
local title_static = {}

--- Creates a title object from text or page ID.
--- @param text_or_id string|number
--- @param defaultNamespace number|nil
--- @return mw.title|nil
function title_static.new(text_or_id, defaultNamespace) end

--- Creates a title object from components.
--- @param ns number|string
--- @param title string
--- @param fragment string|nil
--- @param interwiki string|nil
--- @return mw.title|nil
function title_static.makeTitle(ns, title, fragment, interwiki) end

--- Returns the title object for the current page.
--- @return mw.title
function title_static.getCurrentTitle() end

--- Tests equality of two title objects.
--- @param a mw.title
--- @param b mw.title
--- @return boolean
function title_static.equals(a, b) end

--- Compares two title objects.
--- @param a mw.title
--- @param b mw.title
--- @return -1|0|1
function title_static.compare(a, b) end

--- @class mw.title
--- @field id number Page ID (expensive).
--- @field interwiki string
--- @field namespace number
--- @field nsText string
--- @field text string Title text without namespace prefix.
--- @field prefixedText string Namespace:title.
--- @field fullText string prefixedText#fragment.
--- @field fragment string Read-write.
--- @field rootText string
--- @field baseText string
--- @field subpageText string
--- @field contentModel string Expensive.
--- @field exists boolean Expensive.
--- @field isRedirect boolean Expensive.
--- @field isExternal boolean
--- @field isSpecialPage boolean|nil
--- @field isContentPage boolean|nil
--- @field isTalkPage boolean|nil
--- @field isSubpage boolean
--- @field canTalk boolean|nil
--- @field subjectNsText string|nil
--- @field talkNsText string|nil
--- @field rootPageTitle mw.title
--- @field basePageTitle mw.title
--- @field talkPageTitle mw.title|nil
--- @field subjectPageTitle mw.title
--- @field redirectTarget mw.title|false
--- @field protectionLevels table
--- @field cascadingProtection table
--- @field file table|nil File metadata if file page.
--- @field pageLang mw.language
--- @field content string|false Page wikitext content.
--- @field categories table
local title = {}

--- Tests if this title is in the given namespace.
--- @param ns string|number
--- @return boolean
function title:inNamespace(ns) end

--- Tests if this title is in any of the given namespaces.
--- @param ... string|number
--- @return boolean
function title:inNamespaces(...) end

--- Tests if this title has the given subject namespace.
--- @param ns string|number
--- @return boolean
function title:hasSubjectNamespace(ns) end

--- Tests if this title is a subpage of another.
--- @param title mw.title
--- @return boolean
function title:isSubpageOf(title) end

--- Creates a subpage title.
--- @param text string
--- @return mw.title
function title:subPageTitle(text) end

--- Returns the partial URL-encoded title.
--- @return string
function title:partialUrl() end

--- Returns a full URL.
--- @param query string|table|nil
--- @param proto string|nil
--- @return string
function title:fullUrl(query, proto) end

--- Returns a local URL.
--- @param query string|table|nil
--- @return string
function title:localUrl(query) end

--- Returns a canonical URL.
--- @param query string|table|nil
--- @return string
function title:canonicalUrl(query) end

--- @deprecated Use title.content instead.
--- @return string|nil
function title:getContent() end
