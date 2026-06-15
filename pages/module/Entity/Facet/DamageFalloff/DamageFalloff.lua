require('strict')

--- @module Entity/Facet/DamageFalloff
--- Damage-falloff facet. Renders a weapon's damage-over-distance curve as an inline
--- FalloffChart at the bottom of the Weapon section. Data-driven: fires only when a
--- weapon block (personal_weapon or vehicle_weapon) carries a meaningful in-range
--- falloff — a positive per-metre drop that begins within the projectile's range and
--- ends above a lower floor. Flat weapons (laser) and weapons whose falloff begins
--- beyond their range do not fire, so the block is skipped. Vehicle-ready: ship guns
--- currently expose no falloff data, so the facet is dormant for them until the API
--- provides it.

local format = require('Module:Entity/Format')
local falloffChart = require('Module:FalloffChart')

local p = {}

local DAMAGE_TYPES = { 'physical', 'energy', 'thermal', 'distortion', 'biochemical', 'stun' }

-- Fixed per-class x-axis maxima (m), keyed by personal_weapon.type, so charts are
-- comparable within a weapon class. Each fits the typical class members (from a
-- catalogue-wide falloff survey); a rare long-tail weapon is drawn to the scale and
-- clipped with a "→" marker. Unknown / future classes fall back to the weapon's own
-- adaptive domain, so the facet degrades gracefully.
local CLASS_SCALE = {
	['SMG'] = 100,
	['Assault Rifle'] = 150,
	['Pistol'] = 200,
	['LMG'] = 400,
	['Sniper Rifle'] = 600,
	['Shotgun'] = 600,
}

--- A distance label, rounded to a whole metre, with digit grouping.
--- @param n number
--- @return string
local function metres(n)
	return format.formatNum(math.floor(n + 0.5)) .. ' m'
end

--- A damage label: up to one decimal, trailing ".0" stripped ("91.4", "12").
--- @param n number
--- @return string
local function dmg(n)
	local s = string.format('%.1f', n)
	return (s:gsub('%.0$', ''))
end

--- Reads a `damage_drop_*` field that may be a flat number or a per-type object,
--- preferring the object's `total`, else the value for `primaryType`.
--- @param field any
--- @param primaryType string|nil
--- @return number|nil
local function dropValue(field, primaryType)
	if type(field) == 'number' then
		return field
	end
	if type(field) == 'table' then
		if type(field.total) == 'number' then
			return field.total
		end
		if primaryType and type(field[primaryType]) == 'number' then
			return field[primaryType]
		end
	end
	return nil
end

--- The damage sub-type carrying the most alpha (e.g. "physical"), used to resolve
--- per-type damage_drop objects that lack a `total`. nil when there is no breakdown.
--- @param damage table|nil
--- @return string|nil
local function primaryDamageType(damage)
	if type(damage) ~= 'table' or type(damage.alpha) ~= 'table' then
		return nil
	end
	local best, bestVal = nil, 0
	for _, t in ipairs(DAMAGE_TYPES) do
		local v = tonumber(damage.alpha[t])
		if v and v > bestVal then
			best, bestVal = t, v
		end
	end
	return best
end

--- The weapon block on an entity (personal first, then vehicle), and the section
--- key the chart should merge into.
--- @param apiData table
--- @return table|nil block
--- @return string|nil key
local function weaponBlock(apiData)
	if type(apiData.personal_weapon) == 'table' then
		return apiData.personal_weapon, 'personal_weapon'
	end
	if type(apiData.vehicle_weapon) == 'table' then
		return apiData.vehicle_weapon, 'vehicle_weapon'
	end
	return nil, nil
end

--- Normalizes a weapon block to a falloff model, or nil when the data is absent.
--- @param block table|nil
--- @return table|nil { alpha, minDist, perMeter, minDamage, range }
local function resolveFalloff(block)
	if type(block) ~= 'table' then
		return nil
	end
	local damage = block.damage or {}
	local ammo = block.ammunition or {}
	local alpha = tonumber(damage.alpha_total)
	local range = tonumber(ammo.range)
	if alpha == nil or range == nil then
		return nil
	end
	local primary = primaryDamageType(damage)
	local minDist = dropValue(ammo.damage_drop_min_distance, primary)
	local perMeter = dropValue(ammo.damage_drop_per_meter, primary)
	local minDamage = dropValue(ammo.damage_drop_min_damage, primary)
	if minDist == nil or perMeter == nil or minDamage == nil then
		return nil
	end
	return {
		alpha = alpha,
		minDist = minDist,
		perMeter = perMeter,
		minDamage = minDamage,
		range = range,
	}
end

--- Falloff is meaningful only when it both exists and begins within range.
--- @param m table|nil
--- @return boolean
local function hasMeaningfulFalloff(m)
	return m ~= nil and m.perMeter > 0 and m.alpha > m.minDamage and m.minDist < m.range
end

--- @param m table
--- @return number
local function floorDistance(m)
	return m.minDist + (m.alpha - m.minDamage) / m.perMeter
end

