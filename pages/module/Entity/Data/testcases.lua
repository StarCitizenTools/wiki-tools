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

-- isGenuineRecord (genuine in-game record predicate)

function suite:testGenuineRecordTrueWithUuid()
	self:assertEquals(true, helpers.isGenuineRecord({ uuid = 'abc' }))
end

function suite:testGenuineRecordFalseWithoutUuid()
	self:assertEquals(false, helpers.isGenuineRecord({ is_vehicle = true }))
end

function suite:testGenuineRecordFalseEmpty()
	self:assertEquals(false, helpers.isGenuineRecord({}))
end

function suite:testGenuineRecordFalseEmptyUuid()
	self:assertEquals(false, helpers.isGenuineRecord({ uuid = '' }))
end

-- resolveEditorialKind (args.kind -> opted-in registered kind)

function suite:testEditorialKindResolvesVehicle()
	local kind = helpers.resolveEditorialKind({ kind = 'Vehicle' })
	self:assertEquals('Vehicle', kind and kind.name)
end

function suite:testEditorialKindCaseInsensitive()
	local kind = helpers.resolveEditorialKind({ kind = 'vehicle' })
	self:assertEquals('Vehicle', kind and kind.name)
end

function suite:testEditorialKindNilWhenAbsent()
	self:assertEquals(nil, helpers.resolveEditorialKind({}))
end

function suite:testEditorialKindNilWhenNotOptedIn()
	-- Commodity is registered but does NOT opt into editorial mode.
	self:assertEquals(nil, helpers.resolveEditorialKind({ kind = 'Commodity' }))
end

function suite:testEditorialKindNilWhenUnknown()
	self:assertEquals(nil, helpers.resolveEditorialKind({ kind = 'Nonsense' }))
end

-- resolveLeaf threads args into resolveSubtype

function suite:testResolveLeafThreadsArgsToSubtype()
	local seen
	local subtype = { name = 'sub' }
	local kind = {
		resolveSubtype = function(_, a)
			seen = a
			return subtype
		end,
	}
	local leaf = helpers.resolveLeaf(kind, {}, false, { family = 'ship' })
	self:assertEquals(subtype, leaf)
	self:assertEquals('ship', seen and seen.family)
end

return suite
