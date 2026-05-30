require('strict')

--- @module Entity/Item/WeaponPersonal
--- WeaponPersonal subtype.

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local personal_weapon = apiData.personal_weapon

	local personal_weapon_items = {}
	local performance_items = {}
	local modes = {}

	if personal_weapon then
		if personal_weapon.type then
			table.insert(personal_weapon_items, {
				label = 'Type',
				content = tostring(personal_weapon.type),
			})
		end

		if personal_weapon.damage then
			if personal_weapon.damage.dps_total then
				table.insert(personal_weapon_items, {
					label = 'DPS',
					content = tostring(personal_weapon.damage.dps_total),
				})
			end
			if personal_weapon.damage.alpha_total then
				table.insert(personal_weapon_items, {
					label = 'Alpha damage',
					content = tostring(personal_weapon.damage.alpha_total),
				})
			end
		end

		if personal_weapon.ammunition then
			local ammunition = personal_weapon.ammunition
			if ammunition.speed then
				table.insert(personal_weapon_items, {
					label = 'Muzzle velocity',
					content = tostring(ammunition.speed) .. ' m/s',
				})
			end
			if ammunition.capacity then
				table.insert(personal_weapon_items, {
					label = 'Ammo',
					content = tostring(ammunition.capacity),
				})
			end

			if ammunition.damage_drop_min_distance then
				if ammunition.damage_drop_min_distance.total then
					table.insert(performance_items, {
						label = 'Max range',
						content = tostring(ammunition.range) .. ' m',
					})
				end
			end
			if ammunition.damage_drop_min_distance then
				if ammunition.damage_drop_min_distance.total then
					table.insert(performance_items, {
						label = 'Damage falloff distance',
						content = tostring(ammunition.damage_drop_min_distance.total) .. ' m',
					})
				end
			end
			if ammunition.damage_drop_min_damage then
				if ammunition.damage_drop_min_damage.total then
					table.insert(performance_items, {
						label = 'Max damage falloff',
						content = tostring(ammunition.damage_drop_min_damage.total),
					})
				end
			end
		end

		if personal_weapon.modes then
			for _, mode in ipairs(personal_weapon.modes) do
				if mode.mode and mode.rpm and mode.pellets_per_shot and mode.ammo_per_shot then
					table.insert(modes, {
						label = mode.mode,
						columns = 3,
						items = {
							{
								label = 'Firing rate',
								content = tostring(mode.rpm) .. ' RPM',
							},
							{
								label = 'Projectile',
								content = tostring(mode.pellets_per_shot),
							},
							{
								label = 'Ammo use',
								content = tostring(mode.ammo_per_shot),
							},
						},
					})
				end
			end
		end
	end

	if #personal_weapon_items == 0 then
		return {}
	end

	return {
		{
			key = 'personal_weapon',
			label = 'Personal Weapon',
			collapsible = true,
			items = personal_weapon_items,
		},
		{
			key = 'performance',
			label = 'Performance',
			collapsible = true,
			items = performance_items,
		},
		{
			key = 'modes',
			label = 'Modes',
			collapsible = true,
			sections = modes,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	return {
		ammo = apiData.personal_weapon.ammunition.capacity,
		alpha_damage = apiData.personal_weapon.damage.alpha_total,
		dps = apiData.personal_weapon.damage.dps_total,
		falloff_distance = apiData.personal_weapon.ammunition.damage_drop_min_distance.total,
		falloff_damage = apiData.personal_weapon.ammunition.damage_drop_min_damage.total,
		max_range = apiData.personal_weapon.ammunition.damage_drop_min_damage.total,
		muzzle_velocity = apiData.personal_weapon.ammunition.speed,
	}
end

return p
