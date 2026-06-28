require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Commodity = require('Module:Entity/Commodity')

local suite = ScribuntoUnit:new()

function suite:testGetSectionsFpsSuppressesLaserStats()
	-- FPS mining: signature nil, instability/resistance 0 → only Quality shows,
	-- and the group is still labelled "Mining".
	local raw = {
		is_mineable = true,
		kind = 'mineable',
		methods = { 'FPS' },
		signature = nil,
		instability = 0,
		resistance = 0,
		locations = { { quality_min = 201, quality_max = 1000 } },
	}
	local apiData = { key = 'Aphorite', _rawRecord = raw, _refinedRecord = { key = 'Aphorite' } }
	local sections = Commodity.getSections(apiData, {})
	local mining
	for _, s in ipairs(sections) do
		if s.key == 'mining' then
			mining = s
		end
	end
	self:assertEquals('Mining', mining.label)
	local function item(label)
		for _, i in ipairs(mining.items) do
			if i.label == label then
				return i.content
			end
		end
	end
	self:assertEquals(nil, item('Signature'))
	self:assertEquals(nil, item('Instability'))
	self:assertEquals(nil, item('Resistance'))
	self:assertEquals('201–1000', item('Quality'))
end

function suite:testGetSectionsHarvestableLabel()
	local raw = {
		is_mineable = true,
		kind = 'harvestable',
		methods = { 'Harvestable' },
		locations = { { quality_min = 1, quality_max = 100 } },
	}
	local apiData = { key = 'BluemoonFungus', _rawRecord = raw, _refinedRecord = { key = 'BluemoonFungus' } }
	local sections = Commodity.getSections(apiData, {})
	local mining
	for _, s in ipairs(sections) do
		if s.key == 'mining' then
			mining = s
		end
	end
	self:assertEquals('Harvesting', mining.label)
end

