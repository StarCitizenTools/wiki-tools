require('strict')

--- @module Entity/Editorial
--- Resolves a kind's editorial (wikitext) fields against its API data per a
--- manifest, stamping provenance. The single seam where editor-supplied values
--- and API values reconcile: editor input wins (the API is sometimes wrong),
--- fills gaps the API lacks (concept ships), and every manual value is recorded
--- (`fill`/`override`) so it can be retired when the API catches up.

local p = {}

--- Strip wiki-link markup, keeping display text: [[A|B]] -> B, [[A]] -> A.
--- @param text string|nil
--- @return string|nil
local function delink(text)
	if not text or text == '' then
		return text
	end
	text = text:gsub('%[%[[^%]|]*|([^%]]-)%]%]', '%1')
	text = text:gsub('%[%[([^%]]-)%]%]', '%1')
	return text
end

--- Extract the link TARGET (page title) for SMW Page properties.
--- @param text string|nil
--- @return string|nil
local function pageTitle(text)
	if not text or text == '' then
		return text
	end
	text = text:gsub('%[%[([^%]|]*)|[^%]]-%]%]', '%1')
	text = text:gsub('%[%[([^%]]-)%]%]', '%1')
	return text
end

--- Split a semicolon-separated list into trimmed, non-empty parts.
--- @param text string
--- @return string[]
local function splitSemi(text)
	local parts = {}
	for part in (text .. ';'):gmatch('([^;]*);') do
		part = mw.text.trim(part)
		if part ~= '' then
			parts[#parts + 1] = part
		end
	end
	return parts
end

--- Parse editor numeric input into a bare number. Strips thousands separators,
--- magnitude suffixes (K/M), and any trailing unit words/symbols, so
--- "900K µSCU" -> 900000, "26,245" -> 26245. Returns nil when no number leads.
--- @param v string|number
--- @return number|nil
local function parseNumber(v)
	if type(v) == 'number' then
		return v
	end
	local s = mw.text.trim(tostring(v)):gsub(',', '')
	local num, suffix = s:match('^(%-?%d*%.?%d+)%s*([kKmM]?)')
	if not num then
		return nil
	end
	local n = tonumber(num)
	if suffix == 'k' or suffix == 'K' then
		n = n * 1000
	elseif suffix == 'm' or suffix == 'M' then
		n = n * 1000000
	end
	return n
end

local TRANSFORMS = {
	number = parseNumber,
	text = function(v)
		return mw.text.trim(tostring(v))
	end,
	page = function(v)
		return pageTitle(v)
	end,
	pageList = function(v)
		local out = {}
		for _, item in ipairs(splitSemi(v)) do
			out[#out + 1] = pageTitle(item)
		end
		return out
	end,
	-- Star-Citizen-specific: normalize a patch reference to its canonical Update
	-- page. "Alpha 4.8.0" -> "Update:Star Citizen Alpha 4.8.0"; a [[link]] yields
	-- its target; a bare "Star Citizen …" redirect title is namespaced.
	patchPage = function(v)
		local t = mw.text.trim(pageTitle(v))
		if t == '' then
			return nil
		end
		if t:match('^Update:') then
			return t
		end
		if t:match('^Star Citizen ') then
			return 'Update:' .. t
		end
		return 'Update:Star Citizen ' .. t
	end,
}

--- Dig a dotted path out of a possibly-nil table. "speed.scm" -> apiData.speed.scm.
--- @param tbl table|nil
--- @param path string|nil
--- @return any
local function dig(tbl, path)
	if type(tbl) ~= 'table' or not path then
		return nil
	end
	local cur = tbl
	for key in path:gmatch('[^.]+') do
		if type(cur) ~= 'table' then
			return nil
		end
		cur = cur[key]
	end
	return cur
end

--- Numeric-aware equality so a hand-typed "26245" matching API 26245 is not
--- flagged as an override (formatting noise must not read as a correction).
--- @return boolean
local function sameValue(a, b)
	local na, nb = tonumber(a), tonumber(b)
	if na ~= nil and nb ~= nil then
		return math.abs(na - nb) < 1e-6
	end
	return mw.text.trim(tostring(a)) == mw.text.trim(tostring(b))
end

--- @param apiData table|nil
--- @param args table
--- @param manifest table  field -> { arg, smw, apiPath?, transform?, default? }
--- @return table resolved  field -> { value, source, apiValue }
function p.resolve(apiData, args, manifest)
	local resolved = {}
	for field, def in pairs(manifest) do
		if field:sub(1, 1) ~= '%' then
			-- def.arg is a single template-arg name, or a list of aliases tried in
			-- order (first non-empty wins) — mirrors the legacy `[ARG_Series, ARG_Model]`.
			local raw
			if type(def.arg) == 'table' then
				for _, name in ipairs(def.arg) do
					local v = args[name]
					if type(v) == 'string' then
						v = mw.text.trim(v)
					end
					if v ~= nil and v ~= '' then
						raw = v
						break
					end
				end
			else
				raw = args[def.arg]
				if type(raw) == 'string' then
					raw = mw.text.trim(raw)
				end
			end
			if (raw == nil or raw == '') and def.default ~= nil then
				raw = def.default
			end

			local editorVal = nil
			if raw ~= nil and raw ~= '' then
				editorVal = def.transform and TRANSFORMS[def.transform](raw) or raw
			end
			local apiVal = def.apiPath and dig(apiData, def.apiPath) or nil

			local entry = nil
			if editorVal ~= nil and editorVal ~= '' then
				if def.apiPath == nil then
					entry = { value = editorVal, source = 'editorial', apiValue = nil }
				elseif apiVal == nil or apiVal == '' then
					entry = { value = editorVal, source = 'fill', apiValue = nil }
				elseif sameValue(editorVal, apiVal) then
					entry = { value = apiVal, source = 'api', apiValue = apiVal }
				else
					entry = { value = editorVal, source = 'override', apiValue = apiVal }
				end
			elseif apiVal ~= nil and apiVal ~= '' then
				entry = { value = apiVal, source = 'api', apiValue = apiVal }
			end

			-- table-valued editorial (pageList): keep only when non-empty.
			if entry and type(entry.value) == 'table' and #entry.value == 0 then
				entry = nil
			end
			if entry ~= nil then
				resolved[field] = entry
			end
		end
	end
	return resolved
end

--- Project resolved fields onto their SMW property names, and append the
--- `Manual API field` provenance list (fields the API should own but a human
--- supplied). Pure; the caller merges this into the structured-data write.
--- @param resolved table
--- @param manifest table
--- @return table<string, any>
function p.toStructuredData(resolved, manifest)
	local data = {}
	local manual = {}
	for field, entry in pairs(resolved) do
		local def = manifest[field]
		if def and def.smw then
			data[def.smw] = entry.value
		end
		if entry.source == 'fill' or entry.source == 'override' then
			manual[#manual + 1] = field
		end
	end
	if #manual > 0 then
		data['Manual API field'] = manual
	end
	return data
end

--- @param resolved table
--- @return boolean
function p.hasManualApiData(resolved)
	for _, entry in pairs(resolved) do
		if entry.source == 'fill' or entry.source == 'override' then
			return true
		end
	end
	return false
end

--- A read-only display-merge view over a `resolved` editorial table
--- (field -> { value, source, apiValue }). Wraps the table once so section
--- builders read the display value and its provenance without poking at entry
--- internals. Replaces the per-kind `effective`/`editorialValue` helpers.
local View = {}
View.__index = View

--- The display value for a field: the editorial-resolved value when the field
--- resolved (encodes override/fill/api), else the caller's `fallback` (default
--- nil). Pass the API fallback for overlap fields; omit it for pure-editorial
--- fields. Returns the raw stored value — callers do their own formatting.
--- @param field string
--- @param fallback any|nil
--- @return any
function View:value(field, fallback)
	local entry = self._resolved[field]
	if entry ~= nil then
		return entry.value
	end
	return fallback
end

--- The provenance of a field's displayed value (for future "where did this come
--- from" display). nil when the field did not resolve.
---   'api'      — the API's value (no editor input, or editor == API)
---   'override' — an editor value replacing a *different* API value
---   'wiki'     — editor-authored, nothing displaced (internal `fill` ∪ `editorial`)
--- @param field string
--- @return string|nil
function View:source(field)
	local entry = self._resolved[field]
	if entry == nil then
		return nil
	end
	local s = entry.source
	if s == 'api' or s == 'override' then
		return s
	end
	return 'wiki' -- 'fill' and 'editorial' both: editor-authored, nothing displaced
end

--- Wrap a `resolved` table in a display-merge view. Nil-safe: `view(nil)`
--- behaves like an empty resolved set (the getHeaderBadge path may pass nil).
--- @param resolved table|nil  field -> { value, source, apiValue }
--- @return table  view with :value(field[, fallback]) and :source(field)
function p.view(resolved)
	return setmetatable({ _resolved = type(resolved) == 'table' and resolved or {} }, View)
end

return p
