require('strict')

--- @module Entity/Facet/Medical
--- Medical facet. A medical consumable (injector pen — type FPS_Consumable,
--- sub_type Medical/MedPack) carries a `medical` block describing the dose it
--- delivers: the blood drug level it raises, plus the combat buffs and impact
--- resistances the drug confers while active. Data-driven: fires on any entity
--- with a `medical` block, regardless of kind. (OxygenCap consumables like OxyPen
--- carry a `food` block instead, so the Consumable facet handles those.)

local format = require('Module:Entity/Format')

local p = {}

-- Friendlier labels for the effect keys; falls back to title-case.
local EFFECT_LABELS = {
	a_d_s_enter = 'Aim-down-sights',
	stun_recovery = 'Stun recovery',
	move_speed = 'Movement speed',
	weapon_sway = 'Weapon sway',
	atrophic = 'Atrophy',
}

--- Title-cases a snake_case key: "stun_recovery" -> "Stun recovery".
---
--- @param key string
--- @return string
local function titleCase(key)
	local s = key:gsub('_', ' ')
	return s:sub(1, 1):upper() .. s:sub(2)
end

--- Collects the active effect keys as a sorted, comma-joined label list.
--- Handles both API shapes: a boolean flag map (combat_buffs /
--- impact_resistances — {stun_recovery=true,…}) and the magnitude map the
--- debuffs field uses ({atrophic=900}). A key counts as active unless its
--- value is explicitly false, so flag and magnitude maps both work; an empty
--- array ([]) yields nothing. Returns nil when no key is active.
---
--- @param effects table|nil
--- @return string|nil
local function effectList(effects)
	if type(effects) ~= 'table' then
		return nil
	end
	local labels = {}
	for k, v in pairs(effects) do
		if v ~= false and type(k) == 'string' then
			table.insert(labels, EFFECT_LABELS[k] or titleCase(k))
		end
	end
	if #labels == 0 then
		return nil
	end
	table.sort(labels)
	return table.concat(labels, ', ')
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.medical) == 'table'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local m = apiData.medical
	if type(m) ~= 'table' then
		return {}
	end
	local nutrition = type(m.nutrition) == 'table' and m.nutrition or {}

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	local bdl = tonumber(nutrition.blood_drug_level)
	if bdl ~= nil then
		push('Blood drug level', format.formatNum(bdl))
	end
	push('Combat buffs', effectList(m.combat_buffs))
	push('Impact resistances', effectList(m.impact_resistances))
	push('Debuffs', effectList(m.debuffs))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'medical',
			label = 'Medical',
			collapsible = true,
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local m = apiData.medical
	if type(m) ~= 'table' then
		return {}
	end
	local nutrition = type(m.nutrition) == 'table' and m.nutrition or {}
	return { blood_drug_level = tonumber(nutrition.blood_drug_level) }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	effectList = effectList,
	titleCase = titleCase,
}

return p
