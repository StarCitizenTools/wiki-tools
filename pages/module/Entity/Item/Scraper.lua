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

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Appends a label/content pair only when content is non-empty.
---
--- @param items table[]
--- @param label string
--- @param content string|nil
local function pushItem(items, label, content)
	if content ~= nil and content ~= '' then
		table.insert(items, { label = label, content = content })
	end
end

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
	local speed = tonumber(s.salvage_speed_multiplier)
	if speed then
		pushItem(items, 'Salvage speed', '×' .. format.formatNum(speed))
	end
	local radius = tonumber(s.radius_multiplier)
	if radius then
		pushItem(items, 'Radius', '×' .. format.formatNum(radius))
	end
	local efficiency = tonumber(s.extraction_efficiency)
	if efficiency then
		pushItem(items, 'Extraction efficiency', format.formatNum(math.floor(efficiency * 1000 + 0.5) / 10) .. '%')
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'salvage_modifier',
			label = 'Salvage',
			items = items,
		},
	}
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
