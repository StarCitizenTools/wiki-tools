require('strict')

--- SMW-value decoders shared by Module:AGGridColumns kinds and consumers.
--- mw.smw.ask returns formatted display strings (numbers carry units + the literal
--- entity "&#160;"; page printouts return "[[:Target|Display]]"; files
--- "[[File:X|...]]"; multi-valued printouts arrive as arrays). These decode those
--- shapes. Lifted from the former Module:DataGrid/Util, plus toNumber/buildLinkList
--- (from the former PledgeVehicleGrid) and cloneFormat.

local aggrid = require('mw.ext.aggrid')

local p = {}

--- Source thumbnail width in px (display size is fixed in styles.css).
p.IMAGE_WIDTH = 120

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

--- Decode a (possibly multi-valued) SMW value to display text; arrays join ", ".
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

--- Coerce to a number: entity-decode (drops the nbsp "160" leak), then strip
--- currency/units/grouping. nil when not parseable.
--- @param value any
--- @return number|nil
function p.toNumber(value)
	if type(value) == 'number' then
		return value
	end
	if type(value) == 'table' and value[1] ~= nil then
		value = value[1]
	end
	local text = p.decodeScalar(value)
	if text == nil then
		return nil
	end
	return tonumber((text:gsub('[^%d%.%-]', '')))
end

--- Parse a single SMW page value "[[:Target|Display]]" -> target, display. nil when
--- not a single bracketed page link.
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

--- Build a linked-thumbnail cell value (for the aggridImage type) from
--- "[[File:X|...]]" markup, linked to linkTarget. nil when the file is absent.
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
	return aggrid.thumb(file, p.IMAGE_WIDTH, linkTarget and { link = linkTarget } or nil)
end

--- Build a link-list cell value (for the aggridLinkList type) from a (possibly
--- multi-valued) page printout. nil when no resolvable target.
--- @param value any
--- @return table|nil
function p.buildLinkList(value)
	if value == nil then
		return nil
	end
	local items = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local targets = {}
	for _, m in ipairs(items) do
		local target = p.parseLink(m)
		if target then
			targets[#targets + 1] = target
		end
	end
	if #targets == 0 then
		return nil
	end
	return aggrid.linkList(targets)
end

--- Build a multi-value list cell value (via aggrid.list, rendered by the aggridLinkList
--- type) from a (possibly multi-valued) printout. Each item becomes a plain-text tag,
--- or a { link, text } when it parses as a single page link — so a multi-valued page
--- property still links while a plain-text property (e.g. Industry) stays text. The
--- extension's set filter splits the resulting cell into one option per value. nil when
--- nothing non-empty resolves.
--- @param value any
--- @return table|nil  { links = { {text}|{text,href}, ... } }
function p.buildValueList(value)
	if value == nil then
		return nil
	end
	local raw = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local items = {}
	for _, m in ipairs(raw) do
		local target, display = p.parseLink(m)
		if target then
			items[#items + 1] = { link = target, text = display }
		else
			local text = p.decodeScalar(m)
			if text ~= nil and text ~= '' then
				items[#items + 1] = text
			end
		end
	end
	if #items == 0 then
		return nil
	end
	return aggrid.list(items)
end

-- Lower-cased namespace prefixes marking a value as a file. Built once.
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

local function isFileMarkup(s)
	local inner = s:match('^%[%[(.-)%]%]$')
	if not inner then
		return false
	end
	local prefix = inner:match('^:?([^:|]+):')
	return prefix ~= nil and filePrefixes()[mw.ustring.lower(mw.text.trim(prefix))] == true
end

--- Classify an editor column from its non-nil values:
---  'list'  — any value is multi-valued (a sequence); render as a splitting value list
---            (one set-filter option per value), covering both page links and plain text;
---  'link'  — every non-empty single value is a single page link (not a file);
---  'plain' — otherwise (the default). Never number-vs-text.
--- The list check is a full first pass so the result never depends on row order. nil/
--- keyed-object scalars (e.g. { fulltext = … }) are not sequences, so they classify as
--- single values, not lists.
--- @param values any[]
--- @return string  'list' | 'link' | 'plain'
function p.classifyColumn(values)
	for _, v in ipairs(values) do
		if type(v) == 'table' and v[1] ~= nil then
			return 'list'
		end
	end
	local seen = false
	for _, v in ipairs(values) do
		local s = p.decodeScalar(v)
		if s ~= nil and s ~= '' then
			seen = true
			if not s:match('^%[%[(.-)%]%]$') or isFileMarkup(s) then
				return 'plain'
			end
		end
	end
	return seen and 'link' or 'plain'
end

--- Shallow-copy a format spec. Scribunto's PHP serializer rejects the same table
--- twice ("Cannot pass circular reference to PHP"), so each colDef needs its own.
--- @param fmt table|nil
--- @return table|nil
function p.cloneFormat(fmt)
	if fmt == nil then
		return nil
	end
	local copy = {}
	for k, v in pairs(fmt) do
		copy[k] = v
	end
	return copy
end

p._internal = { isFileMarkup = isFileMarkup }

return p
