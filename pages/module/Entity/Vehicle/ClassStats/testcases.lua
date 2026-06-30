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

function suite:testCohortRowsFoldsSignatureModifier()
	local realSmw = mw.smw
	mw.smw = {
		ask = function()
			return {
				-- stealth coating ×0.5 folds into IR and every cross-section axis
				{
					ir_emission = '10000',
					ir_modifier = '0.5',
					cross_section_length = '10000',
					cross_section_modifier = '0.5',
				},
				{ ir_emission = '8000' }, -- no modifier → unchanged
				{ ir_emission = '6000', em_emission = '4000', em_modifier = '2' }, -- louder EM → 8000
				{ ir_emission = '4000' },
				{ ir_emission = '2000' },
			}
		end,
	}
	-- size 985: unique across the vehicle suites (rowCache is shared per family|size).
	local rows = ClassStats.cohortRows('ship', 985)
	mw.smw = realSmw
	self:assertEquals(5000, rows[1].ir_emission) -- 10000 × 0.5
	self:assertEquals(8000, rows[2].ir_emission) -- absent multiplier → raw
	self:assertEquals(8000, rows[3].em_emission) -- 4000 × 2
	self:assertEquals(5000, rows[1].cross_section_length) -- per-axis folds the same modifier
	self:assertEquals(nil, rows[1].ir_modifier) -- modifier key dropped, never a phantom stat
	self:assertEquals(nil, rows[1].cross_section_modifier)
end

return suite
