local ScribuntoUnit = require('Module:ScribuntoUnit')
local Overview = require('Module:Entity/Vehicle/Stats/Overview')
local suite = ScribuntoUnit:new()

local function stub(rows)
	local r = mw.smw
	mw.smw = {
		ask = function()
			return rows
		end,
	}
	return r
end

function suite:testRingTabFromCohort()
	local real = stub({
		{ health = '100000' },
		{ health = '200000' },
		{ health = '150000' },
		{ health = '120000' },
		{ health = '130000' },
	})
	local tab = Overview.build({ is_spaceship = true, size_class = 994, health = 150000 }, {}, {})
	mw.smw = real
	self:assertEquals('Overview', tab.label)
	self:assertEquals(nil, tab.key)
	self:assertEquals(1, #tab.items) -- one block holding the ring row + cohort footer
	self:assertEquals('t-infobox-item--block', tab.items[1].class)
	-- The cohort footer is plain Lua concat, independent of the stubbed ProgressTiles.
	self:assertTrue(tab.items[1].content:find('Ranked among 5 same-size ships', 1, true) ~= nil)
end

function suite:testNilWithoutCohort()
	self:assertEquals(nil, Overview.build({ is_spaceship = true, size_class = 4, health = 1 }, {}, {}))
end

-- Note: ProgressTiles is stubbed to '' in the headless runner, so the ring gauges
-- themselves are verified in-browser, not here; the percentile DATA behind them is
-- covered by Module:Entity/Vehicle/Stats/Profile/testcases.

return suite
