require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local presets = require('Module:Dimensions/presets')

local suite = ScribuntoUnit:new()

-- reference shapes

function suite:testHumanShape()
	self:assertEquals(1.8, presets.human.height)
	self:assertEquals('Human · 1.8 m', presets.human.label)
end

function suite:testHumanHasNoColour()
	-- Human uses the stylesheet default colour (no inline override).
	self:assertEquals(nil, presets.human.color)
end

function suite:testBananaShape()
	self:assertEquals(0.2, presets.banana.height)
	self:assertEquals('Banana · 0.2 m', presets.banana.label)
end

function suite:testBananaHasColour()
	self:assertEquals('#d9b73e', presets.banana.color)
	self:assertEquals('#ecd06c', presets.banana.colorLight)
	self:assertEquals('#8f7722', presets.banana.colorDark)
end

-- resolveAuto()

function suite:testResolveAutoLargePicksHuman()
	self:assertEquals(presets.human, presets.resolveAuto(18))
end

function suite:testResolveAutoAtHumanThreshold()
	self:assertEquals(presets.human, presets.resolveAuto(1.8))
end

function suite:testResolveAutoMediumPicksBanana()
	self:assertEquals(presets.banana, presets.resolveAuto(1))
end

function suite:testResolveAutoTinyFallsBackToBanana()
	self:assertEquals(presets.banana, presets.resolveAuto(0.1))
end

function suite:testResolveAutoCustomLadder()
	-- A caller-supplied ladder (e.g. SCU cargo boxes), ordered largest first.
	local ladder = {
		{ scu = 8, length = 2.5, width = 2.5, height = 2.5 },
		{ scu = 1, length = 1.25, width = 1.25, height = 1.25 },
		{ scu = 0.125, length = 0.5, width = 0.5, height = 0.5 },
	}
	-- 2.21 m cargo: largest box whose longest dim <= 2.21 is the 1 SCU box.
	self:assertEquals(1, presets.resolveAuto(2.21, ladder).scu)
	-- Tiny cargo: falls back to the smallest box.
	self:assertEquals(0.125, presets.resolveAuto(0.1, ladder).scu)
end

return suite
