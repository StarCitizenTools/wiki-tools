require('strict')

--- SMW-value helpers for Module:DataGrid. mw.smw.ask returns each printout as a
--- formatted display string: numbers carry units and embed the nbsp as the literal
--- entity "&#160;"; page printouts return "[[:Target|Display]]"; file printouts
--- return "[[File:X.png|...]]"; multi-valued printouts arrive as arrays. These
--- helpers DECODE those shapes. classifyColumn decides only the distinction that is
--- reliable from markup -- page-link vs plain -- never number-vs-text (the scwSmart
--- gadget column type sorts plain columns numerically at render time).

local aggrid = require('mw.ext.aggrid')

local p = {}

-- Source thumbnail width in px. Display size is fixed by styles.css; this only
-- governs image resolution.
local IMAGE_WIDTH = 120

--- Decode a single scalar SMW value to clean text (HTML entities decoded, so the
--- "&#160;" nbsp leak becomes a real nbsp instead of "160").
--- @param value any
--- @return string|nil
function p.decodeScalar(value)
	if type(value) == 'table' then
		value = value.fulltext or value.fullText or value.text or value.label
	end
	if value == nil then
		return nil
	end
	return mw.text.decode(tostring(value), true)
end

--- Decode a (possibly multi-valued) SMW value to display text. Arrays join with
--- ", "; scalars pass through; nil stays nil.
--- @param value any
--- @return string|nil
function p.toText(value)
	if type(value) == 'table' and value[1] ~= nil then
		local parts = {}
		for _, v in ipairs(value) do
			local t = p.decodeScalar(v)
			if t and t ~= '' then
				parts[#parts + 1] = t
			end
		end
		return table.concat(parts, ', ')
	end
	return p.decodeScalar(value)
end

--- Parse a single SMW page value "[[:Target|Display]]" into target, display.
--- Returns nil when the value is not a single bracketed page link.
--- @param markup any
--- @return string|nil target
--- @return string|nil display
function p.parseLink(markup)
	if type(markup) == 'table' then
		markup = markup[1]
	end
	local s = p.decodeScalar(markup)
	if s == nil then
		return nil
	end
	local inner = s:match('^%[%[(.-)%]%]$')
	if not inner then
		return nil
	end
	local target = (inner:match('^([^|]*)') or ''):gsub('^:', '')
	if target == '' then
		return nil
	end
	return target, inner:match('|(.*)$')
end

--- Build a linked-thumbnail cell value (consumed by the aggridImage column type)
--- from "[[File:X.png|...]]" markup, linked to linkTarget. nil when the file is
--- absent or missing on-wiki.
--- @param markup any
--- @param linkTarget string|nil
--- @return table|nil
function p.buildThumb(markup, linkTarget)
	if type(markup) == 'table' then
		markup = markup[1]
	end
	local s = p.decodeScalar(markup)
	if s == nil then
		return nil
	end
	local inner = s:match('^%[%[(.-)%]%]$') or s
	local file = inner:match('^([^|]*)')
	if not file or file == '' then
		return nil
	end
	return aggrid.thumb(file, IMAGE_WIDTH, linkTarget and { link = linkTarget } or nil)
end

-- Lower-cased namespace prefixes that mark a value as a file (so a file printout is
-- not mistaken for a page link). Canonical "file"/"image" plus the wiki's localised
-- File namespace (id 6) name and aliases. Built once on first use.
local FILE_PREFIXES
local function filePrefixes()
	if FILE_PREFIXES then
		return FILE_PREFIXES
	end
	FILE_PREFIXES = { file = true, image = true }
	local ns = mw.site.namespaces[6]
	if ns then
		for _, name in ipairs({ ns.name, ns.canonicalName }) do
			if name and name ~= '' then
				FILE_PREFIXES[mw.ustring.lower(name)] = true
			end
		end
		for _, alias in ipairs(ns.aliases or {}) do
			FILE_PREFIXES[mw.ustring.lower(alias)] = true
		end
	end
	return FILE_PREFIXES
end

-- True when a decoded value string is a single bracketed File:/Image: link.
local function isFileMarkup(s)
	local inner = s:match('^%[%[(.-)%]%]$')
	if not inner then
		return false
	end
	local prefix = inner:match('^:?([^:|]+):')
	return prefix ~= nil and filePrefixes()[mw.ustring.lower(mw.text.trim(prefix))] == true
end

--- Classify an editor column from its non-nil values: 'link' when every non-empty
--- value is a single page link "[[...]]" (and not a file), else 'plain'. Number-vs-
--- text is deliberately NOT decided here. An all-empty list is 'plain'.
--- @param values any[]  non-nil mw.smw.ask values for this column (one per non-empty row)
--- @return string  'link' | 'plain'
function p.classifyColumn(values)
	local seen = false
	for _, v in ipairs(values) do
		-- A value is a string, a scalar SMW object, or a multi-valued array. Pass the
		-- array's first element through; the `or v` falls back to the whole value when
		-- it is not an array, letting decodeScalar field-resolve a scalar SMW object.
		local s = p.decodeScalar(type(v) == 'table' and v[1] or v)
		if s ~= nil and s ~= '' then
			seen = true
			if not s:match('^%[%[(.-)%]%]$') or isFileMarkup(s) then
				return 'plain'
			end
		end
	end
	return seen and 'link' or 'plain'
end

return p
