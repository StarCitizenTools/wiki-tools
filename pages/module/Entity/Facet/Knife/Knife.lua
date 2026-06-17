require('strict')

--- @module Entity/Facet/Knife
--- Knife / melee facet. FPS melee weapons (sub_type Knife) carry a
--- `melee_weapon` / `knife` block (the two are identical) instead of a
--- `personal_weapon` block: a pair of attack modes (BladeSlash / BladeStab)
--- plus melee capability flags. Renders a Melee section; lights up data-driven
--- whenever the block is present, so it also covers any future melee weapon.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- The melee block, preferring `melee_weapon` and falling back to the identical
--- `knife`. Returns nil when neither is a table.
---
--- @param apiData table|nil
--- @return table|nil
local function block(apiData)
	if type(apiData) ~= 'table' then
		return nil
	end
	local b = apiData.melee_weapon
	if type(b) ~= 'table' then
		b = apiData.knife
	end
	return type(b) == 'table' and b or nil
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return block(apiData) ~= nil
end

--- Damage of the attack mode whose `category` matches (e.g. "BladeSlash"),
--- or nil when absent.
---
--- @param b table
--- @param category string
--- @return number|nil
local function modeDamage(b, category)
	if type(b.attack_modes) ~= 'table' then
		return nil
	end
	for _, m in ipairs(b.attack_modes) do
		if m.category == category then
			return tonumber(m.damage)
		end
	end
	return nil
end

--- Maps the API's 1/0 (or boolean) capability flag to Yes/No, or nil.
---
--- @param v any
--- @return string|nil
local function yesNo(v)
	if v == true or v == 1 then
		return 'Yes'
	end
	if v == false or v == 0 then
		return 'No'
	end
	return nil
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local b = block(apiData)
	if not b then
		return {}
	end

	local items = {}

	-- Slash and stab usually match; collapse to one Damage row when they do.
	local slash = modeDamage(b, 'BladeSlash')
	local stab = modeDamage(b, 'BladeStab')
	if slash ~= nil and slash == stab then
		sectionBuilder.push(items, 'Damage', format.formatNum(slash))
	else
		sectionBuilder.push(items, 'Slash damage', format.formatNum(slash))
		sectionBuilder.push(items, 'Stab damage', format.formatNum(stab))
	end
	sectionBuilder.push(items, 'Takedown', yesNo(b.can_be_used_for_take_down))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'melee', label = 'Melee', collapsible = true, items = items })
	)
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local b = block(apiData)
	if not b then
		return {}
	end
	return {
		slash_damage = modeDamage(b, 'BladeSlash'),
		stab_damage = modeDamage(b, 'BladeStab'),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	block = block,
	modeDamage = modeDamage,
	yesNo = yesNo,
}

return p
