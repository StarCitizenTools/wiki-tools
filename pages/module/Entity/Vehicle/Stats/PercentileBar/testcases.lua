local ScribuntoUnit = require('Module:ScribuntoUnit')
local PercentileBar = require('Module:Entity/Vehicle/Stats/PercentileBar')
local suite = ScribuntoUnit:new()

function suite:testNilValue()
	self:assertEquals(nil, PercentileBar.item({ label = 'X', valueText = nil, percentile = 80 }))
end
function suite:testDegradesWithoutPercentile()
	local i = PercentileBar.item({ label = 'SCM speed', valueText = '190 m/s', percentile = nil })
	self:assertEquals('SCM speed', i.label)
	self:assertEquals('190 m/s', i.content)
end
function suite:testBuildsBar()
	local i = PercentileBar.item({ label = 'SCM speed', valueText = '190 m/s', percentile = 42 })
	self:assertEquals('t-infobox-item--block', i.class)
	self:assertEquals(nil, i.label)
end
return suite
