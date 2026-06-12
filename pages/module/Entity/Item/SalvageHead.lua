require('strict')

--- @module Entity/Item/SalvageHead
--- Salvage beam subtype (API type "SalvageHead"). The salvage head is the
--- vehicle-mounted beam that strips material from hulls; its stats live in the
--- `vehicle_weapon` object's Salvage (Beam) mode rather than a dedicated block.
--- Renders the beam range plus the full Salvage-mode stat set: material
--- efficiency, repair (extraction) rates, the health-to-ammo ratio, ramp times,
--- and the vehicle-damage / repaired-material ratios. Heads carry durability, so
--- the Component facet renders.
---
--- NOTE: the FPS salvage tool (API type WeaponPersonal, sub_type Gadget) carries
--- the SAME Salvage mode shape under `personal_weapon.modes`. `findSalvageMode`
--- matches on `type == 'Salvage'`, so it would work there too; if/when the FPS
--- salvage tool is surfaced, lift `findSalvageMode` + the mode rows into a shared
--- helper both can require. Not done now (single consumer — YAGNI).

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
--- 'Salvage'`, which covers the salvage head's vehicle_weapon Beam mode
--- (mode="Beam", type="Salvage") and the FPS salvage tool's personal_weapon
--- mode (mode="Salvage", type="Salvage").
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

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end

	local items = {}
	pushItem(items, 'Range', formatStat(vw.range, ' m'))

	local mode = findSalvageMode(vw.modes)
	if mode then
		pushItem(items, 'Material efficiency', percent(mode.material_efficiency))
		pushItem(items, 'Health repair rate', formatStat(mode.max_health_repair_rate))
		pushItem(items, 'Damage repair rate', formatStat(mode.max_damage_map_repair_rate))
		pushItem(items, 'Health-to-ammo ratio', formatStat(mode.health_to_ammo_ratio))

		local rampUp = tonumber(mode.ramp_up_time)
		local rampDown = tonumber(mode.ramp_down_time)
		if rampUp and rampDown then
			pushItem(items, 'Ramp up / down', format.formatNum(rampUp) .. ' s / ' .. format.formatNum(rampDown) .. ' s')
		else
			pushItem(items, 'Ramp up', formatStat(mode.ramp_up_time, ' s'))
			pushItem(items, 'Ramp down', formatStat(mode.ramp_down_time, ' s'))
		end

		pushItem(items, 'Max vehicle damage', percent(mode.max_vehicle_damage_ratio))
		pushItem(items, 'Repaired material', percent(mode.repaired_material_ratio))
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'salvage',
			label = 'Salvage',
			items = items,
		},
	}
end

--- Short description prepends the mount size — "S2 salvage head by Greycat" —
--- mirroring the other component descriptors.
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
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end
	local data = { beam_range = tonumber(vw.range) }

	local mode = findSalvageMode(vw.modes)
	if mode then
		local efficiency = tonumber(mode.material_efficiency)
		data.material_efficiency = efficiency and (math.floor(efficiency * 1000 + 0.5) / 10) or nil
		data.health_repair_rate = tonumber(mode.max_health_repair_rate)
		data.damage_repair_rate = tonumber(mode.max_damage_map_repair_rate)
		data.ramp_up_time = tonumber(mode.ramp_up_time)
		data.ramp_down_time = tonumber(mode.ramp_down_time)
	end

	return data
end

return p
