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

function suite:testGetSectionsOverviewAndMining()
	local raw = {
		is_mineable = true,
		signature = 4000,
		instability = 700,
		resistance = 0.5,
		methods = { 'Ship' },
		systems = { 'Pyro System', 'Stanton System' },
		locations = { { quality_min = 245, quality_max = 1000 }, { quality_min = 300, quality_max = 980 } },
	}
	local apiData = {
		key = 'Aslarite',
		kind = 'mineable',
		tier = 'uncommon',
		raw_versions = { { uuid = 'x' } },
		_rawRecord = raw,
	}
	apiData._refinedRecord = apiData
	local sections = Commodity.getSections(apiData, {})

	local function group(key)
		for _, s in ipairs(sections) do
			if s.key == key then
				return s
			end
		end
	end
	local function item(items, label)
		for _, i in ipairs(items or {}) do
			if i.label == label then
				return i.content
			end
		end
	end

	local overview = group('overview')
	self:assertEquals('Mineral', item(overview.items, 'Family'))
	self:assertEquals('Uncommon', item(overview.items, 'Rarity'))
	self:assertEquals('Ship mining', item(overview.items, 'Acquisition'))
	self:assertEquals('Yes', item(overview.items, 'Refinable'))
	self:assertEquals('Pyro System, Stanton System', item(overview.items, 'Found in'))

	local mining = group('mining')
	self:assertEquals('4,000', item(mining.items, 'Signature'))
	self:assertEquals('245–1000', item(mining.items, 'Quality'))
end

function suite:testGetSectionsNonMineableHasNoMiningGroup()
	local apiData = { key = 'Aslarite', _refinedRecord = { key = 'Aslarite' }, _rawRecord = nil }
	local sections = Commodity.getSections(apiData, {})
	for _, s in ipairs(sections) do
		self:assertEquals(true, s.key ~= 'mining')
	end
end

return suite
