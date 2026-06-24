require('strict')

--- @module Entity/Facet/Component
--- Component facet. Cross-cutting stats shared by every vehicle component (and
--- any item carrying a `durability` block): health, EM / IR signature,
--- distortion resilience, and per-damage-type resistance. Type-specific stats (a
--- quantum drive's speed, a shield's HP, a power plant's generation) live in the
--- owning subtype; this facet renders the common physics so subtypes stay small.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local statFormat = require('Module:Entity/StatFormat')
local Util = require('Module:Entity/Facet/Util')

local p = {}

-- Damage types shown in the resistance row, in a stable order. Components are
-- usually 1.0 (no resistance) for distortion / biochemical / stun, so the row
-- only lists the types that actually resist.
local RESIST_ORDER = Util.damageKeys()
local RESIST_LABEL = Util.damageLabels()

--- Data-driven match: presence of the `durability` block (the component health /
--- resistance payload). Nil-safe, strict boolean.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.durability) == 'table'
end

--- The API resistance values are "damage taken" multipliers (1.0 = full damage,
--- 0.1 = takes 10%, i.e. 90% resistant). Render the reduction (1 - factor) as a
--- percentage, listing only the types that resist (factor < 1). Returns nil when
--- nothing resists, so the row collapses.
---
--- @param resistance table|nil
--- @return string|nil
local function formatResistance(resistance)
	if type(resistance) ~= 'table' then
		return nil
	end
	local parts = {}
	for _, key in ipairs(RESIST_ORDER) do
		local factor = tonumber(resistance[key])
		if factor and factor < 1 then
			local pct = statFormat.resistancePercent(factor)
			table.insert(parts, RESIST_LABEL[key] .. ' ' .. pct .. '%')
		end
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ' · ')
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local durability = apiData.durability or {}
	local emission = apiData.emission or {}
	local distortion = apiData.distortion or {}

	local items = {}
	sectionBuilder.push(items, 'Health', durability.health and format.formatNum(durability.health))
	sectionBuilder.push(items, 'EM signature', emission.em_max and format.formatNum(emission.em_max))
	sectionBuilder.push(items, 'IR signature', emission.ir and format.formatNum(emission.ir))
	sectionBuilder.push(items, 'Distortion', distortion.max and format.formatNum(distortion.max))
	sectionBuilder.push(items, 'Resistance', formatResistance(durability.resistance))

	return sectionBuilder.build(sectionBuilder.section({
		key = 'component',
		label = 'Component',
		collapsible = true,
		collapsed = true,
		items = items,
	}))
end

--- Common component facets for structured data / browse: health, EM and IR
--- signature, and distortion resilience (scalars). Per-type resistance is left
--- out of the query layer for now (multi-valued; a sub-table later).
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local durability = apiData.durability or {}
	local emission = apiData.emission or {}
	local distortion = apiData.distortion or {}
	return {
		health = tonumber(durability.health),
		em_signature = tonumber(emission.em_max),
		ir_signature = tonumber(emission.ir),
		distortion = tonumber(distortion.max),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatResistance = formatResistance,
}

return p
