require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Data = require('Module:Entity/Data')
local helpers = Data._internal

local suite = ScribuntoUnit:new()

-- detectFacets (facet registry detection)

function suite:testDetectFacetsConsumable()
	local facets = helpers.detectFacets({ food = {} })
	self:assertEquals(1, #facets)
	self:assertTrue(facets[1].matches({ food = {} }))
end

function suite:testDetectFacetsNoneWhenNoFood()
	self:assertEquals(0, #helpers.detectFacets({}))
end

function suite:testDetectFacetsNilSafe()
	self:assertEquals(0, #helpers.detectFacets(nil))
end

-- resolveLeaf (leaf-module resolution from the matched kind)

function suite:testResolveLeafUsesSubtype()
	local subtype = { name = 'subtype' }
	local kind = {
		resolveSubtype = function()
			return subtype
		end,
	}
	local leaf, err = helpers.resolveLeaf(kind, {}, true)
	self:assertEquals(subtype, leaf)
	self:assertEquals(false, err)
end

function suite:testResolveLeafFallsToKindWhenSubtypeNil()
	local kind = {
		resolveSubtype = function()
			return nil
		end,
	}
	local leaf, err = helpers.resolveLeaf(kind, {}, true)
	self:assertEquals(kind, leaf)
	self:assertEquals(false, err)
end

function suite:testResolveLeafKindWithoutSubtype()
	local kind = {}
	local leaf, err = helpers.resolveLeaf(kind, {}, true)
	self:assertEquals(kind, leaf)
	self:assertEquals(false, err)
end

function suite:testResolveLeafNoMatchWithUuidIsError()
	local leaf, err = helpers.resolveLeaf(nil, {}, true)
	self:assertEquals(require('Module:Entity/Item'), leaf)
	self:assertEquals(true, err)
end

function suite:testResolveLeafNoMatchNoUuidNoError()
	local leaf, err = helpers.resolveLeaf(nil, {}, false)
	self:assertEquals(require('Module:Entity/Item'), leaf)
	self:assertEquals(false, err)
end

return suite
