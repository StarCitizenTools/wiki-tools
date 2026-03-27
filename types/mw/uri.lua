--- Scribunto mw.uri (REL1_43)
--- @meta

--- @class mw.uri.static
local uri_static = {}

--- URL-encodes a string.
--- @param s string
--- @param enctype 'QUERY'|'PATH'|'WIKI'|nil Defaults to 'QUERY'.
--- @return string
function uri_static.encode(s, enctype) end

--- URL-decodes a string.
--- @param s string
--- @param enctype 'QUERY'|'PATH'|'WIKI'|nil Defaults to 'QUERY'.
--- @return string
function uri_static.decode(s, enctype) end

--- Encodes a string for use as a URL anchor/fragment.
--- @param s string
--- @return string
function uri_static.anchorEncode(s) end

--- Creates a URI object.
--- @param s string|table|nil Nil uses the current page URL.
--- @return mw.uri
function uri_static.new(s) end

--- Returns a local URL as a URI object.
--- @param page string
--- @param query string|table|nil
--- @return mw.uri|nil
function uri_static.localUrl(page, query) end

--- Returns a full URL as a URI object.
--- @param page string
--- @param query string|table|nil
--- @return mw.uri|nil
function uri_static.fullUrl(page, query) end

--- Returns a canonical URL as a URI object.
--- @param page string
--- @param query string|table|nil
--- @return mw.uri|nil
function uri_static.canonicalUrl(page, query) end

--- Validates a URI table.
--- @param obj table
--- @return boolean, string
function uri_static.validate(obj) end

--- Parses a query string into a table.
--- @param s string
--- @param i number|nil
--- @param j number|nil
--- @return table
function uri_static.parseQueryString(s, i, j) end

--- Builds a query string from a table.
--- @param qs table
--- @return string
function uri_static.buildQueryString(qs) end

--- @class mw.uri
--- @field protocol string|nil
--- @field user string|nil
--- @field password string|nil
--- @field host string|nil
--- @field port number|nil
--- @field path string|nil
--- @field query table|nil
--- @field fragment string|nil
--- @field userInfo string|nil Computed: user:password.
--- @field hostPort string|nil Computed: host:port.
--- @field authority string|nil Computed: userInfo@hostPort.
--- @field queryString string|nil Computed: serialized query string.
--- @field relativePath string Computed: path?queryString#fragment.
local uri = {}

--- Parses a URI string and populates fields.
--- @param s string
--- @return mw.uri self
function uri:parse(s) end

--- Returns a copy of this URI object.
--- @return mw.uri
function uri:clone() end

--- Merges key-value pairs into the query.
--- @param parameters table
--- @return mw.uri self
function uri:extend(parameters) end

--- Validates this URI.
--- @return boolean, string
function uri:validate() end
