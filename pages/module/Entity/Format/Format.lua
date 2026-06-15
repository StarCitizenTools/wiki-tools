require('strict')

--- @module Entity/Format
--- Generic, stateless display helpers for the Entity system: number formatting,
--- HTML list building, English list joining, and external-site link assembly.

local p = {}

local lang = mw.getContentLanguage()

--- Formats a numeric value with content-language digit grouping
--- (e.g. 1480 -> "1,480"). Returns nil for nil so callers can collapse
--- empty rows; passes non-numeric values through unchanged.
---
--- @param value number|string|nil
--- @return string|nil
function p.formatNum(value)
	local number = tonumber(value)
	if number == nil then
		return value ~= nil and tostring(value) or nil
	end
	return lang:formatNum(number)
end

--- Wraps display text in a span coloured by the sign of `value`: positive ->
--- --color-success, negative -> --color-destructive. Zero or a non-numeric value
--- returns the text unchanged (no span). For "good when positive, bad when
--- negative" values such as modifiers or deltas (e.g. a g-force bonus vs penalty).
---
--- @param text string The already-formatted display text.
--- @param value number|string The signed value driving the colour.
--- @return string
function p.colorBySign(text, value)
	local number = tonumber(value)
	if number == nil or number == 0 then
		return text
	end
	local color = number > 0 and 'var(--color-success)' or 'var(--color-destructive)'
	return tostring(mw.html.create('span'):css('color', color):wikitext(text))
end

--- Joins a list of strings into natural English with Oxford comma.
--- Examples: {} → nil; {A} → "A"; {A,B} → "A and B"; {A,B,C} → "A, B, and C".
---
--- @param list string[]
--- @return string|nil
function p.joinAnd(list)
	local n = #list
	if n == 0 then
		return nil
	end
	if n == 1 then
		return list[1]
	end
	if n == 2 then
		return list[1] .. ' and ' .. list[2]
	end
	return table.concat(list, ', ', 1, n - 1) .. ', and ' .. list[n]
end

--- Builds HTML list markup from a list of strings for use in infobox values
--- that are semantically lists. Returns the single value directly when there
--- is only one entry (avoids list markup overhead for a single element), or
--- nil when the list is empty.
---
--- @param list string[]
--- @return string|nil
function p.buildHtmlList(list)
	if not list or #list == 0 then
		return nil
	end
	if #list == 1 then
		return list[1]
	end
	return '<ul><li>' .. table.concat(list, '</li><li>') .. '</li></ul>'
end

--- Builds a joined wikitext string of external links from site definitions.
--- Each definition is either { label, format, data } or { label, arg }.
--- Returns nil if no links can be built.
---
--- @param siteDefs table[] List of site link definitions
--- @param dataLookup table<string, string> Lookup table mapping data/arg keys to values
--- @return string|nil Joined wikitext (' · ' separated) or nil when empty
function p.buildSiteLinks(siteDefs, dataLookup)
	local links = {}

	for _, def in ipairs(siteDefs) do
		local url

		if def.arg then
			url = dataLookup[def.arg]
		elseif def.format and def.data then
			local value = dataLookup[def.data]
			if value then
				url = string.format(def.format, mw.uri.encode(value, 'QUERY'))
			end
		end

		if url then
			table.insert(links, '[' .. url .. ' ' .. def.label .. ']')
		end
	end

	if #links == 0 then
		return nil
	end

	return table.concat(links, ' · ')
end

return p
