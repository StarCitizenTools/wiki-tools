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

return suite
