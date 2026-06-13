require('strict')

--- The contract every Module:AGGridColumns/Kind/* module must satisfy. A kind is
--- inert without all three, so all are required. `type` is the JS column type the
--- kind pairs with under the gadget's reg.columnTypes (or `false` for a type-less
--- plain column). Enforced by Module:AGGridColumns/testcases (conformance loop).

local p = {}

--- @class ColumnKind
--- @field type string|false   the JS colDef type (or false for none)
--- @field buildColDef fun(spec: table): table
--- @field buildCellValue fun(spec: table, result: table): any

p.COLUMN_KIND = {
	type = 'field', -- present (string or false); checked for nil
	buildColDef = 'function',
	buildCellValue = 'function',
}

--- Validate a kind module against COLUMN_KIND.
--- @param kind table
--- @return boolean ok
--- @return string|nil message  set when ok is false
function p.validate(kind)
	if type(kind) ~= 'table' then
		return false, 'kind is not a table'
	end
	if kind.type == nil then
		return false, 'missing "type" (use false for a type-less plain column)'
	end
	if type(kind.buildColDef) ~= 'function' then
		return false, 'missing buildColDef function'
	end
	if type(kind.buildCellValue) ~= 'function' then
		return false, 'missing buildCellValue function'
	end
	return true
end

return p
