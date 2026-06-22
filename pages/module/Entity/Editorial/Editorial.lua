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
			local raw = args[def.arg]
			if type(raw) == 'string' then
				raw = mw.text.trim(raw)
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

return p
