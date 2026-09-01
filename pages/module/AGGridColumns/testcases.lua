require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local AGGridColumns = require('Module:AGGridColumns')
local Registry = require('Module:AGGridColumns/Registry')
local Contract = require('Module:AGGridColumns/Contract')

-- Conformance: every registered kind satisfies the contract.
function suite:testAllKindsConform()
	for name, kind in pairs(Registry) do
		local ok, message = Contract.validate(kind)
		self:assertTrue(ok, 'kind "' .. name .. '" fails contract: ' .. tostring(message))
	end
end

function suite:testValidateRejectsMissingBuildColDef()
	local ok = Contract.validate({ type = 'x', buildCellValue = function() end })
	self:assertFalse(ok)
end

-- colDef shapes (the type string per kind).
local function colDefOf(spec)
	return AGGridColumns.buildColumnDefs({ spec })[1]
end

function suite:testTextColDefHasNoType()
	self:assertEquals(nil, colDefOf({ kind = 'text', field = 'c', header = 'C', label = 'C' }).type)
end

function suite:testSmartColDefType()
	self:assertEquals('scwSmart', colDefOf({ kind = 'smart', field = 'c', header = 'C', label = 'C' }).type)
end

function suite:testNumberColDefType()
	self:assertEquals('numericColumn', colDefOf({ kind = 'number', field = 'c', header = 'C', label = 'C' }).type)
end

function suite:testBadgeColDefType()
	self:assertEquals('scwBadge', colDefOf({ kind = 'badge', field = 'c', header = 'C', label = 'C' }).type)
end

function suite:testCardColDefType()
	self:assertEquals('scwEntityCard', colDefOf({ kind = 'card', field = 'c', header = 'C', titleLabel = 'Name' }).type)
end

function suite:testStackedValueColDefRightAligned()
	local def = colDefOf({ kind = 'stackedValue', field = 'c', header = 'C', curLabel = 'P' })
	self:assertEquals('scwStackedValue', def.type)
	self:assertEquals('ag-right-aligned-cell', def.cellClass)
end

function suite:testValueListColDefType()
	local def = colDefOf({ kind = 'valueList', field = 'c', header = 'C', label = 'C' })
	self:assertEquals('aggridLinkList', def.type)
	self:assertEquals('aggridSet', def.filter)
end

-- The bar leans the way that HELPS, not the way the sign points: a 'lower' column
-- marks a negative value good, so a -80% overcharge rate and a +100% window both
-- lean right. A 0 sits on the baseline and is neither.
function suite:testSignedBarDirection()
	local Bar = Registry.signedBar
	local spec = { field = 'c1', label = 'V', good = 'lower', max = 80 }
	self:assertEquals(true, Bar.buildCellValue(spec, { V = -80 }).good)
	self:assertEquals(false, Bar.buildCellValue(spec, { V = 15 }).good)
	local higher = { field = 'c1', label = 'V', good = 'higher', max = 100 }
	self:assertEquals(true, Bar.buildCellValue(higher, { V = 100 }).good)
	self:assertEquals(false, Bar.buildCellValue(higher, { V = -30 }).good)
	-- No direction declared, and the baseline, both leave `good` absent so the
	-- gadget draws them neutral rather than as a verdict.
	self:assertEquals(nil, Bar.buildCellValue({ field = 'c1', label = 'V' }, { V = 20 }).good)
	self:assertEquals(nil, Bar.buildCellValue(spec, { V = 0 }).good)
	self:assertEquals(nil, Bar.buildCellValue(spec, { V = nil }))
end

-- The cell carries the raw number for sort/filter and a signed display string that
-- matches the infobox row's formatting.
function suite:testSignedBarCellValue()
	local Bar = Registry.signedBar
	local v = Bar.buildCellValue({ field = 'c1', label = 'V', good = 'lower', max = 80 }, { V = -15.5 })
	self:assertEquals(-15.5, v.value)
	self:assertEquals('−15.5%', v.text)
	self:assertEquals('+15.5%', Bar.buildCellValue({ field = 'c1', label = 'V' }, { V = 15.5 }).text)
end

