require('strict')

--- @module Entity/Commodity/Variants
--- Body renderer: collapsed table of the SCU packaging ladder, derived from
--- the commodity record's box_sizes_scu + density_g_per_cc (no /items fetch).
--- Consumes Module:Entity/Data so it shares Apiunto's cache with the infobox.

local data = require('Module:Entity/Data')
local util = require('Module:Entity/Util')

local p = {}

--- @param boxSizes number[]|nil
--- @param density number|nil
--- @return table[] rows of { scu, mass_kg }
local function buildRows(boxSizes, density)
	local rows = {}
	if type(boxSizes) ~= 'table' then
		return rows
	end
	local d = tonumber(density) or 0
	for _, scu in ipairs(boxSizes) do
		rows[#rows + 1] = { scu = scu, mass_kg = scu * d * 1000 }
	end
	table.sort(rows, function(a, b)
		return a.scu < b.scu
	end)
	return rows
end

--- @param frame table
--- @return string
function p.render(frame)
	local result = data.get(data.parseArgs(frame))
	local rec = result.apiData._refinedRecord or result.apiData
	local rows = buildRows(rec.box_sizes_scu, rec.density_g_per_cc)
	if #rows == 0 then
		return ''
	end

	local tbl = mw.html.create('table'):addClass('wikitable mw-collapsible mw-collapsed')
	tbl:tag('caption'):wikitext('Cargo variants')
	local head = tbl:tag('tr')
	head:tag('th'):wikitext('SCU')
	head:tag('th'):wikitext('Mass')
	for _, r in ipairs(rows) do
		local tr = tbl:tag('tr')
		tr:tag('td'):wikitext(util.formatNum(r.scu))
		tr:tag('td'):wikitext(util.formatNum(r.mass_kg) .. ' kg')
	end
	return tostring(tbl)
end

p._internal = { buildRows = buildRows }

return p
