local ScribuntoUnit = require('Module:ScribuntoUnit')
local ClassStats = require('Module:Entity/Vehicle/ClassStats')

local suite = ScribuntoUnit:new()

function suite:testPercentile()
	local v = { 10, 20, 30, 40, 50 }
	self:assertEquals(50, ClassStats.percentile(v, 30)) -- Hazen: (2 below + 0.5*1 equal)/5
	self:assertEquals(90, ClassStats.percentile(v, 50)) -- leader: (4 + 0.5)/5
	self:assertEquals(10, ClassStats.percentile(v, 10)) -- floor: (0 + 0.5)/5
	self:assertEquals(nil, ClassStats.percentile({}, 10))
end

function suite:testPercentileHazenMedianAndTies()
	self:assertEquals(50, ClassStats.percentile({ 1, 2, 3 }, 2)) -- middle reads 50
	self:assertEquals(30, ClassStats.percentile({ 0, 0, 0, 10, 20 }, 0)) -- ties not inflated: (0 + 0.5*3)/5
end

function suite:testCohortRowsNilWithoutSmw()
	self:assertEquals(nil, ClassStats.cohortRows('ship', 4))
end

function suite:testCohortRowsNonShip()
	local realSmw = mw.smw
	mw.smw = {
		ask = function()
			error('should not query for non-ship')
		end,
	}
	local r = ClassStats.cohortRows('ground', 2)
	mw.smw = realSmw
	self:assertEquals(nil, r)
end

function suite:testCohortRowsStubbedDecodes()
	local realSmw = mw.smw
	mw.smw = {
		ask = function()
			return {
				{ health = '100,000', pilot_dps = '4000' },
				{ health = '200000' },
				{ health = '150000' },
				{ health = '120000' },
				{ health = '130000' },
			}
		end,
	}
	local rows = ClassStats.cohortRows('ship', 991)
	mw.smw = realSmw
	self:assertEquals(5, #rows)
	self:assertEquals(100000, rows[1].health)
	self:assertEquals(4000, rows[1].pilot_dps)
	self:assertEquals(nil, rows[2].pilot_dps) -- missing decodes to absent, not 0
end

return suite
