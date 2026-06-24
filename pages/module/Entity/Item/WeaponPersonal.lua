require('strict')

--- @module Entity/Item/WeaponPersonal
--- WeaponPersonal subtype. Renders FPS personal-weapon stats from the
--- `personal_weapon` block — ranged guns (pistols, rifles, shotguns, snipers,
--- LMGs, railguns, launchers) plus the medical/utility devices that share the
--- block. The weapon *class* (Pistol / Assault Rifle / ...) lives only in the
--- free-text `personal_weapon.type` field; classification and sub_type carry
--- just the size bucket (Small / Medium / Large), so the class is stored as a
--- `weapon_class` facet to drive the per-class filtered index tables.
---
--- Knives (`melee_weapon` / `knife`), grenades (`grenade`) and gadgets (utility
--- tools sharing the `personal_weapon` block) are other WeaponPersonal sub_types;
--- their stats render via the Knife / Grenade / Gadget facets, and `getTypeInfo`
--- routes each to its own browse category. This subtype renders only the gun
--- "Weapon" section, collapsing for all of those.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')
local Util = require('Module:Entity/Facet/Util')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Appends a label/content item to a list only when content is non-nil — the
--- nil-collapsing every subtype relies on so absent stats drop their row.
---
--- @param items EntityItemData[]
--- @param label string
--- @param content string|nil
local function pushItem(items, label, content)
	if content ~= nil then
		table.insert(items, { label = label, content = content })
	end
end

--- Per-mode fire stats as one display string: "<rpm> RPM" plus a pellet count
--- for multi-projectile modes (shotguns) and an ammo-per-shot multiplier when
--- a shot burns more than one round. Returns nil when the mode carries no rate
--- (utility modes like Salvage/Heal have no rpm) so it drops from the list.
---
--- @param mode table
--- @return string|nil
local function formatMode(mode)
	local rpm = tonumber(mode.rpm)
	if rpm == nil then
		return nil
	end
	local parts = { format.formatNum(rpm) .. ' RPM' }
	local pellets = tonumber(mode.pellets_per_shot)
	if pellets and pellets > 1 then
		table.insert(parts, format.formatNum(pellets) .. ' pellets')
	end
	local ammoPerShot = tonumber(mode.ammo_per_shot)
	if ammoPerShot and ammoPerShot > 1 then
		table.insert(parts, format.formatNum(ammoPerShot) .. '× ammo/shot')
	end
	return table.concat(parts, ', ')
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	-- Gadgets share the personal_weapon block but the gun "Weapon" section is
	-- meaningless for a utility tool — they render via the Gadget facet instead.
	if apiData.sub_type == 'Gadget' then
		return {}
	end
	local pw = apiData.personal_weapon
	if type(pw) ~= 'table' then
		return {}
	end

	local damage = pw.damage or {}
	local ammunition = pw.ammunition or {}

	local overview = {}
	pushItem(overview, 'Type', type(pw.type) == 'string' and pw.type ~= '' and pw.type or nil)
	pushItem(overview, 'Class', type(pw.class) == 'string' and pw.class ~= '' and pw.class or nil)
	-- Rows below are weapon STATS; Type/Class above are mere descriptors. A stub
	-- personal_weapon block (grenades carry one with only a `type`) yields zero
	-- stat rows, so the Weapon section is suppressed and the sub_type's facet
	-- (Grenade) renders instead.
	local statStart = #overview
	pushItem(overview, 'Damage', format.formatNum(damage.alpha_total))
	pushItem(overview, 'DPS', format.formatNum(damage.dps_total))
	-- Ammo capacity only for magazine-fed weapons; energy/charge weapons and
	-- gadgets report 0 or null.
	local capacity = tonumber(ammunition.capacity)
	if capacity and capacity > 0 then
		pushItem(overview, 'Ammo', format.formatNum(capacity))
	end
	pushItem(overview, 'Muzzle velocity', Util.withUnit(ammunition.speed, ' m/s'))
	-- Range from the API's `range` field (its `effective_range` is deprecated). A
	-- single Range row; the damage-falloff chart carries the over-distance story.
	local range = tonumber(pw.range)
	pushItem(overview, 'Range', range and Util.withUnit(range, ' m'))
	local statCount = #overview - statStart

	local modeItems = {}
	if type(pw.modes) == 'table' then
		for _, mode in ipairs(pw.modes) do
			if mode.mode then
				pushItem(modeItems, tostring(mode.mode), formatMode(mode))
			end
		end
	end

	local sections = {}
	if statCount > 0 then
		table.insert(sections, {
			key = 'personal_weapon',
			label = 'Weapon',
			collapsible = true,
			items = overview,
		})
	end
	if #modeItems > 0 then
		table.insert(sections, {
			key = 'fire_modes',
			label = 'Fire modes',
			collapsible = true,
			items = modeItems,
		})
	end
	return sections
end

--- Short description: "S<size> <class> by <manufacturer>" — the player-facing
--- weapon class (e.g. "S2 assault rifle by Klaus & Werner"), lower-cased and
--- size-prefixed. Falls back to the family type name ("Personal weapon") when
--- the block omits a class. Size is dropped only when the API has none.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local pw = apiData.personal_weapon
	local typeName = typeInfo.name
	if type(pw) == 'table' and type(pw.type) == 'string' and pw.type ~= '' then
		typeName = pw.type:lower()
	end
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- Display metadata. Personal weapons all share the API `type` "WeaponPersonal",
--- so the structural browse category is resolved from the `sub_type`: knives and
--- grenades get their own buckets, while the ranged-gun sizes (Small/Medium/Large)
--- and anything else fall through (return nil) to the type map's "Personal weapons"
--- umbrella. Data.get prefers this leaf hook over the classification resolver
--- (which ignores FPS.* paths).
---
--- @param apiData table
--- @param args table
--- @return table|nil { name, category }
function p.getTypeInfo(apiData, args)
	local sub = apiData and apiData.sub_type
	if sub == 'Knife' then
		return { name = 'Knife', category = 'Knives' }
	end
	if sub == 'Grenade' then
		return { name = 'Grenade', category = 'Grenades' }
	end
	if sub == 'Gadget' then
		return { name = 'Gadget', category = 'Gadgets' }
	end
	return nil
end

--- Flat structured data for the query backend. Every access is nil-guarded:
--- the block is absent on knives/grenades, and gadgets/medical devices null
--- out damage and ammo. `weapon_class` is the facet the per-class index tables
--- filter on; `damage_class` (Ballistic / Energy) is a secondary facet.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local pw = apiData.personal_weapon
	if type(pw) ~= 'table' then
		return {}
	end
	local damage = pw.damage or {}
	local ammunition = pw.ammunition or {}
	local data = {
		weapon_class = type(pw.type) == 'string' and pw.type ~= '' and pw.type or nil,
		damage_class = type(pw.class) == 'string' and pw.class ~= '' and pw.class or nil,
		damage = damage.alpha_total,
		dps = damage.dps_total,
		muzzle_velocity = ammunition.speed,
		max_range = tonumber(pw.range),
	}
	local capacity = tonumber(ammunition.capacity)
	if capacity and capacity > 0 then
		data.ammo = capacity
	end
	return data
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatMode = formatMode,
}

return p
