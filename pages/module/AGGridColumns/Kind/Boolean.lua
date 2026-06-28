require('strict')

--- 'boolean' kind -- an icon-only tri-state boolean, rendered by the gadget's
--- scwBoolean type. Maps the raw cell value through Module:Boolean.gridClassify
--- (the shared yes / no / unknown classifier) to { text, state, iconSrc }. `text`
--- is the sort / set-filter key (real "Yes"/"No" words) even though the cell
--- shows only a glyph. Spec: { field, header, label, filter?, width? }.

local Util = require('Module:AGGridColumns/Util')
local Boolean = require('Module:Boolean')
local Icon = require('Module:Icon')

local p = {}
p.type = 'scwBoolean'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		type = 'scwBoolean',
		filter = spec.filter or 'aggridSet',
		sortable = true,
		width = spec.width,
		suppressAutoSize = true,
	}
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	-- Normalise the raw SMW value first (entity-decode, unwrap { fulltext } table
	-- shapes), matching the sibling Badge / BadgeList kinds, so the value reaches
	-- Module:Yesno in a parseable form rather than silently classifying unknown.
	local raw = Util.decodeScalar(result[spec.label])
	if raw == nil or raw == '' then
		return nil
	end
	local b = Boolean.gridClassify(raw)
	return { text = b.text, state = b.state, iconSrc = Icon.src(b.icon) }
end

return p
