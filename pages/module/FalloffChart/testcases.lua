require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local FalloffChart = require('Module:FalloffChart')

local suite = ScribuntoUnit:new()
local I = FalloffChart._internal

function suite:testFmtNum()
	self:assertEquals('16.67', I.fmtNum(16.666))
	self:assertEquals('50', I.fmtNum(50.00))
	self:assertEquals('3.64', I.fmtNum(3.6363))
	self:assertEquals('0', I.fmtNum(0))
end

function suite:testClampPct()
	self:assertEquals(50, I.clampPct(50, 100))
	self:assertEquals(100, I.clampPct(150, 100))
	self:assertEquals(0, I.clampPct(-5, 100))
	self:assertEquals(0, I.clampPct(5, 0))
end

function suite:testBuildClip()
	-- Clean model: full 20 to x=10, floor 10 by x=50, domain 60, yMax 20.
	-- y% = 100 - (y/20*100): 20 -> 0%, 10 -> 50%.
	local points = {
		{ x = 0, y = 20 },
		{ x = 10, y = 20 },
		{ x = 50, y = 10 },
		{ x = 60, y = 10 },
	}
	self:assertEquals(
		'polygon(0% 100%, 0% 0%, 16.67% 0%, 83.33% 50%, 100% 50%, 100% 100%)',
		I.buildClip(points, 60, 20)
	)
end

return suite
