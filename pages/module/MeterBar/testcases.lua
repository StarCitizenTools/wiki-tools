require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local MeterBar = require('Module:MeterBar')

local suite = ScribuntoUnit:new()

-- clampPct()

function suite:testClampPctNormal()
	self:assertEquals(40, MeterBar._internal.clampPct(40, 100))
end

function suite:testClampPctBelowZero()
	self:assertEquals(0, MeterBar._internal.clampPct(-5, 100))
end

function suite:testClampPctAboveHundred()
	self:assertEquals(100, MeterBar._internal.clampPct(250, 100))
end

function suite:testClampPctZeroMax()
	self:assertEquals(0, MeterBar._internal.clampPct(5, 0))
end

function suite:testClampPctFraction()
	self:assertEquals(50, MeterBar._internal.clampPct(26400, 52800))
end

return suite
