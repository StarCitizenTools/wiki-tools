require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Availability = require('Module:Entity/Availability')

local suite = ScribuntoUnit:new()

-- buildSummaryRows() dispatches on result.kind

function suite:testBuildSummaryRowsDispatchesCommodityByKind()
	local apiData = { box_sizes_scu = { 1, 2 }, _rawRecord = { is_mineable = true } }
	local rows = Availability._internal.buildSummaryRows({}, apiData, 'Commodity')
	local hasMine = false
	for _, r in ipairs(rows) do
		if r.label == 'Mine' then
			hasMine = true
		end
	end
	self:assertTrue(hasMine, 'kind="Commodity" should route to the commodity summary builder')
end

-- The dispatch keys on result.kind, NOT on apiData fields (the point of the
-- refactor): an Item carrying a box_sizes_scu field must still route to the item
-- builder, not the commodity one.
function suite:testBuildSummaryRowsKeysOnKindNotFields()
	local rows = Availability._internal.buildSummaryRows({}, { box_sizes_scu = { 1 }, uuid = 'x' }, 'Item')
	local hasMine = false
	for _, r in ipairs(rows) do
		if r.label == 'Mine' then
			hasMine = true
		end
	end
	self:assertFalse(hasMine, 'kind="Item" must not route to the commodity builder even with box_sizes_scu present')
end

-- buildCommoditySummaryRows()

function suite:testCommoditySummaryMineableHarvestable()
	local apiData = {
		box_sizes_scu = { 1, 2 },
		_rawRecord = { is_mineable = true, has_harvestables = false },
	}
	local rows = Availability._internal.buildCommoditySummaryRows({}, apiData)
	local function value(label)
		for _, r in ipairs(rows) do
			if r.label == label then
				return r.value
			end
		end
	end
	self:assertEquals(true, value('Mine'))
	self:assertEquals(false, value('Harvest'))
	-- No UEX purchase data → Buy is unknown (nil).
	self:assertEquals(nil, value('Buy'))
end

return suite
