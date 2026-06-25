require('strict')

--- @module Entity/SubtypeResolver
--- The mechanical half of subtype dispatch shared by kinds whose resolveSubtype
--- selects a leaf by a string token: a `token → module path` lookup that requires
--- and returns the leaf module. The *derivation* of the token (a data field, a
--- flag ladder, a curated arg) stays per-kind; only this lookup is shared.
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

return p
