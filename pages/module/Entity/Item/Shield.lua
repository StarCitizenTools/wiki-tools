require('strict')

--- @module Entity/Item/Shield
--- Shield generator subtype. Projects the vehicle's shield bubble. The Component
--- facet renders the generator hardware's shared stats (health, EM / IR,
--- resistance) off the durability block; this adds the shield-performance rows:
--- shield HP, regeneration rate, and the regen delays. The shield's
--- per-damage-type absorption / resistance (min/max ranges) is intentionally
--- deferred — it needs richer formatting and would otherwise collide with the
--- Component facet's hardware "Resistance" row.

local format = require('Module:Entity/Format')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local shield = apiData.shield
	if type(shield) ~= 'table' then
		return {}
	end

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	-- regen_delay carries the pause before the shield starts recharging:
	-- `damage` after any hit, `downed` (longer) after a full depletion.
	local delay = type(shield.regen_delay) == 'table' and shield.regen_delay or {}

	push('Shield HP', shield.max_health and format.formatNum(shield.max_health))
	push('Regeneration', shield.regen_rate and (format.formatNum(shield.regen_rate) .. ' HP/s'))
	push('Regen delay', delay.damage and (format.formatNum(delay.damage) .. ' s'))
	push('Downed delay', delay.downed and (format.formatNum(delay.downed) .. ' s'))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'shield',
			label = 'Shield',
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local shield = apiData.shield
	if type(shield) ~= 'table' then
		return {}
	end
	local delay = type(shield.regen_delay) == 'table' and shield.regen_delay or {}
	return {
		shield_health = tonumber(shield.max_health),
		shield_regeneration = tonumber(shield.regen_rate),
		shield_regen_delay = tonumber(delay.damage),
	}
end

return p
