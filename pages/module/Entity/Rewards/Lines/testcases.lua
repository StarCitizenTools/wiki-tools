require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Lines = require('Module:Entity/Rewards/Lines')

local suite = ScribuntoUnit:new()

function suite:testItemLine()
	self:assertEquals('2x [[Medpen]]', Lines.itemLine({ amount = 2, name = 'Medpen' }))
end

function suite:testBlueprintLine()
	self:assertEquals('[[P4-AR]] blueprint', Lines.blueprintLine({ name = 'P4-AR' }))
end

function suite:testRewardLinesItemsThenBlueprints()
	local rewardGroups = { { items = { { amount = 2, name = 'Medpen' } } } }
	local blueprintGroups = { { drop_chance_percent = 50, items = { { name = 'P4-AR' } } } }
	self:assertDeepEquals({ '2x [[Medpen]]', '[[P4-AR]] blueprint' }, Lines.rewardLines(rewardGroups, blueprintGroups))
end

function suite:testRewardLinesMultipleGroupsAndItems()
	local rewardGroups = {
		{ items = { { amount = 1, name = 'Medpen' }, { amount = 3, name = 'Ration Kit' } } },
		{ items = { { amount = 1, name = 'Datapad' } } },
	}
	self:assertDeepEquals(
		{ '1x [[Medpen]]', '3x [[Ration Kit]]', '1x [[Datapad]]' },
		Lines.rewardLines(rewardGroups, nil)
	)
end

function suite:testRewardLinesNilGroupsAreEmpty()
	self:assertDeepEquals({}, Lines.rewardLines(nil, nil))
end

function suite:testRewardLinesBlueprintsOnly()
	local blueprintGroups = { { drop_chance_percent = 100, items = { { name = 'P4-AR' } } } }
	self:assertDeepEquals({ '[[P4-AR]] blueprint' }, Lines.rewardLines(nil, blueprintGroups))
end

return suite
