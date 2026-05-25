require('strict')

--- @module Entity/Item/WeaponGun
--- WeaponGun subtype. Renders vehicle-mounted gun stats from the shared
--- `vehicle_weapon` block. The section builder is exposed so the future
--- Turret module can render an equipped gun with the identical layout
--- (turret ports carry the same `vehicle_weapon` shape as a standalone gun).

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
	pushItem(overview, 'Damage', damage.alpha_total and tostring(damage.alpha_total))
	pushItem(overview, 'DPS', damage.burst and tostring(damage.burst))
	pushItem(overview, 'Fire rate', vehicleWeapon.rpm and (tostring(vehicleWeapon.rpm) .. ' RPM'))
	pushItem(overview, 'Fire mode', #modeNames > 0 and table.concat(modeNames, ', ') or nil)
	pushItem(overview, 'Range', vehicleWeapon.range and (tostring(vehicleWeapon.range) .. ' m'))
	pushItem(overview, 'Speed', ammunition.speed and (tostring(ammunition.speed) .. ' m/s'))
	-- Ammo only for magazine-fed (ballistic) weapons; energy weapons report 0.
	-- tonumber() guards against a string value (comparing string > number throws
	-- in Lua 5.1) and keeps the row hidden for 0/nil/non-numeric capacity.
	local capacity = tonumber(vehicleWeapon.capacity)
	if capacity and capacity > 0 then
		pushItem(overview, 'Ammo', tostring(capacity))
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
	return {
		dps = damage.burst,
		alpha_damage = damage.alpha_total,
		max_range = vw.range,
		muzzle_velocity = ammunition.speed,
		fire_rate = vw.rpm,
	}
end

return p
