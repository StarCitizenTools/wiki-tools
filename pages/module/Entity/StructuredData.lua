require('strict')

local p = {}

local PROPERTIES_PAGE = 'Module:Entity/properties.json'

--- Returns the property prefix for the current page's namespace.
--- Main namespace uses no prefix (canonical storage). Other namespaces
--- are prefixed with their namespace text (e.g. "template_", "user_") so
--- test and template pages don't pollute canonical SMW queries.
---
--- @return string
local function getPrefix()
	local nsText = mw.title.getCurrentTitle().nsText
	if nsText == '' then
		return ''
	end
	return nsText:lower():gsub(' ', '_') .. '_'
end

--- Legacy auto-transform: the implicit snake_case -> SMW display name SMW applied
--- pre-PR1 (ucfirst, underscores -> spaces). This remains the NAME PRODUCER so
--- stored property names are byte-identical; the manifest only flags registration.
--- @param key string
--- @return string
local function autoName(key)
	local spaced = key:gsub('_', ' ')
	return (spaced:gsub('^%l', string.upper))
end

--- Resolve an emitter key to (smwName, registered). The name is always autoName(key)
--- (byte-identical); `registered` is true iff a static manifest entry or a %patterns
--- keyMatch covers it.
--- @param manifest table decoded properties.json
--- @param key string
--- @return string name
--- @return boolean registered
local function resolveName(manifest, key)
	local display = autoName(key)
	if type(manifest[display]) == 'table' then
		return display, true
	end
	local patterns = manifest['%patterns']
	if type(patterns) == 'table' then
		for _, pat in ipairs(patterns) do
			if type(pat) == 'table' and type(pat.keyMatch) == 'string' and key:match(pat.keyMatch) then
				return display, true
			end
		end
	end
	return display, false
end

--- Stores structured data as SMW properties on the current page.
--- @param data table<string, any> Flat snake_case key -> value
--- @return boolean success
--- @return string|nil error
--- @return string[]|nil unregistered Emitter keys absent from properties.json (+%patterns)
function p.store(data)
	local manifest = mw.loadJsonData(PROPERTIES_PAGE)
	local prefix = getPrefix()
	local prefixed = {}
	local unregistered = {}
	for k, v in pairs(data) do
		local name, registered = resolveName(manifest, k)
		if not registered then
			unregistered[#unregistered + 1] = k
		end
		prefixed[prefix .. name] = v
	end

	local success, err = pcall(mw.smw.set, prefixed)
	if not success then
		return false, 'SMW storage failed: ' .. tostring(err), unregistered
	end
	if #unregistered > 0 then
		return true, nil, unregistered
	end
	return true, nil, nil
end

-- Test-only exports (no mw.smw needed to exercise name resolution).
p._internal = {
	autoName = autoName,
	resolveName = resolveName,
}

return p
