require('strict')

--- @module Mainpage/Config
--- Loads [[Module:Mainpage/settings.json]], the one page an editor changes.
---
--- Everything the page shows that is not prose in a module lives there: the
--- featured article, the running event, the build chips, the hero, and the two
--- link lists. One file rather than a settings template plus a navigation file,
--- because the split cost more than it bought — two pages to find, two formats
--- to learn, and a delimiter convention for list values that a real array does
--- not need.
---
--- JSON rather than a `#switch` template for three reasons that matter to the
--- people editing it: MediaWiki refuses to SAVE invalid JSON, so the page
--- cannot be left broken; a list is a real array, so nothing has to be escaped
--- or separated; and the build chips are a list of objects rather than
--- `patch1type` / `patch2type` / `patch3type` flattened into numbered keys.
---
--- The cost, paid deliberately: JSON has no comments, so the guidance that used
--- to sit inline lives in the file's own `_readme` and in Module:Mainpage/doc.

local DATA_PAGE = 'Module:Mainpage/settings.json'

local p = {}

local data

--- Converts one loaded value into plain Lua.
---
--- `mw.loadJsonData` hands back a read-only table whose metatable breaks the
--- length operator and `next()`. Copying once, here, confines that to this
--- function: every caller downstream gets an ordinary table it can measure,
--- iterate and test however it likes.
---
--- Two normalisations happen on the way through, so the rest of the module
--- never has to think about either:
---  * a blank string becomes nil, so clearing a value in the JSON does the same
---    thing as deleting its line;
---  * an array is rebuilt compacted, so a blank entry leaves no hole for
---    `ipairs` to stop at.
---
--- Keys beginning with an underscore are guidance for whoever is editing the
--- file, not data, and are dropped.
---
--- @param value any
--- @return any
local function toPlain(value)
	if type(value) == 'string' then
		local trimmed = mw.text.trim(value)
		return trimmed ~= '' and trimmed or nil
	end

	if type(value) ~= 'table' then
		return value
	end

	-- An array. `value[1] ~= nil` rather than `#value`, because the first pass
	-- runs on the loadJsonData table itself, where the length operator lies.
	if value[1] ~= nil then
		local list = {}
		for _, item in ipairs(value) do
			local converted = toPlain(item)
			if converted ~= nil then
				list[#list + 1] = converted
			end
		end
		return list
	end

	local out = {}
	for key, item in pairs(value) do
		if type(key) ~= 'string' or key:sub(1, 1) ~= '_' then
			out[key] = toPlain(item)
		end
	end
	return out
end

--- @return table
local function load()
	if not data then
		-- loadJsonData RAISES on a missing page and on invalid JSON. The second
		-- should be impossible, since MediaWiki validates JSON at save, but the
		-- page can still be moved or deleted — and that must cost the page its
		-- settings rather than its render.
		local ok, loaded = pcall(mw.loadJsonData, DATA_PAGE)
		data = ok and toPlain(loaded) or {}
	end
	return data
end

--- One top-level section of the settings, always a table.
---
--- Returns an empty table for a section that is missing or blank, so a caller
--- can read a field off it without testing first: an absent section and a
--- section with nothing set behave identically, which is what makes "clear the
--- value to remove the thing" work.
---
--- @param name string
--- @return table
function p.section(name)
	local value = load()[name]
	return type(value) == 'table' and value or {}
end

--- One top-level list, always an array.
---
--- @param name string
--- @return table[]
function p.list(name)
	local value = load()[name]
	if type(value) ~= 'table' or value[1] == nil then
		return {}
	end
	return value
end

--- Turns a settings time into ISO 8601 UTC, or nil.
---
--- Accepts `YYYY-MM-DD`, optionally followed by `HH:MM` or `HH:MM:SS` with
--- either a space or a `T` between them, and tolerates a trailing `UTC` or `Z`.
--- Anything else returns nil.
---
--- The strictness is the point. The settings file is edited by hand, so it will
--- receive free-form dates and placeholders like "TBA". Module:Countdown RAISES
--- on a date it cannot read, and a raise takes down the whole page — so an
--- unreadable date has to cost the clock and nothing else.
---
--- Here rather than in the card that draws the clock, because both event cards
--- read the same two keys and neither should own the rule for what they accept.
---
--- @param value string|nil
--- @return string|nil
function p.toIso(value)
	if not value then
		return nil
	end

	local raw = mw.text.trim(value)
	raw = (raw:gsub('%s*[Uu][Tt][Cc]$', ''))
	raw = (raw:gsub('%s*[Zz]$', ''))

	local date, time = mw.text.trim(raw):match('^(%d%d%d%d%-%d%d%-%d%d)[T ]?(.*)$')
	if not date then
		return nil
	end

	time = mw.text.trim(time)
	if time == '' then
		return date .. 'T00:00:00Z'
	end

	local hour, minute, second = time:match('^(%d%d):(%d%d):(%d%d)$')
	if not hour then
		hour, minute = time:match('^(%d%d):(%d%d)$')
		second = '00'
	end
	if not hour then
		return nil
	end

	return string.format('%sT%s:%s:%sZ', date, hour, minute, second)
end

--- The build the wiki is running: the first patch whose channel is LIVE, or —
--- when an editor has not marked one — simply the first with a name.
---
--- Resolved HERE and not in each consumer, because two of them ask: the chip
--- that gets the filled marker and the card that says "New in …" have to name
--- the same build, and they would drift the moment either grew its own rule.
---
--- The fallback is deliberate. Forgetting `"channel": "LIVE"` should cost the
--- filled marker, not the patch card — a silently missing card is the harder
--- failure to notice.
---
--- @return table|nil
function p.livePatch()
	local patches = p.list('patches')

	for _, patch in ipairs(patches) do
		if patch.name and patch.channel and mw.ustring.upper(patch.channel) == 'LIVE' then
			return patch
		end
	end

	for _, patch in ipairs(patches) do
		if patch.name then
			return patch
		end
	end

	return nil
end

return p
