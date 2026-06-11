require('strict')

--- @module Entity/Item/WeaponGun
--- WeaponGun subtype. Renders vehicle-mounted gun stats from the shared
--- `vehicle_weapon` block. The section builder is exposed so the future
--- Turret module can render an equipped gun with the identical layout
--- (turret ports carry the same `vehicle_weapon` shape as a standalone gun).

local format = require('Module:Entity/Format')
local CLASSES = mw.loadJsonData('Module:Entity/Item/WeaponGun/weaponClasses.json')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Appends a label/content item to a list only when content is non-nil.
--- Mirrors the nil-collapsing the other subtype modules rely on, but lets
--- callers pass a pre-formatted string or nil in one expression.
---
--- @param items EntityItemData[]
--- @param label string
--- @param content string|nil
local function pushItem(items, label, content)
	if content ~= nil then
		table.insert(items, { label = label, content = content })
	end
end

--- The type segment of an RSI class_name, lowercased: the underscore-part after
--- the manufacturer prefix. "KBAR_BallisticCannon_S2" -> "ballisticcannon",
--- "BEHR_DistortionRepeater_VNG_S2" -> "distortionrepeater". nil when absent.
---
--- @param className string|nil
--- @return string|nil
local function classTypeSegment(className)
	if type(className) ~= 'string' then
		return nil
	end
	local seg = className:match('^[^_]+_([^_]+)')
	return seg and seg:lower() or nil
end

--- Damage type: prefer the clean class_name segment (prefix match, space-stripped
--- so "Mass Driver" matches "MassDriver..."); fall back to the label's leading
--- token. Returns the canonical curated value, or nil when nothing matches.
--- Intentionally a leading-prefix match (never mid-string), unlike findMechanism's
--- substring match, so "Size 2 Ballistic Cannon" never falsely triggers a damage hit.
---
--- @param apiData table
--- @return string|nil
local function resolveDamageType(apiData)
	local seg = classTypeSegment(apiData.class_name)
	if seg then
		for _, dt in ipairs(CLASSES.damageTypes) do
			local key = dt:gsub('%s+', ''):lower()
			if seg:sub(1, #key) == key then
				return dt
			end
		end
	end
	local label = apiData.vehicle_weapon and apiData.vehicle_weapon.type
	if type(label) == 'string' then
		local low = label:lower()
		for _, dt in ipairs(CLASSES.damageTypes) do
			if low:sub(1, #dt) == dt:lower() then
				return dt
			end
		end
	end
	return nil
end

--- Finds a curated firing mechanism in a string via case-folded substring match.
--- Handles spaced labels ("Ballistic Cannon"), CamelCase class_name segments
--- ("plasmacannon"), junk suffixes ("ballistic gatling (x2)"), and the
--- "Canon"->"Cannon" alias. Returns the canonical mechanism, or nil.
---
--- @param text string|nil
--- @return string|nil
local function findMechanism(text)
	if type(text) ~= 'string' then
		return nil
	end
	local low = text:lower()
	for _, m in ipairs(CLASSES.mechanisms) do
		if low:find(m:lower(), 1, true) then
			return m
		end
	end
	for alias, canonical in pairs(CLASSES.aliases) do
		if low:find(alias:lower(), 1, true) then
			return canonical
		end
	end
	return nil
end

--- Firing mechanism: the player-facing label is the authority (class_name's
--- mechanism is unreliable — VNCL laser repeaters are internally "LaserCannon").
--- Falls back to class_name only when the label yields nothing (gap guns).
---
--- @param apiData table
--- @return string|nil
local function resolveFiringType(apiData)
	local label = apiData.vehicle_weapon and apiData.vehicle_weapon.type
	return findMechanism(label) or findMechanism(apiData.class_name)
end

--- Parses a vehicle gun's blended type into two independent facets. Each axis is
--- nil when no curated value matches (Rocket Pod, blanks, unknown). item_type is
--- still stored verbatim by Item regardless, so nothing is lost.
---
--- @param apiData table|nil
--- @return { damage_type: string|nil, firing_type: string|nil }
local function parseWeaponClass(apiData)
	if type(apiData) ~= 'table' then
		return {}
	end
	return {
		damage_type = resolveDamageType(apiData),
		firing_type = resolveFiringType(apiData),
	}
end

--- Builds infobox sections for a vehicle weapon's `vehicle_weapon` block.
--- Reusable across a standalone WeaponGun (`apiData.vehicle_weapon`) and a
--- turret's equipped gun (`ports[].equipped_item.vehicle_weapon`). Returns
--- an empty list when the block is missing or yields no displayable rows so
--- the section list collapses cleanly.
---
--- @param vehicleWeapon table|nil
--- @return EntitySectionEntry[]
function p.getVehicleWeaponSections(vehicleWeapon)
	if type(vehicleWeapon) ~= 'table' then
		return {}
	end

	local damage = vehicleWeapon.damage or {}
	local ammunition = vehicleWeapon.ammunition or {}

	-- Fire mode names only (e.g. "Single", "Burst"); per-mode stats omitted for now.
	local modeNames = {}
	if type(vehicleWeapon.modes) == 'table' then
		for _, mode in ipairs(vehicleWeapon.modes) do
			if mode.mode then
				table.insert(modeNames, tostring(mode.mode))
			end
		end
	end

	local overview = {}
	pushItem(overview, 'Type', vehicleWeapon.type and tostring(vehicleWeapon.type))
	pushItem(overview, 'Damage', format.formatNum(damage.alpha_total))
	pushItem(overview, 'DPS', format.formatNum(damage.burst))
	pushItem(overview, 'Fire rate', vehicleWeapon.rpm and (format.formatNum(vehicleWeapon.rpm) .. ' RPM'))
	pushItem(overview, 'Fire mode', #modeNames > 0 and table.concat(modeNames, ', ') or nil)
	pushItem(overview, 'Range', vehicleWeapon.range and (format.formatNum(vehicleWeapon.range) .. ' m'))
	pushItem(overview, 'Speed', ammunition.speed and (format.formatNum(ammunition.speed) .. ' m/s'))
	-- Ammo only for magazine-fed (ballistic) weapons; energy weapons report 0.
	-- tonumber() guards against a string value (comparing string > number throws
	-- in Lua 5.1) and keeps the row hidden for 0/nil/non-numeric capacity.
	local capacity = tonumber(vehicleWeapon.capacity)
	if capacity and capacity > 0 then
		pushItem(overview, 'Ammo', format.formatNum(capacity))
	end

	if #overview == 0 then
		return {}
	end

	return {
		{
			key = 'vehicle_weapon',
			label = 'Weapon',
			collapsible = true,
			items = overview,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	return p.getVehicleWeaponSections(apiData.vehicle_weapon)
end

--- Flat structured data for the structured-data backend. Every access is
--- nil-guarded: energy weapons null out many `vehicle_weapon` fields, and
--- the block itself may be absent.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end
	local damage = vw.damage or {}
	local ammunition = vw.ammunition or {}
	local class = parseWeaponClass(apiData)
	local data = {
		dps = damage.burst,
		alpha_damage = damage.alpha_total,
		max_range = vw.range,
		muzzle_velocity = ammunition.speed,
		fire_rate = vw.rpm,
		damage_type = class.damage_type,
		firing_type = class.firing_type,
	}
	-- Ammo only for magazine-fed (ballistic) weapons; energy weapons report 0.
	local capacity = tonumber(vw.capacity)
	if capacity and capacity > 0 then
		data.ammo = capacity
	end
	return data
end

-- Test-only exports. Not part of the public API.
p._internal = {
	parseWeaponClass = parseWeaponClass,
}

return p
