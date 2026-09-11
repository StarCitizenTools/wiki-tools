require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Consumable = require('Module:Entity/Facet/Consumable')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

-- matches

function suite:testMatchesWhenFoodPresent()
	self:assertTrue(Consumable.matches({ food = {} }))
end

function suite:testMatchesFalseWhenNoFood()
	self:assertFalse(Consumable.matches({}))
end

function suite:testMatchesNilSafe()
	self:assertFalse(Consumable.matches(nil))
end

-- getShortDescriptionPrefix

function suite:testPrefixSingleEffect()
	self:assertEquals('Stimulant', Consumable.getShortDescriptionPrefix(ctx({ food = { effects = { 'Stimulant' } } })))
end

function suite:testPrefixJoinsEffects()
	self:assertEquals(
		'Stimulant and Healing',
		Consumable.getShortDescriptionPrefix(ctx({ food = { effects = { 'Stimulant', 'Healing' } } }))
	)
end

function suite:testPrefixNilWhenNoEffects()
	self:assertEquals(nil, Consumable.getShortDescriptionPrefix(ctx({ food = {} })))
end

function suite:testPrefixNilWhenNoFood()
	self:assertEquals(nil, Consumable.getShortDescriptionPrefix(ctx({})))
end

-- getSections (empty-result branches; populated rendering is verified by QA)

function suite:testGetSectionsEmptyWhenNoFood()
	self:assertEquals(0, #Consumable.getSections(ctx({})))
end

function suite:testGetSectionsEmptyWhenFoodHasNoRows()
	self:assertEquals(0, #Consumable.getSections(ctx({ food = {} })))
end

-- getStructuredData

function suite:testStructuredDataReadsNdrHeiEffects()
	local sd = Consumable.getStructuredData(ctx({
		food = {
			nutritional_density_rating = '23',
			hydration_efficacy_index = '10',
			effects = { 'Hydrating', 'Energizing' },
		},
	}))
	self:assertEquals(23, sd.ndr)
	self:assertEquals(10, sd.hei)
	self:assertEquals('Hydrating', sd.effects[1])
	self:assertEquals('Energizing', sd.effects[2])
end

function suite:testStructuredDataCoercesNdrHeiToNumbers()
	-- NDR / HEI arrive as strings; stored as numbers so range / sort queries work.
	local sd = Consumable.getStructuredData(ctx({ food = { nutritional_density_rating = '80' } }))
	self:assertEquals(80, sd.ndr)
	self:assertEquals('number', type(sd.ndr))
end

function suite:testStructuredDataOmitsAbsentFields()
	local sd = Consumable.getStructuredData(ctx({ food = {} }))
	self:assertEquals(nil, sd.ndr)
	self:assertEquals(nil, sd.hei)
	self:assertEquals(nil, sd.effects)
end

function suite:testStructuredDataOmitsEmptyEffects()
	self:assertEquals(nil, Consumable.getStructuredData(ctx({ food = { effects = {} } })).effects)
end

function suite:testStructuredDataEmptyWhenNoFood()
	self:assertEquals(nil, next(Consumable.getStructuredData(ctx({}))))
end

return suite
