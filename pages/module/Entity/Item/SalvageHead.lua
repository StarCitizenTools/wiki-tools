require('strict')

--- @module Entity/Item/SalvageHead
--- Salvage beam subtype (API type "SalvageHead"). The salvage head is the
--- vehicle-mounted beam that strips material from hulls. The subtype contributes
--- only the beam Range here; the Salvage-mode stat set (material efficiency,
--- repair rates, ramp times, etc.) is rendered by the data-driven Salvage facet
--- (Module:Entity/Facet/Salvage), which fires on any entity carrying a Salvage
--- mode — heads and FPS salvage tools alike. Range and the facet's stats share
--- the `salvage` section key, so this Range row renders first and the facet's
--- rows append below it (chain sections precede facets in the merge). Heads carry
--- durability, so the Component facet renders alongside.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end

	local range = tonumber(vw.range)
	if range == nil then
		return {}
	end

	return {
		{
			key = 'salvage',
			label = 'Salvage',
			items = { { label = 'Range', content = format.formatNum(range) .. ' m' } },
		},
	}
end

--- Short description prepends the mount size — "S2 salvage head by Greycat" —
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
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end
	-- The shared salvage_* properties are emitted by the Salvage facet; the head
	-- contributes only the beam range.
	return { beam_range = tonumber(vw.range) }
end

return p
