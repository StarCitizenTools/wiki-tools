local ScribuntoUnit = require('Module:ScribuntoUnit')
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

function suite:testCohortRowsNilWithNoBucketRows()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	self:assertEquals(nil, ClassStats.cohortRows('ship', 4))
end

-- Rows as the real extension returns them for a joined query: keyed by the
-- qualified selector; Store maps them to the stat keys.
local function row(over)
	local base = {
		scm_speed = 200,
		max_speed = 1000,
		ir_emission = 100,
		ir_modifier = 0.5,
		em_emission = 50,
		cross_section = 10,
		cross_section_length = 20,
		cross_section_width = 8,
		cross_section_height = 5,
	}
	for k, v in pairs(over or {}) do
		base[k] = v
	end
	local r = {}
	for k, v in pairs(base) do
		r[selectorFor(k)] = v
	end
	return r
end

local function cohort(n)
	local rows = {}
	for i = 1, n do
		rows[i] = row({ scm_speed = 100 + i })
	end
	return rows
end

--- cohortRows' contract is "nil when comparison is unavailable"; a Bucket
--- infrastructure failure must land in that same bucket, not error the page.
function suite:testCohortRowsContainsBucketFailure()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', cohort(6))
	bucketLib._failNext = true
	self:assertEquals(nil, ClassStats.cohortRows('ship', 991))
end

function suite:testCohortBelowMinimumIsNil()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', cohort(4))
	self:assertEquals(nil, ClassStats.cohortRows('ship', 3))
end

function suite:testCohortQueryShape()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', cohort(6))
	ClassStats.cohortRows('ship', 3)
	local chain = bucketLib._chains[1]
	self:assertEquals('entity', chain.bucket)
	self:assertDeepEquals({ { 'subject_type', '=', 'Spacecraft' }, { 'size', '=', 3 } }, chain.where)
	self:assertDeepEquals({ { 'vehicle_stats', 'vehicle_stats.page_name', 'entity.page_name' } }, chain.join)
	self:assertEquals(500, chain.limit)
	self:assertEquals(29, #chain.select)
end

function suite:testCohortFoldsSignatureModifiers()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', cohort(6))
	local out = ClassStats.cohortRows('ship', 3)
	self:assertEquals(6, #out)
	self:assertEquals(50, out[1].ir_emission)
	self:assertEquals(nil, out[1].ir_modifier)
	self:assertEquals(101, out[1].scm_speed)
end

function suite:testCohortMemoised()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', cohort(6))
	ClassStats.cohortRows('ship', 3)
	ClassStats.cohortRows('ship', 3)
	self:assertEquals(1, #bucketLib._chains)
end

function suite:testNonShipFamilyIsNil()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	self:assertEquals(nil, ClassStats.cohortRows('ground', 3))
	self:assertEquals(0, #bucketLib._chains)
end

return suite
