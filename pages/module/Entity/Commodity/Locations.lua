require('strict')

--- @module Entity/Commodity/Locations
--- Body renderer: mining deposit locations grouped by system, from the raw
--- commodity record's locations[]. Consumes Module:Entity/Data.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')

local p = {}

--- @param locations table[]|nil
--- @return table[] groups of { system, rows = { { body, type, spawn_pct, quality } } }
local function groupBySystem(locations)
	local order, bySystem = {}, {}
	if type(locations) ~= 'table' then
		return {}
	end
	for _, l in ipairs(locations) do
		local sys = l.system or 'Unknown'
		if not bySystem[sys] then
			bySystem[sys] = { system = sys, rows = {} }
			order[#order + 1] = sys
		end
		local quality = nil
		if l.quality_min and l.quality_max then
			quality = tostring(l.quality_min) .. '–' .. tostring(l.quality_max)
		end
		table.insert(bySystem[sys].rows, {
			body = l.display_name or l.name,
			type = l.type,
			spawn_pct = l.relative_probability_percent,
			quality = quality,
		})
	end
	local groups = {}
	for _, sys in ipairs(order) do
		groups[#groups + 1] = bySystem[sys]
	end
	return groups
end

--- @param frame table
--- @return string
function p.render(frame)
	local result = data.get(data.parseArgs(frame))
	local raw = result.apiData._rawRecord
	local groups = groupBySystem(raw and raw.locations)
	if #groups == 0 then
		return ''
	end

	local out = {}
	for _, g in ipairs(groups) do
		local tbl = mw.html.create('table'):addClass('wikitable wikitable--fluid sortable')
		local head = tbl:tag('tr')
		head:tag('th'):wikitext('Body')
		head:tag('th'):wikitext('Type')
		head:tag('th'):wikitext('Spawn %')
		head:tag('th'):wikitext('Quality')
		for _, r in ipairs(g.rows) do
			local tr = tbl:tag('tr')
			tr:tag('td'):wikitext(r.body or '')
			tr:tag('td'):wikitext(r.type or '')
			tr:tag('td'):wikitext(r.spawn_pct and (tostring(r.spawn_pct) .. '%') or '')
			tr:tag('td'):wikitext(r.quality or '')
		end
		local count = #g.rows
		out[#out + 1] = collapsibleCard.render({
			title = g.system,
			description = count .. (count == 1 and ' deposit' or ' deposits'),
			content = tostring(tbl),
		})
	end
	return table.concat(out, '\n')
end

p._internal = { groupBySystem = groupBySystem }

return p
