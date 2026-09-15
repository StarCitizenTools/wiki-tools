require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Lines = require('Module:Entity/Combat/Lines')

local suite = ScribuntoUnit:new()

function suite:testCountRangeFixed()
	self:assertEquals('5', Lines.countRange(5, 5))
end

function suite:testCountRangeSpread()
	self:assertEquals('5 - 10', Lines.countRange(5, 10))
end

function suite:testCountRangeMinOnly()
	self:assertEquals('7', Lines.countRange(7, nil))
end

function suite:testCountRangeMaxOnly()
	self:assertEquals('3', Lines.countRange(nil, 3))
end

function suite:testCountRangeNeitherBound()
	self:assertEquals(nil, Lines.countRange(nil, nil))
end

function suite:testCountRangeIgnoresAMaxBelowTheMin()
	self:assertEquals('5', Lines.countRange(5, 0))
end

function suite:testGroupLabelIsVerbatim()
	self:assertEquals('Juggernaut x 1 - Target', Lines.groupLabel({ group_name = 'Juggernaut x 1 - Target' }))
end

function suite:testGroupLabelFallsBackWhenUnnamed()
	self:assertEquals('Unnamed group', Lines.groupLabel({}))
	self:assertEquals('Unnamed group', Lines.groupLabel({ group_name = '' }))
end

function suite:testSpawnKind()
	self:assertEquals('Ship', Lines.spawnKind({ spawn_kind = 'Ship' }))
	self:assertEquals('Npc', Lines.spawnKind({ spawn_kind = 'Npc' }))
	self:assertEquals(nil, Lines.spawnKind({}))
end

--- Stands in for the Bucket lookup, which is keyed lowercase.
local function resolver(className)
	return ({ aegs_hammerhead = 'Hammerhead', aegs_gladius = 'Gladius', orig_85x = '85X' })[className]
end

function suite:testShipLabelsLinkAResolvedClassName()
	local spawn = { ships = { { class_name = 'AEGS_Gladius', name = 'Aegis Gladius' } } }
	self:assertDeepEquals({ '[[Gladius]]' }, Lines.shipLabels(spawn, resolver))
end

function suite:testShipLabelsFallBackToPlainTextWhenUnresolved()
	-- No Bucket row means no page to link, so the display name renders as text
	-- rather than as a guessed (and red) link.
	local spawn = { ships = { { class_name = 'ANVL_Valkyrie', name = 'Anvil Valkyrie' } } }
	self:assertDeepEquals({ 'Anvil Valkyrie' }, Lines.shipLabels(spawn, resolver))
end

function suite:testShipLabelsGroupByDisplayNameBeforeResolving()
	-- Regression: the _GS variant has no page of its own, so resolving before
	-- grouping emitted '[[Hammerhead]]' AND 'Aegis Hammerhead' for one ship.
	local spawn = {
		ships = {
			{ class_name = 'AEGS_Hammerhead_GS', name = 'Aegis Hammerhead' },
			{ class_name = 'AEGS_Hammerhead', name = 'Aegis Hammerhead' },
		},
	}
	self:assertDeepEquals({ '[[Hammerhead]]' }, Lines.shipLabels(spawn, resolver))
end

function suite:testShipLabelsMatchRegardlessOfClassNameCase()
	-- The two sources disagree on case for the same identifier: combat gives
	-- ORIG_85x where the page stores ORIG_85X, which cost a link each.
	local spawn = { ships = { { class_name = 'ORIG_85x', name = 'Origin 85X Limited' } } }
	self:assertDeepEquals({ '[[85X]]' }, Lines.shipLabels(spawn, resolver))
end

function suite:testShipLabelsSortAlphabetically()
	-- The API orders the pool by manufacturer, which no longer shows once the
	-- linked entries display their model-only page titles.
	local spawn = {
		ships = {
			{ class_name = 'AEGS_Hammerhead', name = 'Aegis Hammerhead' },
			{ class_name = 'ANVL_Valkyrie', name = 'Anvil Valkyrie' },
			{ class_name = 'AEGS_Gladius', name = 'Aegis Gladius' },
		},
	}
	-- Ordered by the VISIBLE text, so an unresolved entry interleaves with the
	-- links instead of being filed after them: Anvil Valkyrie, Gladius, Hammerhead.
	self:assertDeepEquals({ 'Anvil Valkyrie', '[[Gladius]]', '[[Hammerhead]]' }, Lines.shipLabels(spawn, resolver))
