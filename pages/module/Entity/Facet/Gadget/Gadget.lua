require('strict')

--- @module Entity/Facet/Gadget
--- Gadget facet (WeaponPersonal sub_type "Gadget"): multi-tools, handheld
--- salvage tools, tractor beams, fire extinguishers, rangefinders. Their stats
--- live in the shared `personal_weapon` block, but the gun "Weapon" section is
--- meaningless for a utility tool — so WeaponPersonal suppresses it for gadgets
--- and this facet renders the utility overview (type / range / capacity) instead.
---
--- Per-mode behaviour is owned by data-driven facets that match on the mode
--- itself, not on the Gadget sub_type: a Salvage mode renders via the Salvage
--- facet, a healing-beam mode via the Heal facet, and optical zoom via the
--- WeaponModifier facet. Stat-less modes (tractor toggle, rangefinder single) add
--- nothing.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.sub_type == 'Gadget'
end

--- @param value any
--- @param unit string
--- @return string|nil
local function withUnit(value, unit)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(n) .. unit
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local pw = apiData.personal_weapon
	if type(pw) ~= 'table' then
		return {}
	end
	local ammunition = type(pw.ammunition) == 'table' and pw.ammunition or {}

	local overview = {}
	sectionBuilder.push(overview, 'Type', type(pw.type) == 'string' and pw.type ~= '' and pw.type or nil)
	-- `range` (the API's non-deprecated field; `effective_range` is deprecated).
	-- Skip it when a tractor_beam block is present: the Beam facet renders the
	-- authoritative beam range, so the gadget overview would just duplicate it.
	if type(apiData.tractor_beam) ~= 'table' then
		sectionBuilder.push(overview, 'Range', withUnit(pw.range, ' m'))
	end
	local capacity = tonumber(ammunition.capacity)
	if capacity and capacity > 0 then
		sectionBuilder.push(overview, 'Capacity', format.formatNum(capacity))
	end

	return sectionBuilder.build(sectionBuilder.section({
		key = 'gadget',
		label = 'Gadget',
		collapsible = true,
		items = overview,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local pw = apiData.personal_weapon
	if type(pw) ~= 'table' then
		return {}
	end
	local data = {}
	local range = tonumber(pw.range)
	if range then
		data.max_range = range
	end
	return data
end

return p
