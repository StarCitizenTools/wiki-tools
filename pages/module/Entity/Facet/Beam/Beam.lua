require('strict')

--- @module Entity/Facet/Beam
--- Tractor / towing beam stats facet. Every beam — a vehicle mount AND an FPS
--- handheld tractor beam (MaxLift) — carries its stats in the same top-level
--- `tractor_beam` block: base pull force, range, max angle, tether-break time, plus
--- a heavy-lift mode. The facet fires whenever that block is present, so the stats
--- render additively on vehicle beams (beside the Item kind's category / short-
--- description routing) and on FPS tractor-beam gadgets (beside the Gadget overview),
--- with no kind coupling.
---
--- Heavy-lift mode is vehicle-only: towing beams expose a `towing` object (Tow force),
--- tractor beams a `cargo_mode_override` (Cargo force). FPS beams carry a copied
--- global `cargo_mode_override` default (a 5,000,000 sentinel on every one, not a
--- per-item stat), so the heavy-lift row is suppressed for non-vehicle beams.
---
--- Replaces the stat rendering that used to live in the Module:Entity/Item/Beam
--- subtype (which now keeps only the vehicle short description); both read the
--- identical block, so vehicle output is unchanged.

local format = require('Module:Entity/Format')

local p = {}

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

--- Resolves the heavy-lift mode force + its display label. Vehicle beams only:
--- towing beams carry a `towing` object, tractor beams a `cargo_mode_override`.
--- Returns nil force for FPS beams (type WeaponPersonal), whose cargo_mode_override
--- is a non-per-item global default — so the row collapses.
---
--- @param apiData table
--- @param beam table
--- @return number|nil force, string label
local function heavyLift(apiData, beam)
	if apiData.type == 'TowingBeam' then
		local towing = type(beam.towing) == 'table' and beam.towing or nil
		if towing then
			return tonumber(towing.force), 'Tow force'
		end
	end
	if apiData.type == 'TractorBeam' then
		local cargo = type(beam.cargo_mode_override) == 'table' and beam.cargo_mode_override or nil
		if cargo then
			return tonumber(cargo.max_force), 'Cargo force'
		end
	end
	return nil, 'Cargo force'
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	if apiData == nil then
		return false
	end
	return type(apiData.tractor_beam) == 'table'
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
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

-- Test-only exports. Not part of the public API.
p._internal = {
	heavyLift = heavyLift,
}

return p
