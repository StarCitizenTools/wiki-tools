require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Util = require('Module:Entity/Facet/Util')

local suite = ScribuntoUnit:new()

function suite:testWithUnit()
	self:assertEquals('800 m/s', Util.withUnit(800, ' m/s'))
	self:assertEquals('1,600 m', Util.withUnit(1600, ' m'))
	self:assertEquals(nil, Util.withUnit(nil, ' m'))
	self:assertEquals(nil, Util.withUnit('abc', ' m'))
end

function suite:testTitleCase()
	self:assertEquals('Jump speed', Util.titleCase('jump_speed'))
	self:assertEquals('Atrophic', Util.titleCase('atrophic'))
end

function suite:testRangeStr()
	self:assertEquals('4–5.5 m', Util.rangeStr(4, 5.5, 'm'))
	self:assertEquals('3 m', Util.rangeStr(3, 3, 'm'))
	self:assertEquals('3 m', Util.rangeStr(3, nil, 'm'))
	self:assertEquals(nil, Util.rangeStr(nil, nil, 'm'))
end

function suite:testDamageKeysAndLabels()
	self:assertEquals('physical', Util.damageKeys()[1])
	self:assertEquals('Physical', Util.damageLabels().physical)
	self:assertEquals('Stun', Util.damageLabels().stun)
end

return suite
