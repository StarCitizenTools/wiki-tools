require('strict')

--- @module Entity/SubtypeResolver
--- The mechanical half of subtype dispatch shared by kinds whose resolveSubtype
--- selects a leaf by a string token: a `token → module path` lookup that requires
--- and returns the leaf module. The *derivation* of the token (a record field, a flag ladder) stays per-kind; the lookup and the curated-arg normalisation (familyArg) are shared.
--- Sibling of Module:Entity/TypeResolver (which resolves display metadata, not
--- behavior modules).

local p = {}

--- @param token string|nil  the dispatch token (e.g. apiData.type, or a vehicle family)
--- @param map table<string, string>  token → module path WITHOUT the 'Module:' prefix
--- @return table|nil  the required leaf module, or nil for nil/empty/unmapped token
function p.resolve(token, map)
	if type(token) ~= 'string' or token == '' then
		return nil
	end
	local path = map[token]
	if path == nil then
		return nil
	end
	return require('Module:' .. path)
end

--- The curated `|family=` arg as a dispatch token: trimmed and lowercased so
--- editors may write `Ship` or ` JumpPoint `, nil when absent, blank, or not a
--- string. Every kind's resolveSubtype reads the arg through here so the
--- normalisation cannot drift between kinds.
--- @param args table|nil
--- @return string|nil
function p.familyArg(args)
	if type(args) ~= 'table' or type(args.family) ~= 'string' then
		return nil
	end
	local token = mw.text.trim(args.family):lower()
	if token == '' then
		return nil
	end
	return token
end

return p
