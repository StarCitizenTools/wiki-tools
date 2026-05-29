require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Commodity = require('Module:Entity/Commodity')

local suite = ScribuntoUnit:new()

function suite:testMatchesNilReturnsFalse()
	self:assertEquals(false, Commodity.matches(nil))
end

function suite:testMatchesEmptyTableReturnsFalse()
	self:assertEquals(false, Commodity.matches({}))
end

function suite:testMatchesBoxSizesPresentReturnsTrue()
	self:assertEquals(true, Commodity.matches({ box_sizes_scu = { 1, 2, 4 } }))
end

function suite:testGetApiConfigsEndpoint()
	local cfg = Commodity.getApiConfigs()[1]
	self:assertEquals('commodities/%s', cfg.endpoint)
	self:assertEquals('data', cfg.responseDataPath)
end

function suite:testResolveRolesSelfIsRaw()
	local self_ = { name = 'Aslarite (Raw)', is_mineable = true, refined_version = { uuid = 'ref-1' } }
	local counterpart = { name = 'Aslarite' }
	local raw, refined = Commodity._internal.resolveRoles(self_, counterpart)
	self:assertEquals('Aslarite (Raw)', raw.name)
	self:assertEquals('Aslarite', refined.name)
end

function suite:testResolveRolesSelfIsRefined()
	local self_ = { name = 'Aslarite', raw_versions = { { uuid = 'raw-1' } } }
	local counterpart = { name = 'Aslarite (Raw)' }
	local raw, refined = Commodity._internal.resolveRoles(self_, counterpart)
	self:assertEquals('Aslarite (Raw)', raw.name)
	self:assertEquals('Aslarite', refined.name)
end

function suite:testResolveRolesRefinedOnlyNoCounterpart()
	local self_ = { name = 'GoldOnly', raw_versions = {} }
	local raw, refined = Commodity._internal.resolveRoles(self_, nil)
	self:assertEquals(nil, raw)
	self:assertEquals('GoldOnly', refined.name)
end

function suite:testGetTypeInfoMineral()
	local ti = Commodity.getTypeInfo({ key = 'Aslarite' })
	self:assertEquals('Mineral', ti.name)
	self:assertEquals('Minerals', ti.category)
end

function suite:testGetTypeInfoRawMaps()
	self:assertEquals('Mineral', Commodity.getTypeInfo({ key = 'Raw_Aslarite' }).name)
end

function suite:testGetTypeInfoUnknownReturnsNil()
	self:assertEquals(nil, Commodity.getTypeInfo({ key = 'UnknownJunk' }))
end

return suite
