require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Beam = require('Module:Entity/Item/Beam')
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

-- The Durus tractor beam: heavy-lift mode is `cargo_mode_override`.
local function tractorData()
	return {
		type = 'TractorBeam',
		size = 1,
		tractor_beam = {
			force = { min = 1500, max = 500000 },
			range = { max = 75, max_angle = 60 },
			tether = { tether_break_time = 1.5 },
			cargo_mode_override = { max_force = 9500000, max_distance = 225 },
		},
	}
end

function suite:testTractorRows()
	local sections = Beam.getSections(tractorData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('tractor_beam', sections[1].key)
	self:assertEquals('Tractor beam', sections[1].label)
	self:assertEquals('500,000', findItem(sections[1].items, 'Force').content)
	self:assertEquals('9,500,000', findItem(sections[1].items, 'Cargo force').content)
	self:assertEquals('75 m', findItem(sections[1].items, 'Range').content)
	self:assertEquals('60°', findItem(sections[1].items, 'Max angle').content)
	self:assertEquals('1.5 s', findItem(sections[1].items, 'Tether break time').content)
end

-- A towing beam: heavy-lift mode is the `towing` object, labelled Tow force.
function suite:testTowingRows()
	local sections = Beam.getSections({
		type = 'TowingBeam',
		size = 3,
		tractor_beam = {
			force = { max = 5000000000 },
			range = { max = 300, max_angle = 90 },
			tether = { tether_break_time = 3 },
			towing = { force = 120000000 },
			cargo_mode_override = { max_force = 9500001 },
		},
	}, {})
	self:assertEquals('Towing beam', sections[1].label)
	-- Tow force wins over cargo_mode_override for a towing beam.
	self:assertEquals('120,000,000', findItem(sections[1].items, 'Tow force').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Cargo force'))
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Beam.getSections({ type = 'TractorBeam' }, {}))
end

function suite:testShortDescription()
	local desc = Beam.getShortDescription(
		tractorData(),
		{ manufacturer = 'Greycat Industrial' },
		{ name = 'Tractor beam' }
	)
	self:assertEquals('S1 tractor beam by Greycat Industrial', desc)
end

function suite:testStructuredData()
	local data = Beam.getStructuredData(tractorData())
	self:assertEquals(500000, data.beam_force)
	self:assertEquals(9500000, data.beam_mode_force)
	self:assertEquals(75, data.beam_range)
	self:assertEquals(60, data.beam_max_angle)
	self:assertEquals(1.5, data.beam_tether_break)
end

function suite:testResolveSubtype()
	self:assertEquals(Beam, Item.resolveSubtype({ type = 'TractorBeam' }))
	self:assertEquals(Beam, Item.resolveSubtype({ type = 'TowingBeam' }))
end

return suite