--- @param m table
--- @param d number
--- @return number
local function damageAt(m, d)
	if d <= m.minDist then
		return m.alpha
	end
	local value = m.alpha - (d - m.minDist) * m.perMeter
	if value < m.minDamage then
		return m.minDamage
	end
	return value
end

--- Chart x extent: to the floor distance with headroom (to show the plateau) when
--- the floor is reached within range; otherwise clamped to range.
--- @param m table
--- @return number
local function adaptiveDomain(m)
	local fd = floorDistance(m)
	if fd <= m.range then
		return fd * 1.25
	end
	return m.range
end

--- The weapon's class (personal_weapon.type), used to look up the fixed scale.
--- @param apiData table
--- @return string|nil
local function weaponType(apiData)
	local block = weaponBlock(apiData)
	if type(block) == 'table' and type(block.type) == 'string' then
		return block.type
	end
	return nil
end

--- The chart's fixed x extent: the weapon class's shared scale (so charts are
--- comparable within a class), or the weapon's own adaptive domain when the class
--- has no fixed scale.
--- @param apiData table
--- @param m table
--- @return number
local function chartDomain(apiData, m)
	return CLASS_SCALE[weaponType(apiData)] or adaptiveDomain(m)
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	if apiData == nil then
		return false
	end
	return hasMeaningfulFalloff(resolveFalloff((weaponBlock(apiData))))
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local block, key = weaponBlock(apiData)
	local m = resolveFalloff(block)
	if not hasMeaningfulFalloff(m) then
		return {}
	end

	local domain = chartDomain(apiData, m)
	local fd = floorDistance(m)
	-- Draw only to where the projectile actually reaches; the fixed class scale may
	-- extend past a short-range weapon (leaving honest dead space on the right).
	local drawEnd = math.min(domain, m.range)
	local floorInView = fd <= drawEnd
	-- Curve still descending where the fixed scale cuts it off, with the projectile
	-- reaching at least that far: show a "→" clip marker.
	local clipped = m.range >= domain and fd > domain
	-- Lowest damage the weapon actually deals: the floor if reached within range,
	-- else the damage at maximum range.
	local headerEnd = (fd <= m.range) and m.minDamage or damageAt(m, m.range)

	local points = { { x = 0, y = m.alpha } }
	if m.minDist <= drawEnd then
		table.insert(points, { x = m.minDist, y = m.alpha })
	end
	if floorInView then
		table.insert(points, { x = fd, y = m.minDamage })
	end
	table.insert(points, { x = drawEnd, y = damageAt(m, drawEnd) })

	local markers = {}
	if m.minDist <= drawEnd then
		table.insert(markers, { at = m.minDist, label = metres(m.minDist) })
	end
	if floorInView then
		table.insert(markers, { at = fd, label = 'floor ' .. metres(fd) })
	end

	local caption
	if floorInView then
		caption = 'Full &#8804; ' .. metres(m.minDist) .. ' &#183; floor ' .. dmg(m.minDamage) .. ' at ' .. metres(fd)
	elseif fd <= m.range then
		-- Floor reached, but beyond the fixed scale (off the right edge).
		caption = 'Full &#8804; '
			.. metres(m.minDist)
			.. ' &#183; &#8594; floor '
			.. dmg(m.minDamage)
			.. ' at '
			.. metres(fd)
	else
		-- Projectile dies before the floor is reached.
		caption = 'Full &#8804; '
			.. metres(m.minDist)
			.. ' &#183; '
			.. dmg(damageAt(m, m.range))
			.. ' at '
			.. metres(m.range)
			.. ' (floor not reached)'
	end

	local chart = falloffChart.render({
		points = points,
		domain = domain,
		yMax = m.alpha,
		label = 'Damage falloff',
		value = dmg(m.alpha) .. ' &#8594; ' .. dmg(headerEnd),
		markers = markers,
		floor = floorInView and m.minDamage or nil,
		axisMin = '0 m',
		axisMax = metres(domain) .. (clipped and ' &#8594;' or ''),
		caption = caption,
		-- Model for the optional client-side hover gadget (Gadget-falloffChart).
		dataset = {
			['falloff-alpha'] = m.alpha,
			['falloff-min-dist'] = m.minDist,
			['falloff-per-meter'] = m.perMeter,
			['falloff-min-damage'] = m.minDamage,
			['falloff-domain'] = domain,
			['falloff-range'] = m.range,
		},
	})

	if chart == nil then
		return {}
	end

	return {
		{ key = key, items = { { content = chart, class = 't-infobox-item--block' } } },
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local m = resolveFalloff((weaponBlock(apiData)))
	if not hasMeaningfulFalloff(m) then
		return {}
	end
	return {
		full_damage_range = m.minDist,
		min_damage = m.minDamage,
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolveFalloff = resolveFalloff,
	hasMeaningfulFalloff = hasMeaningfulFalloff,
	floorDistance = floorDistance,
	damageAt = damageAt,
	adaptiveDomain = adaptiveDomain,
	chartDomain = chartDomain,
	weaponType = weaponType,
	primaryDamageType = primaryDamageType,
	dropValue = dropValue,
}

return p
