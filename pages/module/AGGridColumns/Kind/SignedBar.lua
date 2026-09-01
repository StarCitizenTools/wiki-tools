require('strict')

--- 'signedBar' kind — a signed number drawn as a bar growing from a centre line,
--- rendered by the gadget's scwSignedBar type. For columns of signed deltas whose
--- SIGN alone does not say good or bad: a mining module's resistance +15% is a
--- penalty while its shatter damage −30% is a benefit, so a reader who does not
--- already know each stat's polarity cannot skim the column.
---
--- `good` names the direction that helps, and the bar leans that way regardless of
--- sign — a −80% overcharge rate and a +100% charge window both lean right. Omit
--- `good` for a stat with no inherent good side: the bar then leans by sign and is
--- drawn neutral.
---
--- Bar length is the value's share of `max`, which the consumer computes across the
--- whole column (see Module:DataGrid) and which the gadget reads off the colDef as
--- `scwBarMax`. Scaling on the column rather than per cell is what makes two rows
--- comparable at a glance; it deliberately does not rescale when rows are filtered,
--- so a bar means the same thing before and after.
---
--- Spec: { field, header, label, good? ('higher'|'lower'), max, width? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwSignedBar'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	local def = {
		field = spec.field,
		headerName = spec.header,
		type = 'scwSignedBar',
		filter = 'agNumberColumnFilter',
		cellClass = 'ag-right-aligned-cell',
		headerClass = 'ag-right-aligned-header',
		width = spec.width,
		suppressAutoSize = true,
	}
	-- The column's scale, read by the gadget's cellRenderer. A non-positive max
	-- would divide every bar by zero, so it is normalised here rather than in JS.
	local max = tonumber(spec.max) or 0
	def.scwBarMax = max > 0 and max or 1
	return def
end

--- Formats a signed percentage, rounded to one decimal. Mirrors
--- Entity/Facet/Mining's signedPct so a grid cell and an infobox row read alike.
--- @param n number
--- @return string
local function signedPct(n)
	local rounded = math.floor(math.abs(n) * 10 + 0.5) / 10
	if n < 0 then
		rounded = -rounded
	end
	local sign = rounded >= 0 and '+' or ''
	return sign .. mw.getContentLanguage():formatNum(rounded) .. '%'
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	local n = Util.toNumber(result[spec.label])
	if n == nil then
		return nil
	end
	local value = { value = n, text = signedPct(n) }
	-- `good` is deliberately absent, not false, when the column has no direction or
	-- the value sits on the baseline — the gadget distinguishes "leans the bad way"
	-- from "has no good way", and a 0 is neither.
	if n ~= 0 then
		if spec.good == 'higher' then
			value.good = n > 0
		elseif spec.good == 'lower' then
			value.good = n < 0
		end
	end
	return value
end

return p
