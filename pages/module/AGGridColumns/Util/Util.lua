require('strict')

--- Stored-value decoders shared by Module:AGGridColumns kinds and consumers.
--- Values arrive as Bucket rows: a PAGE column holds a bare title, a repeated
--- column an array, and a TEXT column whatever its emitter stored, which may be
--- "[[:Target|Display]]" or "[[File:X|...]]" markup. Stored text is already
--- entity-decoded before the write (Entity/Editorial.toStoredValue); decodeScalar's
--- mw.text.decode is a cheap defensive pass, not a correction for a known-dirty
--- shape.

local aggrid = require('mw.ext.aggrid')

local p = {}

--- Source thumbnail width in px (display size is fixed in styles.css).
p.IMAGE_WIDTH = 120

--- @param value any
--- @return string|nil
function p.decodeScalar(value)
	if value == nil or type(value) == 'table' then
		return nil
	end
	return mw.text.decode(tostring(value), true)
end

--- Decode a (possibly multi-valued) stored value to display text; arrays join ", ".
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

--- Coerce to a number. A repeated column arrives as an array; only the first
--- value is used (kind=bar bypasses DataGrid's INTEGER/DOUBLE column
--- classification, so this still runs even where a caller never expects a
--- list). nil when not parseable.
--- @param value any
--- @return number|nil
function p.toNumber(value)
	if type(value) == 'table' then
		value = value[1]
	end
	if type(value) == 'number' then
		return value
	end
	if type(value) == 'string' then
		return tonumber(value)
	end
	return nil
end

--- Parse a single page link "[[:Target|Display]]" -> target, display. nil when
--- not a single bracketed page link; a `]` inside the brackets (a second link, as in
--- "[[A]] and [[B]]") is not one.
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
	local inner = s:match('^%[%[([^%]]-)%]%]$')
	if not inner then
		return nil
	end
	local target = (inner:match('^([^|]*)') or ''):gsub('^:', '')
	if target == '' then
		return nil
	end
	return target, inner:match('|(.*)$')
end

--- Page target from either "[[:Target|Display]]" markup or a bare title, the
--- shape a Bucket PAGE column carries. nil when empty. parseLink stays strict on purpose:
--- DataGrid types columns from the manifest, not from parseLink or its values.
--- @param value any
--- @return string|nil target
--- @return string|nil display
function p.pageTarget(value)
	local target, display = p.parseLink(value)
	if target then
		return target, display
	end
	if type(value) == 'table' then
		value = value[1]
	end
	local s = p.decodeScalar(value)
	if s == nil or s == '' then
		return nil
	end
	return s, nil
end

--- Build a linked-thumbnail cell value (for the aggridImage type) from
--- "[[File:X|...]]" markup, linked to linkTarget. nil when the file is absent
--- or `aggrid.thumb` errors on it (an invalid title MediaWiki rejects), so one
--- bad filename drops its own cell rather than emptying the whole grid.
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
	local ok, thumb = pcall(aggrid.thumb, file, p.IMAGE_WIDTH, linkTarget and { link = linkTarget } or nil)
	if not ok then
		return nil
	end
	return thumb
end

--- Build a link-list cell value (for the aggridLinkList type) from a (possibly
--- multi-valued) page value or a list of bare titles. nil when no resolvable
--- target.
--- @param value any
--- @return table|nil
function p.buildLinkList(value)
	if value == nil then
		return nil
	end
	local items = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local targets = {}
	for _, m in ipairs(items) do
		local target = p.pageTarget(m)
		if target then
			targets[#targets + 1] = target
		end
	end
	if #targets == 0 then
		return nil
	end
	return aggrid.linkList(targets)
end

--- The single `[[...]]` link inside `text`, with the plain text before/after it
--- ('' either side of a whole-link item), when `text` has exactly one such link.
--- nil when `text` has no link or has two or more (item stays plain text). Finds
--- links with an unanchored search rather than parseLink's own `^...$` anchor: a
--- `^%[%[(.-)%]%]$` match still succeeds across two non-nested pairs (the lazy
--- `.-` only needs the string's own trailing `]]` to satisfy `$`), which would
--- otherwise merge "[[A]] and [[B]]" into one bogus link spanning both. Delegates
--- target/display extraction to parseLink (kept strict, whole-link-only) by
--- handing it the matched substring, so a `[[:Target|Label]]` link strips its
--- leading colon and yields `Label` the same way it does through parseLink directly.
--- @param text string
--- @return string|nil target
--- @return string|nil display
--- @return string|nil before
--- @return string|nil after
local function extractOneLink(text)
	local s, e = text:find('%[%[.-%]%]')
	if not s then
		return nil
	end
	if text:find('%[%[.-%]%]', e + 1) then
		return nil
	end
	local target, display = p.parseLink(text:sub(s, e))
	if not target then
		return nil
	end
	return target, display, text:sub(1, s - 1), text:sub(e + 1)
end

--- Build a multi-value list cell value (via aggrid.list, rendered by the aggridLinkList
--- type) from a (possibly multi-valued) stored value. Each item becomes a plain-text tag,
--- or a { link, text } when it wraps exactly one page link, anywhere in the item
--- ("50x [[Council Scrip]]" -> linked to Council Scrip, text "50x Council Scrip") —
--- so a multi-valued page property still links, a plain-text property (e.g.
--- Industry) stays text, and a quantity-prefixed link (a loot table entry) still
--- links despite the surrounding text. The extension's set filter splits the
--- resulting cell into one option per value. nil when nothing non-empty resolves.
--- @param value any
--- @return table|nil  { links = { {text}|{text,href}, ... } }
function p.buildValueList(value)
	if value == nil then
		return nil
	end
	local raw = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local items = {}
	for _, m in ipairs(raw) do
		local text = p.decodeScalar(m)
		if text ~= nil and text ~= '' then
			local target, display, before, after = extractOneLink(text)
			if target then
				items[#items + 1] = { link = target, text = mw.text.trim(before .. (display or target) .. after) }
			else
				items[#items + 1] = text
			end
		end
	end
	if #items == 0 then
		return nil
	end
	return aggrid.list(items)
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

return p