end

function suite:testShipLabelsTolerateAMissingResolver()
	-- An empty Bucket (nothing reparsed yet) degrades every entry to plain text.
	local spawn = { ships = { { class_name = 'AEGS_Gladius', name = 'Aegis Gladius' } } }
	self:assertDeepEquals({ 'Aegis Gladius' }, Lines.shipLabels(spawn, nil))
end

function suite:testShipLabelsTolerateAShipWithNoClassName()
	local spawn = { ships = { { name = 'Wreckage' } } }
	self:assertDeepEquals({ 'Wreckage' }, Lines.shipLabels(spawn, resolver))
end

function suite:testShipLabelsEmptyForAnNpcGroup()
	self:assertDeepEquals({}, Lines.shipLabels({ ships = {} }, resolver))
	self:assertDeepEquals({}, Lines.shipLabels({}, resolver))
end

function suite:testSpawnRowsOrderEnemiesFirst()
	local combat = {
		aggregated_spawns = {
			{ role = 'other', group_name = 'FriendlyProbe', spawn_kind = 'Ship' },
			{ role = 'defend_target', group_name = 'ShipToDefend', spawn_kind = 'Ship' },
			{ role = 'enemy', group_name = 'Targets', spawn_kind = 'Ship', concurrent_min = 4, concurrent_max = 6 },
			{ role = 'escort_target', group_name = 'Convoy', spawn_kind = 'Ship' },
		},
	}
	local rows = Lines.spawnRows(combat)
	self:assertEquals(4, #rows)
	self:assertEquals('Targets', rows[1].label)
	self:assertEquals('Hostile', rows[1].roleLabel)
	self:assertEquals('4 - 6', rows[1].count)
	self:assertEquals('Convoy', rows[2].label)
	self:assertEquals('ShipToDefend', rows[3].label)
	self:assertEquals('FriendlyProbe', rows[4].label)
end

function suite:testSpawnRowsTreatAMissingRoleAsOther()
	local rows = Lines.spawnRows({ aggregated_spawns = { { group_name = 'Soldier x 2', spawn_kind = 'Npc' } } })
	self:assertEquals(1, #rows)
	self:assertEquals('other', rows[1].role)
	self:assertEquals('Other', rows[1].roleLabel)
	-- Npc groups carry no concurrent bounds anywhere in the corpus.
	self:assertEquals(nil, rows[1].count)
end

function suite:testSpawnRowsKeepAnUnknownRoleUnderItsRawName()
	local rows = Lines.spawnRows({
		aggregated_spawns = {
			{ role = 'salvage_target', group_name = 'Wreck', spawn_kind = 'Ship' },
			{ role = 'enemy', group_name = 'Targets', spawn_kind = 'Ship' },
		},
	})
	self:assertEquals('Targets', rows[1].label)
	self:assertEquals('Wreck', rows[2].label)
	self:assertEquals('salvage_target', rows[2].roleLabel)
end

function suite:testSpawnRowsNilCombatIsEmpty()
	self:assertDeepEquals({}, Lines.spawnRows(nil))
	self:assertDeepEquals({}, Lines.spawnRows({}))
end

function suite:testTotalEnemies()
	self:assertEquals('5 - 10', Lines.totalEnemies({ summary = { total = { min = 5, max = 10 } } }))
	self:assertEquals('7', Lines.totalEnemies({ summary = { total = { min = 7, max = 7 } } }))
	self:assertEquals(nil, Lines.totalEnemies({ summary = {} }))
	self:assertEquals(nil, Lines.totalEnemies(nil))
end

function suite:testHasData()
	self:assertTrue(Lines.hasData({ summary = { total = { min = 3, max = 3 } } }))
	self:assertTrue(Lines.hasData({ aggregated_spawns = { { group_name = 'Targets' } } }))
	self:assertFalse(Lines.hasData({ summary = {}, aggregated_spawns = {} }))
	self:assertFalse(Lines.hasData(nil))
end

return suite
