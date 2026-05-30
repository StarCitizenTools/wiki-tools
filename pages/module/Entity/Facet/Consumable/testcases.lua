require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Consumable = require('Module:Entity/Facet/Consumable')

local suite = ScribuntoUnit:new()

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
	self:assertEquals('Stimulant', Consumable.getShortDescriptionPrefix({ food = { effects = { 'Stimulant' } } }))
end

function suite:testPrefixJoinsEffects()
	self:assertEquals(
		'Stimulant and Healing',
		Consumable.getShortDescriptionPrefix({ food = { effects = { 'Stimulant', 'Healing' } } })
	)
end

function suite:testPrefixNilWhenNoEffects()
	self:assertEquals(nil, Consumable.getShortDescriptionPrefix({ food = {} }))
end

function suite:testPrefixNilWhenNoFood()
	self:assertEquals(nil, Consumable.getShortDescriptionPrefix({}))
end

-- getSections (empty-result branches; populated rendering is verified by QA)

function suite:testGetSectionsEmptyWhenNoFood()
	self:assertEquals(0, #Consumable.getSections({}))
end

function suite:testGetSectionsEmptyWhenFoodHasNoRows()
	self:assertEquals(0, #Consumable.getSections({ food = {} }))
end

return suite
