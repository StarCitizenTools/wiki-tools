require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Scraper = require('Module:Entity/Item/Scraper')
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

-- The Abrade Scraper Module: speed ×0.15, radius ×3.5, 90% extraction.
local function abradeData()
	return {
		size = 1,
		salvage_modifier = {
			salvage_speed_multiplier = 0.15,
			radius_multiplier = 3.5,
			extraction_efficiency = 0.9,
		},
	}
end

function suite:testRows()
	local sections = Scraper.getSections(abradeData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('salvage_modifier', sections[1].key)
	self:assertEquals('Salvage', sections[1].label)
	-- Both multipliers are higher-better: ×0.15 speed (slower) is a red nerf, ×3.5
	-- radius (wider) a green buff.
	local speed = findItem(sections[1].items, 'Salvage speed').content
	self:assertStringContains('×0.15', speed, true)
	self:assertStringContains('color-destructive', speed, true)
	local radius = findItem(sections[1].items, 'Radius').content
	self:assertStringContains('×3.5', radius, true)
	self:assertStringContains('color-success', radius, true)
	self:assertEquals('90%', findItem(sections[1].items, 'Extraction efficiency').content)
end

-- The ReadyGrip: a neutral tractor-flavoured SalvageModifier (all multipliers 1).
function suite:testNeutralModifier()
	local sections = Scraper.getSections({
		size = 1,
		salvage_modifier = {
			salvage_speed_multiplier = 1,
			radius_multiplier = 1,
			extraction_efficiency = 1,
		},
	}, {})
	self:assertEquals('×1', findItem(sections[1].items, 'Salvage speed').content)
	self:assertEquals('100%', findItem(sections[1].items, 'Extraction efficiency').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Scraper.getSections({}, {}))
end

function suite:testShortDescription()
	local desc = Scraper.getShortDescription(
		abradeData(),
		{ manufacturer = 'Greycat Industrial' },
		{ name = 'Scraper module' }
	)
	self:assertEquals('S1 scraper module by Greycat', desc)
end

function suite:testStructuredData()
	local data = Scraper.getStructuredData(abradeData())
	self:assertEquals(0.15, data.salvage_speed_multiplier)
	self:assertEquals(3.5, data.radius_multiplier)
	self:assertEquals(90, data.extraction_efficiency)
end

function suite:testResolveSubtype()
	self:assertEquals(Scraper, Item.resolveSubtype({ type = 'SalvageModifier' }))
end

return suite