-- The column's scale reaches the gadget on the colDef; a non-positive max would
-- divide every bar by zero, so it is normalised to 1.
function suite:testSignedBarColDefCarriesScale()
	local Bar = Registry.signedBar
	self:assertEquals(80, Bar.buildColDef({ field = 'c1', header = 'V', max = 80 }).scwBarMax)
	self:assertEquals(1, Bar.buildColDef({ field = 'c1', header = 'V', max = 0 }).scwBarMax)
	self:assertEquals(1, Bar.buildColDef({ field = 'c1', header = 'V' }).scwBarMax)
	self:assertEquals('agNumberColumnFilter', Bar.buildColDef({ field = 'c1', header = 'V', max = 5 }).filter)
end

function suite:testUnknownKindErrors()
	self:assertThrows(function()
		AGGridColumns.buildColumnDefs({ { kind = 'nope', field = 'c' } })
	end)
end

-- cell shapes for pure kinds.
local function cellOf(spec, result)
	return AGGridColumns.buildRowData({ result }, { spec })[1][spec.field]
end

function suite:testTextCell()
	self:assertEquals('Laser', cellOf({ kind = 'text', field = 'c', label = 'C' }, { C = 'Laser' }))
end

function suite:testNumberCell()
	self:assertEquals(1234, cellOf({ kind = 'number', field = 'c', label = 'C' }, { C = '1,234 m' }))
end

function suite:testBadgeCell()
	local v = cellOf({ kind = 'badge', field = 'c', label = 'C', variants = { Ready = 'success' } }, { C = 'Ready' })
	self:assertEquals('Ready', v.text)
	self:assertEquals('success', v.variant)
end

function suite:testStackedValueCellShowsSubWhenDiffers()
	local v = cellOf(
		{ kind = 'stackedValue', field = 'c', curLabel = 'Cur', origLabel = 'Orig' },
		{ Cur = '50', Orig = '70' }
	)
	self:assertEquals(50, v.value)
	self:assertEquals('$50', v.text)
	self:assertEquals('$70', v.sub)
end

function suite:testStackedValueCellNoSubWhenSame()
	local v = cellOf(
		{ kind = 'stackedValue', field = 'c', curLabel = 'Cur', origLabel = 'Orig' },
		{ Cur = '50', Orig = '50' }
	)
	self:assertEquals(nil, v.sub)
end

-- A value-list cell splits a multi-valued printout into one { text } item per value
-- (the extension's set filter then offers one option per value).
function suite:testValueListCellSplitsMultiValue()
	local v = cellOf({ kind = 'valueList', field = 'c', label = 'C' }, { C = { 'mining', 'salvage' } })
	self:assertDeepEquals({ links = { { text = 'mining' }, { text = 'salvage' } } }, v)
end

function suite:testValueListCellNilWhenAbsent()
	self:assertEquals(nil, cellOf({ kind = 'valueList', field = 'c', label = 'C' }, {}))
end

-- Contract: a kind with no `type` at all (nil, not false) is rejected.
function suite:testValidateRejectsMissingType()
	local ok = Contract.validate({ buildColDef = function() end, buildCellValue = function() end })
	self:assertFalse(ok)
end

-- A cell whose source field is absent yields nil (the row key is simply omitted).
function suite:testTextCellNilWhenAbsent()
	self:assertEquals(nil, cellOf({ kind = 'text', field = 'c', label = 'C' }, {}))
end

-- A badge value not present in the variants map gets a nil variant (neutral pill).
function suite:testBadgeCellUnmappedVariant()
	local v = cellOf({ kind = 'badge', field = 'c', label = 'C' }, { C = 'Unmapped' })
	self:assertEquals('Unmapped', v.text)
	self:assertEquals(nil, v.variant)
end

-- boolean kind: colDef carries the scwBoolean JS type
function suite:testBooleanColDefType()
	self:assertEquals('scwBoolean', colDefOf({ kind = 'boolean', field = 'c', header = 'C', label = 'C' }).type)
end

-- boolean kind: an absent field yields an empty cell (no Icon.src call)
function suite:testBooleanCellEmpty()
	self:assertEquals(nil, cellOf({ kind = 'boolean', field = 'c', label = 'C' }, {}))
end

return suite
