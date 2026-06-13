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

return suite
