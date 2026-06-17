require('strict')

--- @module Entity/Item/Scraper
--- Scraper module subtype (API type "SalvageModifier"). A scraper module slots
--- into a salvage beam and trades salvage speed for area, altering the beam's
--- behaviour. Renders the `salvage_modifier` block: the salvage-speed and radius
--- multipliers and the extraction efficiency. Scraper modules carry a durability
--- block, so the Component facet renders; the tractor-flavoured SalvageModifier
--- (ReadyGrip) carries neutral multipliers and no durability — both render here.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local s = apiData.salvage_modifier
	if type(s) ~= 'table' then
		return {}
	end

	local items = {}

	-- salvage_speed_multiplier and radius_multiplier are baseline multipliers
	-- (×1 = unchanged); extraction_efficiency is a 0-1 fraction shown as a percent.
	-- Both multipliers are higher-is-better (faster salvage / bigger radius), so
	-- colour green above ×1, red below; a neutral ×1 (ReadyGrip) renders uncoloured.
	local speed = tonumber(s.salvage_speed_multiplier)
	if speed then
		sectionBuilder.push(
			items,
			'Salvage speed',
			format.colorByDirection('×' .. format.formatNum(speed), speed, 1, 'higher')
		)
	end
	local radius = tonumber(s.radius_multiplier)
	if radius then
		sectionBuilder.push(
			items,
			'Radius',
			format.colorByDirection('×' .. format.formatNum(radius), radius, 1, 'higher')
		)
	end
	local efficiency = tonumber(s.extraction_efficiency)
	if efficiency then
		sectionBuilder.push(
			items,
			'Extraction efficiency',
			format.formatNum(math.floor(efficiency * 1000 + 0.5) / 10) .. '%'
		)
	end

	return sectionBuilder.build(sectionBuilder.section({
		key = 'salvage_modifier',
		label = 'Salvage',
		items = items,
	}))
end

--- Short description prepends the mount size — "S1 scraper module by Greycat" —
--- mirroring the other component descriptors.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local s = apiData.salvage_modifier
	if type(s) ~= 'table' then
		return {}
	end
	local efficiency = tonumber(s.extraction_efficiency)
	return {
		salvage_speed_multiplier = tonumber(s.salvage_speed_multiplier),
		radius_multiplier = tonumber(s.radius_multiplier),
		extraction_efficiency = efficiency and (math.floor(efficiency * 1000 + 0.5) / 10) or nil,
	}
end

return p
