require('strict')

--- @module Entity/Facet/Flashlight
--- Flashlight facet. A weapon light carries a top-level `flashlight` block: an
--- object of named light modes (e.g. `narrow`, `wide`), each with a beam type
--- (Projector / Omni), a light radius, and an intensity. Renders one row per mode
--- ("Narrow → Projector, 35 m"), ordered by the mode's port name for stability.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.flashlight) == 'table'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local fl = apiData.flashlight
	if type(fl) ~= 'table' then
		return {}
	end

	-- Collect the named modes and order them by port_name (light_1, light_2, …)
	-- so pairs()' undefined order doesn't shuffle the rows.
	local modes = {}
	for _, mode in pairs(fl) do
		if type(mode) == 'table' then
			table.insert(modes, mode)
		end
	end
	table.sort(modes, function(a, b)
		return tostring(a.port_name or a.name or '') < tostring(b.port_name or b.name or '')
	end)

	local items = {}
	for _, mode in ipairs(modes) do
		local label = type(mode.name) == 'string' and mode.name ~= '' and mode.name or 'Light'
		local parts = {}
		if type(mode.light_type) == 'string' and mode.light_type ~= '' then
			table.insert(parts, mode.light_type)
		end
		local radius = tonumber(mode.light_radius)
		if radius then
			table.insert(parts, format.formatNum(radius) .. ' m')
		end
		sectionBuilder.push(items, label, table.concat(parts, ', '))
	end

	return sectionBuilder.build(sectionBuilder.section({
		key = 'flashlight',
		label = 'Flashlight',
		collapsible = true,
		items = items,
	}))
end

return p
