require('strict')

--- @module Entity/Item/Beam
--- Tractor beam / towing beam subtype. Both share the `tractor_beam` block — base
--- pull force, range, max angle, and a tether-break time — plus a heavy-lift mode:
--- tractor beams expose it as `cargo_mode_override` (moving cargo), towing beams as
--- a `towing` object (towing ships). The subtype surfaces the base force, the
--- heavy-lift force (labelled Cargo / Tow by kind), range, max angle, and tether
--- break. Both carry a durability block, so the Component facet renders alongside.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Appends a label/content pair only when content is non-empty.
---
--- @param items table[]
--- @param label string
--- @param content string|nil
local function pushItem(items, label, content)
	if content ~= nil and content ~= '' then
		table.insert(items, { label = label, content = content })
	end
end

--- Resolves the heavy-lift mode force + its display label. Towing beams carry a
--- dedicated `towing` object; tractor beams carry `cargo_mode_override`. Returns
--- nil force when neither applies.
---
--- @param apiData table
--- @param beam table
--- @return number|nil force, string label
local function heavyLift(apiData, beam)
	local towing = type(beam.towing) == 'table' and beam.towing or nil
	if apiData.type == 'TowingBeam' and towing then
		return tonumber(towing.force), 'Tow force'
	end
	local cargo = type(beam.cargo_mode_override) == 'table' and beam.cargo_mode_override or nil
	if cargo then
		return tonumber(cargo.max_force), 'Cargo force'
	end
	return nil, 'Cargo force'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local beam = apiData.tractor_beam
	if type(beam) ~= 'table' then
		return {}
	end
	local force = type(beam.force) == 'table' and beam.force or {}
	local range = type(beam.range) == 'table' and beam.range or {}
	local tether = type(beam.tether) == 'table' and beam.tether or {}

	local items = {}
	pushItem(items, 'Force', force.max and format.formatNum(force.max))
	local liftForce, liftLabel = heavyLift(apiData, beam)
	pushItem(items, liftLabel, liftForce and format.formatNum(liftForce))
	pushItem(items, 'Range', range.max and (format.formatNum(range.max) .. ' m'))
	pushItem(items, 'Max angle', range.max_angle and (format.formatNum(range.max_angle) .. '°'))
	pushItem(
		items,
		'Tether break time',
		tether.tether_break_time and (format.formatNum(tether.tether_break_time) .. ' s')
	)

	if #items == 0 then
		return {}
	end

	local label = apiData.type == 'TowingBeam' and 'Towing beam' or 'Tractor beam'
	return {
		{
			key = 'tractor_beam',
			label = label,
			items = items,
		},
	}
end

--- Short description prepends the mount size — "S1 tractor beam by Greycat
--- Industrial" — mirroring the other vehicle-component descriptors.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local beam = apiData.tractor_beam
	if type(beam) ~= 'table' then
		return {}
	end
	local force = type(beam.force) == 'table' and beam.force or {}
	local range = type(beam.range) == 'table' and beam.range or {}
	local tether = type(beam.tether) == 'table' and beam.tether or {}
	local liftForce = heavyLift(apiData, beam)
	return {
		beam_force = tonumber(force.max),
		beam_mode_force = liftForce,
		beam_range = tonumber(range.max),
		beam_max_angle = tonumber(range.max_angle),
		beam_tether_break = tonumber(tether.tether_break_time),
	}
end

return p
