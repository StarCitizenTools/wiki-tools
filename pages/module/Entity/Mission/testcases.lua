require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Mission = require('Module:Entity/Mission')

local suite = ScribuntoUnit:new()

local function ctx(apiData, args)
	return { apiData = apiData or {}, args = args or {} }
end

--- Find an infobox item by label across every section a hook returned.
local function itemByLabel(sections, label)
	for _, section in ipairs(sections) do
		for _, item in ipairs(section.items or {}) do
			if item.label == label then
				return item
			end
		end
	end
	return nil
end

local function sectionByKey(sections, key)
	for _, section in ipairs(sections) do
		if section.key == key then
			return section
		end
	end
	return nil
end

function suite:testMatchesRequiresAMissionType()
	self:assertTrue(Mission.matches({ mission_type = 'Mercenary' }))
	self:assertFalse(Mission.matches({ name = 'Gladius' }))
	self:assertFalse(Mission.matches(nil))
end

function suite:testGetApiConfigsExposesTheMissionEndpointFirst()
	local configs = Mission.getApiConfigs()
	self:assertEquals('missions/%s', configs[1].endpoint)
	self:assertEquals('data', configs[1].responseDataPath)
end

function suite:testTypeInfoPassesAnUnmappedTypeThrough()
	-- The API carries 30-odd mission_type values and gains more each patch, so a
	-- type with no explicit mapping must still resolve rather than return nil.
	local typeInfo = Mission.getTypeInfo(ctx({ mission_type = 'Refueling' }))
	self:assertEquals('Refueling', typeInfo.name)
	self:assertEquals('Refueling contracts', typeInfo.category)
	self:assertDeepEquals({ 'Contracts' }, typeInfo.categories)
end

function suite:testTypeInfoCategoryMatchesTheExistingCategoryNames()
	-- 'Bounty Hunter' must route to Category:Bounty hunter contracts, the name the
	-- retired {{Contract}} template generated through {{Fixcaps}}.
	local typeInfo = Mission.getTypeInfo(ctx({ mission_type = 'Bounty Hunter' }))
	self:assertEquals('Bounty Hunter', typeInfo.name)
	self:assertEquals('Bounty hunter contracts', typeInfo.category)
end

function suite:testTypeInfoFoldsBothWikeloBucketsIntoCollection()
	self:assertEquals('Collection', Mission.getTypeInfo(ctx({ mission_type = 'Wikelo - Other Items' })).name)
	self:assertEquals('Collection', Mission.getTypeInfo(ctx({ mission_type = 'Wikelo - Vehicles' })).name)
	self:assertEquals('Collection contracts', Mission.getTypeInfo(ctx({ mission_type = 'Wikelo - Vehicles' })).category)
end

function suite:testTypeInfoRemapsTheMisTaggedLocalRecord()
	self:assertEquals('Maintenance', Mission.getTypeInfo(ctx({ mission_type = 'local' })).name)
end

function suite:testTypeInfoIsNilWithoutAMissionType()
	self:assertEquals(nil, Mission.getTypeInfo(ctx({})))
	self:assertEquals(nil, Mission.getTypeInfo(ctx({ mission_type = '' })))
end

function suite:testSectionsRenderAnUnmappedType()
	-- Regression: an unmapped mission_type used to return nil typeInfo and then
	-- error on typeInfo.name, taking the whole infobox down.
	local sections = Mission.getSections(ctx({ mission_type = 'Hauling', mission_giver = 'Covalex' }))
	self:assertEquals('Hauling', itemByLabel(sections, 'Type').content)
end

function suite:testSectionsSurviveAMissingType()
	local sections = Mission.getSections(ctx({ mission_giver = 'Covalex' }))
	self:assertEquals(nil, itemByLabel(sections, 'Type').content)
end

function suite:testSectionsLabelTheScripTheContractActuallyAwards()
	-- Regression: the payout row read a field the reward loop never wrote, so a
	-- Council Scrip payout was labelled MG Scrip.
	local sections = Mission.getSections(ctx({
		mission_type = 'Mercenary',
		reward_items = { { name = 'Council Scrip', amount = 250 } },
	}))
	local payout = sectionByKey(sections, 'payout')
	self:assertEquals('Council Scrip', payout.items[2].label)
	self:assertEquals('250', payout.items[2].content)
