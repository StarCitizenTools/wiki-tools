require('strict')

--- @module Manufacturers
--- Registry of Star Citizen manufacturers. Exposes lookup by code or name,
--- returning a canonical record with code, name, short name, and wiki page.

local p = {}

--- Resolves a manufacturer by code (e.g. "AEGS") or full name (e.g.
--- "Aegis Dynamics"). Returns a record with all canonical forms, or nil
--- when the input doesn't match any known manufacturer.
---
--- Record fields:
---   code  — canonical manufacturer code
---   name  — full display name
---   short — short display name (falls back to name)
---   page  — wiki page title for links (falls back to name)
---
--- @param codeOrName string|nil
--- @return { code: string, name: string, short: string, page: string }|nil
function p.resolve(codeOrName)
	if not codeOrName then
		return nil
	end

	local data = mw.loadJsonData('Module:Manufacturers/data.json')

	-- Direct lookup by code (the common case)
	local entry = data[codeOrName]
	if entry then
		return {
			code = codeOrName,
			name = entry.name,
			short = entry.short or entry.name,
			page = entry.page or entry.name,
		}
	end

	-- Linear scan for name match
	for code, info in pairs(data) do
		if info.name == codeOrName then
			return {
				code = code,
				name = info.name,
				short = info.short or info.name,
				page = info.page or info.name,
			}
		end
	end

	return nil
end

return p
