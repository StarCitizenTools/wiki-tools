local ScribuntoUnit = require('Module:ScribuntoUnit')
local Overview = require('Module:Entity/Vehicle/Stats/Overview')
local ClassStats = require('Module:Entity/Vehicle/ClassStats')
local store = require('Module:Entity/Store')
local bucketLib = require('mw.ext.bucket')
local suite = ScribuntoUnit:new()

-- Bucket selector for a cohort stat key, resolved through the real manifest
-- (Module:Entity/Store) rather than a hardcoded field-naming rule.
local function selectorFor(key)
	local entry = store.resolve(ClassStats._internal.cohortProps[key], 'Vehicle')
	if entry.bucket == 'entity' then
		return entry.field
	end
	return entry.bucket .. '.' .. entry.field
end

-- Rows as the real extension returns them for a joined query: keyed by the
-- qualified selector; Store maps them to the stat keys.
local function row(fields)
	local r = {}
	for k, v in pairs(fields) do
		r[selectorFor(k)] = v
	end
	return r
end

function suite:testRingTabFromCohort()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ health = 100000 }),
		row({ health = 200000 }),
		row({ health = 150000 }),
		row({ health = 120000 }),
		row({ health = 130000 }),
	})
	local tab = Overview.build({ is_spaceship = true, size_class = 3, health = 150000 }, {}, {})
	self:assertEquals('Overview', tab.label)
	self:assertEquals(nil, tab.key)
	self:assertEquals(1, #tab.items) -- one block holding the ring row + cohort footer
	self:assertEquals('t-infobox-item--block', tab.items[1].class)
	-- The cohort footer is plain Lua concat (BadgeLua stubbed to echo its text),
	-- independent of the stubbed ProgressTiles: a Beta badge + "vs. N S<class> ships"
	-- (5 = cohort size, 3 = size class).
	self:assertTrue(tab.items[1].content:find('Beta', 1, true) ~= nil)
	self:assertTrue(tab.items[1].content:find('vs. 5 S3 ships', 1, true) ~= nil)
end

-- No rows installed: Bucket returns none for size 4, so cohortRows is nil.
function suite:testNilWithoutCohort()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	self:assertEquals(nil, Overview.build({ is_spaceship = true, size_class = 4, health = 1 }, {}, {}))
end

-- Note: ProgressTiles is stubbed to '' in the headless runner, so the ring gauges
-- themselves are verified in-browser, not here; the percentile DATA behind them is
-- covered by Module:Entity/Vehicle/Stats/Profile/testcases.

return suite
