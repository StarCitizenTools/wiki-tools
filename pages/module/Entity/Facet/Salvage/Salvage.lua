require('strict')

--- @module Entity/Facet/Salvage
--- Salvage facet. Any entity carrying a Salvage mode (`mode.type == 'Salvage'`)
--- gets the salvage stat set surfaced: material efficiency, repair (extraction)
--- rates, the health-to-ammo ratio, ramp times, and the vehicle-damage /
--- repaired-material ratios. The Salvage mode appears with an identical shape in
--- BOTH a vehicle salvage head's `vehicle_weapon.modes` (mode = "Beam") and an
--- FPS salvage tool's `personal_weapon.modes` (mode = "Salvage"), so this one
--- data-driven facet covers both populations — replacing the duplicated lookup
--- that used to live in Module:Entity/Item/SalvageHead and the Gadget facet.
---
--- On a salvage head the SalvageHead subtype contributes the beam Range under the
--- same `salvage` section key, so the chain's Range row renders first and this
--- facet's stats append below it (chain sections precede facets in the merge).

local format = require('Module:Entity/Format')

local p = {}

--- Formats a plain numeric stat, returning nil when absent so the row collapses.
---
--- @param value number|string|nil
--- @param suffix string|nil  appended after the number (e.g. " m")
--- @return string|nil
local function formatStat(value, suffix)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(n) .. (suffix or '')
end

--- Formats a 0-1 ratio as a percentage ("0.9" -> "90%"). Returns nil when absent.
---
--- @param value number|string|nil
--- @return string|nil
local function percent(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(math.floor(n * 1000 + 0.5) / 10) .. '%'
end

--- Finds the Salvage mode in a weapon's modes array. Matches on `type ==
--- 'Salvage'`, which covers both the salvage head's vehicle_weapon Beam mode
--- (mode = "Beam", type = "Salvage") and the FPS salvage tool's personal_weapon
--- mode (mode = "Salvage", type = "Salvage").
---
--- @param modes table|nil
--- @return table|nil
local function findSalvageMode(modes)
	if type(modes) ~= 'table' then
		return nil
	end
	for _, mode in ipairs(modes) do
		if mode.type == 'Salvage' then
			return mode
		end
	end
	return nil
end

--- The Salvage mode on this entity, scanning whichever weapon block is present
--- (vehicle salvage heads vs FPS salvage tools). Top-level blocks only — a salvage
--- beam is a standalone item, never a locked weapon embedded under ports.
---
--- @param apiData table|nil
--- @return table|nil
local function salvageModeOf(apiData)
	if type(apiData) ~= 'table' then
		return nil
	end
	local vw = apiData.vehicle_weapon
	if type(vw) == 'table' then
		local mode = findSalvageMode(vw.modes)
		if mode then
			return mode
		end
	end
	local pw = apiData.personal_weapon
	if type(pw) == 'table' then
		local mode = findSalvageMode(pw.modes)
		if mode then
			return mode
		end
	end
	return nil
end

--- The ordered Salvage-mode stat rows ({ label, content }): material efficiency,
--- repair (extraction) rates, the health-to-ammo ratio, ramp times, and the
--- vehicle-damage / repaired-material ratios. Returns an empty list when the mode
--- is absent or carries no displayable stats.
---
--- @param mode table|nil
--- @return EntityItemData[]
local function salvageItems(mode)
	local items = {}
	if type(mode) ~= 'table' then
		return items
	end
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Material efficiency', percent(mode.material_efficiency))
	push('Health repair rate', formatStat(mode.max_health_repair_rate))
	push('Damage repair rate', formatStat(mode.max_damage_map_repair_rate))
	push('Health-to-ammo ratio', formatStat(mode.health_to_ammo_ratio))

	local rampUp = tonumber(mode.ramp_up_time)
	local rampDown = tonumber(mode.ramp_down_time)
	if rampUp and rampDown then
		push('Ramp up / down', format.formatNum(rampUp) .. ' s / ' .. format.formatNum(rampDown) .. ' s')
	else
		push('Ramp up', formatStat(mode.ramp_up_time, ' s'))
		push('Ramp down', formatStat(mode.ramp_down_time, ' s'))
	end

	push('Max vehicle damage', percent(mode.max_vehicle_damage_ratio))
	push('Repaired material', percent(mode.repaired_material_ratio))
	return items
end

--- Data-driven match: presence of a Salvage mode in either weapon block.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return salvageModeOf(apiData) ~= nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local items = salvageItems(salvageModeOf(apiData))
	if #items == 0 then
		return {}
	end
	return {
		{
			key = 'salvage',
			label = 'Salvage',
			collapsible = true,
			items = items,
		},
	}
end

--- Structured data for the Salvage mode. Property names are shared across every
--- salvage population (vehicle heads + FPS tools) so they query alike.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local mode = salvageModeOf(apiData)
	if type(mode) ~= 'table' then
		return {}
	end
	local efficiency = tonumber(mode.material_efficiency)
	return {
		material_efficiency = efficiency and (math.floor(efficiency * 1000 + 0.5) / 10) or nil,
		health_repair_rate = tonumber(mode.max_health_repair_rate),
		damage_repair_rate = tonumber(mode.max_damage_map_repair_rate),
		ramp_up_time = tonumber(mode.ramp_up_time),
		ramp_down_time = tonumber(mode.ramp_down_time),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatStat = formatStat,
	percent = percent,
	findSalvageMode = findSalvageMode,
	salvageModeOf = salvageModeOf,
	salvageItems = salvageItems,
}

return p
