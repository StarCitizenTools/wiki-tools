require('strict')

--- @module Entity/Item/Turret
--- Turret subtype (PDC turrets, gimbal mounts, remote-turret bases — all
--- carry type=Turret). Renders a Turret stats section for any turret, plus
--- a Weapon section for a *locked* equipped gun (the PDC case), reusing
--- Module:Entity/Item/WeaponGun's section builder.

local format = require('Module:Entity/Format')
local weaponGun = require('Module:Entity/Item/WeaponGun')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Appends a label/content item only when content is non-nil (mirrors the
--- nil-collapsing the sibling subtype modules use).
---
--- @param items EntityItemData[]
--- @param label string
--- @param content string|nil
local function pushItem(items, label, content)
	if content ~= nil then
		table.insert(items, { label = label, content = content })
	end
end

--- Builds the Turret stats section from `apiData.turret`: mount count and
--- yaw/pitch traverse speeds (when the API reports them; many turrets leave
--- the axis speeds null). Returns nil when no row has a value so the section
--- collapses cleanly. `rotation_style` is intentionally not surfaced — the
--- value (always "SingleAxis" in observed data) doesn't correspond to whether
--- a turret has one or two functional axes.
---
--- @param turret table|nil
--- @return EntitySectionEntry|nil
local function buildTurretSection(turret)
	if type(turret) ~= 'table' then
		return nil
	end
	local yaw = type(turret.yaw_axis) == 'table' and turret.yaw_axis or {}
	local pitch = type(turret.pitch_axis) == 'table' and turret.pitch_axis or {}

	local items = {}
	pushItem(items, 'Mounts', turret.mounts and format.formatNum(turret.mounts))
	pushItem(items, 'Yaw speed', yaw.speed and (format.formatNum(yaw.speed) .. ' °/s'))
	pushItem(items, 'Pitch speed', pitch.speed and (format.formatNum(pitch.speed) .. ' °/s'))

	if #items == 0 then
		return nil
	end
	return {
		key = 'turret',
		label = 'Turret',
		collapsible = true,
		items = items,
	}
end

--- Returns the `vehicle_weapon` of the first locked gun port — a port that
--- is not editable (`editable == false`) whose equipped item carries a
--- `vehicle_weapon` block. This is the "comes with a weapon" case (PDC
--- turrets ship a fixed gun); swappable or empty mounts return nil.
---
--- @param apiData table
--- @return table|nil
local function findLockedWeapon(apiData)
	local ports = apiData.ports
	if type(ports) ~= 'table' then
		return nil
	end
	for _, port in ipairs(ports) do
		if port.editable == false and type(port.equipped_item) == 'table' then
			local vw = port.equipped_item.vehicle_weapon
			if type(vw) == 'table' then
				return vw
			end
		end
	end
	return nil
end

--- Contributes the Turret section and, when the turret ships a locked gun,
--- the Weapon section (rendered by the shared WeaponGun builder). The
--- Entity chain appends these after Item's General section.
---
--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local sections = {}
	local turretSection = buildTurretSection(apiData.turret)
	if turretSection then
		table.insert(sections, turretSection)
	end
	local lockedWeapon = findLockedWeapon(apiData)
	if lockedWeapon then
		for _, section in ipairs(weaponGun.getVehicleWeaponSections(lockedWeapon)) do
			table.insert(sections, section)
		end
	end
	return sections
end

--- Contributes turret-specific structured-data facets: yaw and pitch traverse
--- speeds in degrees per second. Honest reads of the outer entity only — we
--- intentionally don't fall back to ports[].equipped_item for housings
--- (TMSB-5, Anvil ball/nose turrets, PDCs) where the API leaves the outer
--- speeds null and the real values live on the inner equipped gimbal mount.
--- Falling back would conflate two entities' data on one page; partial
--- coverage is more honest. Standalone gimbal mounts (VariPuck etc.) populate
--- these directly.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local turret = apiData.turret
	local yawAxis = type(turret) == 'table' and turret.yaw_axis or nil
	local pitchAxis = type(turret) == 'table' and turret.pitch_axis or nil
	return {
		yaw_speed = type(yawAxis) == 'table' and yawAxis.speed or nil,
		pitch_speed = type(pitchAxis) == 'table' and pitchAxis.speed or nil,
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	buildTurretSection = buildTurretSection,
	findLockedWeapon = findLockedWeapon,
}

return p
