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

function suite:testAllFacetsConform()
	for i, facet in ipairs(Registry.facets) do
		local ok, errors = Contract.validate(facet, Contract.FACET)
		self:assertTrue(ok, 'facet #' .. i .. ' failed: ' .. table.concat(errors, '; '))
	end
end

return suite
