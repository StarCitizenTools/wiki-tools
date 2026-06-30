require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Standing = require('Module:Entity/Vehicle/Stats/Standing')

local suite = ScribuntoUnit:new()

function suite:testPositionHigherIsBetter()
	local v = { 10, 20, 30, 40, 50 }
	self:assertEquals(1, Standing.position(v, 50)) -- top
	self:assertEquals(3, Standing.position(v, 30)) -- middle
	self:assertEquals(5, Standing.position(v, 10)) -- bottom
	self:assertEquals(nil, Standing.position({}, 10)) -- empty cohort
end

function suite:testPositionInvertLowerIsBetter()
	local v = { 10, 20, 30, 40, 50 }
	self:assertEquals(1, Standing.position(v, 10, true)) -- lowest is best (e.g. emissions)
	self:assertEquals(5, Standing.position(v, 50, true))
end

function suite:testPositionTiesShareRank()
	-- only 40 is strictly better than 30, so both 30s share 2nd
	self:assertEquals(2, Standing.position({ 10, 30, 30, 40 }, 30))
end

function suite:testMedalPodium()
	-- Emoji only; the ordinal rides in the title so it doubles as a hover tooltip. The
	-- emoji is an icon: user-select:none keeps it out of the copyable value, and the
	-- margin spaces it from the value without a literal whitespace character.
	local style = ' style="user-select:none;-webkit-user-select:none;margin-right:0.35em"'
	self:assertEquals('<span title="1st of the size class"' .. style .. '>\240\159\165\135</span>', Standing.medal(1)) -- 🥇
	self:assertEquals('<span title="2nd of the size class"' .. style .. '>\240\159\165\136</span>', Standing.medal(2)) -- 🥈
	self:assertEquals('<span title="3rd of the size class"' .. style .. '>\240\159\165\137</span>', Standing.medal(3)) -- 🥉
end

function suite:testMedalNilBeyondPodium()
	-- Ranks beyond the podium are noise in a small size class — no indicator.
	self:assertEquals(nil, Standing.medal(4))
	self:assertEquals(nil, Standing.medal(11))
end

function suite:testColorScaleOliveToGreen()
	self:assertEquals('#6a7a52', Standing.color(0)) -- olive (low)
	self:assertEquals('#3aa676', Standing.color(100)) -- green (high)
	self:assertEquals('#529064', Standing.color(50)) -- midpoint interpolation
end

function suite:testStopsMatchScaleEndpoints()
	self:assertEquals('#6a7a52', Standing.stops[1].color)
	self:assertEquals('#3aa676', Standing.stops[2].color)
end

return suite
