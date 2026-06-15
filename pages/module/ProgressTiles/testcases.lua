require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local ProgressTiles = require('Module:ProgressTiles')

local suite = ScribuntoUnit:new()

-- heatmap() — default thirds

function suite:testHeatmapWeak()
	self:assertEquals('var(--color-error)', ProgressTiles.heatmap(20, 100))
end

function suite:testHeatmapMid()
	self:assertEquals('var(--color-warning)', ProgressTiles.heatmap(50, 100))
end

function suite:testHeatmapStrong()
	self:assertEquals('var(--color-success)', ProgressTiles.heatmap(80, 100))
end

-- heatmap() — custom thresholds (the armour banding)

function suite:testHeatmapCustomWeak()
	self:assertEquals('var(--color-error)', ProgressTiles.heatmap(20, 100, { 0.2, 0.45 }))
end

function suite:testHeatmapCustomMid()
	self:assertEquals('var(--color-warning)', ProgressTiles.heatmap(40, 100, { 0.2, 0.45 }))
end

function suite:testHeatmapCustomStrong()
	self:assertEquals('var(--color-success)', ProgressTiles.heatmap(60, 100, { 0.2, 0.45 }))
end

-- heatmap() — defaults and edge cases

function suite:testHeatmapDefaultMax()
	-- max defaults to 100, so 80 is strong
	self:assertEquals('var(--color-success)', ProgressTiles.heatmap(80))
end

function suite:testHeatmapZeroMax()
	-- ratio collapses to 0 -> weak, never divides by zero
	self:assertEquals('var(--color-error)', ProgressTiles.heatmap(5, 0))
end

-- clampPct()

function suite:testClampPctNormal()
	self:assertEquals(40, ProgressTiles._internal.clampPct(40, 100))
end

function suite:testClampPctBelowZero()
	self:assertEquals(0, ProgressTiles._internal.clampPct(-5, 100))
end

function suite:testClampPctAboveHundred()
	self:assertEquals(100, ProgressTiles._internal.clampPct(250, 100))
end

function suite:testClampPctZeroMax()
	self:assertEquals(0, ProgressTiles._internal.clampPct(5, 0))
end

return suite