function suite:testGetSectionsHarvestableShowsSignatureNotEmpty()
	-- Harvestable with a signature but no quality / laser stats: the group must
	-- show Signature, not render label-only (regression: empty Harvesting group).
	local raw = {
		is_mineable = true,
		kind = 'harvestable',
		methods = {},
		signature = 1700,
		instability = nil,
		resistance = nil,
		locations = { { quality_min = nil, quality_max = nil } },
	}
	local apiData = { key = 'AmioshiPlague', _rawRecord = raw, _refinedRecord = { key = 'AmioshiPlague' } }
	local sections = Commodity.getSections(apiData, {})
	local mining
	for _, s in ipairs(sections) do
		if s.key == 'mining' then
			mining = s
		end
	end
	self:assertEquals('Harvesting', mining.label)
	self:assertEquals(1, #mining.items)
	self:assertEquals('Signature', mining.items[1].label)
	self:assertEquals('1,700', mining.items[1].content)
end

function suite:testGetSectionsNoStatsOmitsMiningGroup()
	-- Mineable but no signature, not laser, no quality → no mining group at all.
	local raw = { is_mineable = true, kind = 'mineable', methods = { 'FPS' }, locations = {} }
	local apiData = { key = 'X', _rawRecord = raw, _refinedRecord = { key = 'X' } }
	local sections = Commodity.getSections(apiData, {})
	for _, s in ipairs(sections) do
		self:assertEquals(true, s.key ~= 'mining')
	end
end

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
	-- include=items populates the items relation that enrich reads to attach
	-- food from the linked harvestable (edible-commodity facet).
	self:assertEquals('items', cfg.params.include)
end

function suite:testResolveGroupsDepthOne()
	local ti = Commodity.getTypeInfo({ commodity_groups = { 'Metal' } })
	self:assertEquals('Metal', ti.name)
	self:assertEquals('Metals', ti.category)
	self:assertEquals('Commodities', ti.categories[1])
end

function suite:testResolveGroupsDepthTwo()
	local ti = Commodity.getTypeInfo({ commodity_groups = { 'ProcessedGoods', 'Vice' } })
	self:assertEquals('Vice', ti.name)
	self:assertEquals('Processed goods', ti.category)
end

function suite:testGetTypeInfoPlaceholderParentReturnsNil()
	self:assertEquals(nil, Commodity.getTypeInfo({ commodity_groups = { 'HeatPlaceholder' } }))
end

function suite:testGetTypeInfoMissingGroupsReturnsNil()
	self:assertEquals(nil, Commodity.getTypeInfo({}))
	self:assertEquals(nil, Commodity.getTypeInfo({ commodity_groups = {} }))
end

function suite:testGetStructuredDataGroupAndType()
	local apiData = {
		commodity_groups = { 'ProcessedGoods', 'Vice' },
		tier = 'uncommon',
		kind = 'mineable',
		_rawRecord = { is_mineable = true, density_g_per_cc = 2.3 },
	}
	local sd = Commodity.getStructuredData(apiData, {})
	self:assertEquals('Processed goods', sd.commodity_group)
	self:assertEquals('Vice', sd.commodity_type)
	self:assertEquals(nil, sd.family)
	self:assertEquals('uncommon', sd.tier)
	self:assertEquals(true, sd.mineable)
	self:assertEquals(2.3, sd.density)
end

function suite:testGetStructuredDataNoGroupOmitsFields()
	local sd = Commodity.getStructuredData({ commodity_groups = { 'CleanAir' } }, {})
	self:assertEquals(nil, sd.commodity_group)
	self:assertEquals(nil, sd.commodity_type)
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
		commodity_groups = { 'Mineral' },
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
	self:assertEquals('Mineral', item(overview.items, 'Type'))
	self:assertEquals('Uncommon', item(overview.items, 'Rarity'))
	self:assertEquals('Ship mining', item(overview.items, 'Acquisition'))
	-- boolean rows render via Module:Boolean (icon markup); assert the canonical
	-- data-state marker, not the literal word.
	self:assertStringContains('data-state="yes"', item(overview.items, 'Refinable'), true)
	-- `systems` is deliberately not an infobox row (unscalable); it lives in
	-- structured data instead. Confirm no "Found in" row is emitted.
	self:assertEquals(nil, item(overview.items, 'Found in'))

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

function suite:testGetStructuredData()
	local apiData = {
		key = 'Aslarite',
		commodity_groups = { 'Mineral' },
		tier = 'uncommon',
		kind = 'mineable',
		_rawRecord = { is_mineable = true, density_g_per_cc = 2.3, signature = 4000, systems = { 'Pyro System' } },
	}
	local sd = Commodity.getStructuredData(apiData, {})
	self:assertEquals('Mineral', sd.commodity_group)
	self:assertEquals('Mineral', sd.commodity_type)
	self:assertEquals(nil, sd.family)
	self:assertEquals('uncommon', sd.tier)
	self:assertEquals(true, sd.mineable)
	self:assertEquals(2.3, sd.density)
end

function suite:testGetShortDescriptionFull()
	local apiData = { key = 'Aslarite', tier = 'uncommon', kind = 'mineable' }
	self:assertEquals('Uncommon mineable mineral', Commodity.getShortDescription(apiData, {}, { name = 'Mineral' }))
end

function suite:testGetShortDescriptionBare()
	self:assertEquals('Mineral', Commodity.getShortDescription({ key = 'Aslarite' }, {}, { name = 'Mineral' }))
end

function suite:testGetAcquisitionCommodityLinkOut()
	-- No refined prices → Trade is a link-out card keyed on slug; no locations → no mining card.
	local a = Commodity.getAcquisition(
		{ _rawRecord = { is_mineable = true, slug = 'gold' }, _refinedRecord = { slug = 'gold' } },
		{}
	)
	local byLabel = {}
	for _, r in ipairs(a.summary) do
		byLabel[r.label] = r.value
	end
	self:assertEquals(true, byLabel['Mine'])
	self:assertEquals('links', a.cards[#a.cards].type)
	self:assertTrue(a.cards[#a.cards].buttons[1].url:find('gold', 1, true) ~= nil)
end

function suite:testGetAcquisitionCommodityTradeTerminals()
	local a = Commodity.getAcquisition({
		_rawRecord = { is_mineable = false },
		_refinedRecord = { uex_prices = { purchase = { { price_buy = 5, price_sell = 7 } } } },
	}, {})
	self:assertEquals('terminals', a.cards[#a.cards].type)
	self:assertEquals('Trade terminals', a.cards[#a.cards].caption)
end

return suite