end

function suite:testSectionsKeepMgScripAsTheDefaultLabel()
	local sections = Mission.getSections(ctx({
		mission_type = 'Wikelo - Other Items',
		reward_items = { { name = 'MG Scrip', amount = 30 } },
	}))
	self:assertEquals('MG Scrip', sectionByKey(sections, 'payout').items[2].label)
end

function suite:testSectionsSumRepeatedScripRewards()
	local sections = Mission.getSections(ctx({
		mission_type = 'Mercenary',
		reward_items = { { name = 'MG Scrip', amount = 10 }, { name = 'MG Scrip', amount = 15 } },
	}))
	self:assertEquals('25', sectionByKey(sections, 'payout').items[2].content)
end

function suite:testSectionsMarkANotForReleaseContractUnavailable()
	local sections = Mission.getSections(ctx({ mission_type = 'Mercenary', not_for_release = true }))
	self:assertEquals('Unavailable', itemByLabel(sections, 'Availability').content)
end

function suite:testSectionsLetTheEditorOverrideAvailability()
	local sections = Mission.getSections(ctx({ mission_type = 'Mercenary', not_for_release = true }, {
		available = 'yes',
	}))
	self:assertEquals('Available', itemByLabel(sections, 'Availability').content)
end

function suite:testSectionsRouteWikeloToItsEmporium()
	local sections = Mission.getSections(ctx({ mission_type = 'Wikelo - Vehicles', mission_giver = 'Wikelo' }))
	self:assertEquals('[[Wikelo Emporium]]', itemByLabel(sections, 'Contract Pickup').content)
end

function suite:testSectionsDefaultPickupToTheContractManager()
	local sections = Mission.getSections(ctx({ mission_type = 'Mercenary', mission_giver = 'Foxwell Enforcement' }))
	self:assertEquals('[[Contract Manager]]', itemByLabel(sections, 'Contract Pickup').content)
end

function suite:testSectionsMarkAnIllegalContractUnverified()
	local sections = Mission.getSections(ctx({ mission_type = 'Mercenary', illegal = true }))
	self:assertEquals('Unverified', itemByLabel(sections, 'Category').content)
end

function suite:testStructuredDataCarriesTheResolvedType()
	local stored = Mission.getStructuredData(ctx({ mission_type = 'Wikelo - Other Items', illegal = false }))
	self:assertEquals('Collection', stored.type)
	self:assertEquals('verified', stored.legality)
end

function suite:testStructuredDataSurvivesAMissingType()
	local stored = Mission.getStructuredData(ctx({ illegal = true }))
	self:assertEquals(nil, stored.type)
	self:assertEquals('unverified', stored.legality)
end

function suite:testStructuredDataDefaultsStandingsToNone()
	local stored = Mission.getStructuredData(ctx({ mission_type = 'Mercenary' }))
	self:assertEquals('None', stored.reputation_min)
	self:assertEquals('None', stored.reputation_max)
end

function suite:testShortDescriptionCombinesFactionAndType()
	local typeInfo = { name = 'Mercenary' }
	self:assertEquals(
		'Headhunters mercenary contract',
		Mission.getShortDescription({
			apiData = { faction = { name = 'Headhunters' } },
			args = {},
			typeInfo = typeInfo,
		})
	)
end

function suite:testShortDescriptionFallsBackToTheMissionGiver()
	self:assertEquals(
		'Wikelo collection contract',
		Mission.getShortDescription({
			apiData = { mission_giver = 'Wikelo' },
			args = {},
			typeInfo = { name = 'Collection' },
		})
	)
end

function suite:testShortDescriptionDropsTheFactionWhenTheRecordHasNone()
	-- Regression: ~100 records in the 4.10 corpus carry neither faction.name nor
	-- mission_giver, and indexing the nil faction took the page down.
	self:assertEquals(
		'Mercenary contract',
		Mission.getShortDescription({ apiData = {}, args = {}, typeInfo = { name = 'Mercenary' } })
	)
end

function suite:testShortDescriptionIsNilWithoutAType()
	self:assertEquals(
		nil,
		Mission.getShortDescription({ apiData = { mission_giver = 'Wikelo' }, args = {}, typeInfo = nil })
	)
end

return suite
