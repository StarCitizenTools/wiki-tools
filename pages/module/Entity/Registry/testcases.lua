require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Registry = require('Module:Entity/Registry')
local Contract = require('Module:Entity/Contract')

local suite = ScribuntoUnit:new()

function suite:testRegistryNonEmpty()
	self:assertTrue(#Registry.kinds > 0)
	self:assertTrue(#Registry.facets > 0)
end

function suite:testAllKindsConform()
	for i, kind in ipairs(Registry.kinds) do
		local ok, errors = Contract.validate(kind, Contract.KIND)
		self:assertTrue(ok, 'kind #' .. i .. ' failed: ' .. table.concat(errors, '; '))
	end
end

-- Every kind must declare a non-empty, unique string `name` — the canonical kind
-- name exposed as Data.get().result.kind for sibling renderers to branch on.
-- Authoritative `name` check (non-empty + uniqueness, which KIND_FIELDS cannot
-- express); keep it distinct from testAllKindsConformFields below.
function suite:testAllKindsDeclareName()
	local seen = {}
	for i, kind in ipairs(Registry.kinds) do
		self:assertEquals('string', type(kind.name), 'kind #' .. i .. ' has no string name')
		self:assertTrue(#kind.name > 0, 'kind #' .. i .. ' has an empty name')
		self:assertEquals(nil, seen[kind.name], 'duplicate kind name: ' .. tostring(kind.name))
		seen[kind.name] = true
	end
end

function suite:testAllFacetsConform()
	for i, facet in ipairs(Registry.facets) do
		local ok, errors = Contract.validate(facet, Contract.FACET)
		self:assertTrue(ok, 'facet #' .. i .. ' failed: ' .. table.concat(errors, '; '))
	end
end

-- Generic typed-field gate: every kind's non-function fields (name, editorialMode)
-- conform to KIND_FIELDS. Complements testAllKindsDeclareName (which additionally
-- guarantees name is non-empty + unique) — do not dedupe the two.
function suite:testAllKindsConformFields()
	for i, kind in ipairs(Registry.kinds) do
		local ok, errors = Contract.validateFields(kind, Contract.KIND_FIELDS)
		self:assertTrue(ok, 'kind #' .. i .. ' field check failed: ' .. table.concat(errors, '; '))
	end
end

return suite
