require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Rack = require('Module:Entity/Item/Rack')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- A missile rack: count/size live in the `missile_rack` block.
function suite:testMissileRackCapacity()
	local sections = Rack.getSections({
		type = 'MissileLauncher',
		missile_rack = { missile_count = 20, missile_size = 12 },
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('rack', sections[1].key)
	self:assertEquals('Missile rack', sections[1].label)
	self:assertEquals('20 × S12', findItem(sections[1].items, 'Capacity').content)
end

-- A bomb launcher: count is `max_bombs`, size is `max_size`, labelled differently.
function suite:testBombLauncherCapacity()
	local sections = Rack.getSections({ type = 'BombLauncher', max_bombs = 1, max_size = 3 }, {})
	self:assertEquals('Bomb launcher', sections[1].label)
	self:assertEquals('1 × S3', findItem(sections[1].items, 'Capacity').content)
end

-- Count without a size still shows the count alone.
function suite:testCountOnly()
	local sections = Rack.getSections({ type = 'MissileLauncher', missile_rack = { missile_count = 4 } }, {})
	self:assertEquals('4', findItem(sections[1].items, 'Capacity').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Rack.getSections({ type = 'MissileLauncher' }, {}))
end

function suite:testShortDescription()
	local desc = Rack.getShortDescription(
		{ size = 1, missile_rack = { missile_count = 1, missile_size = 1 } },
		{ manufacturer = 'Behring' },
		{ name = 'Missile rack' }
	)
	self:assertEquals('S1 missile rack by Behring', desc)
end

function suite:testStructuredData()
	local data = Rack.getStructuredData({
		type = 'MissileLauncher',
		missile_rack = { missile_count = 20, missile_size = 12 },
	})
	self:assertEquals(20, data.capacity_count)
	self:assertEquals(12, data.capacity_size)
end

function suite:testResolveSubtype()
	self:assertEquals(Rack, Item.resolveSubtype({ type = 'MissileLauncher' }))
	self:assertEquals(Rack, Item.resolveSubtype({ type = 'BombLauncher' }))
end

return suite
