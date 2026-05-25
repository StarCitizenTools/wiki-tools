require('strict')

--- @module Entity/Item/Turret
--- Turret subtype (PDC turrets, gimbal mounts, remote-turret bases — all
--- carry type=Turret). Renders a Turret stats section for any turret, plus
--- a Weapon section for a *locked* equipped gun (the PDC case), reusing
--- Module:Entity/Item/WeaponGun's section builder.

local util = require('Module:Entity/Util')
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

--- Humanises a PascalCase rotation style into spaced words:
--- "SingleAxis" -> "Single Axis". Returns nil for nil/empty so the row
--- collapses.
---
--- @param style string|nil
--- @return string|nil
local function humanizeRotation(style)
	if type(style) ~= 'string' or style == '' then
		return nil
	end
	return (style:gsub('(%l)(%u)', '%1 %2'))
end

--- Builds the Turret stats section from `apiData.turret`: rotation style,
--- mount count, and yaw/pitch traverse speeds (when the API reports them;
--- many turrets leave the axis speeds null). Returns nil when no row has a
--- value so the section collapses cleanly.
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
	pushItem(items, 'Rotation', humanizeRotation(turret.rotation_style))
	pushItem(items, 'Mounts', turret.mounts and util.formatNum(turret.mounts))
	pushItem(items, 'Yaw speed', yaw.speed and (util.formatNum(yaw.speed) .. ' °/s'))
	pushItem(items, 'Pitch speed', pitch.speed and (util.formatNum(pitch.speed) .. ' °/s'))

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

-- Test-only exports. Not part of the public API.
p._internal = {
	humanizeRotation = humanizeRotation,
	buildTurretSection = buildTurretSection,
	findLockedWeapon = findLockedWeapon,
}

return p
