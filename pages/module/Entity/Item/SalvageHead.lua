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
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

-- Transitional (see Module:Entity/Assembly.callHook): hooks take an EntityHookContext.
p.contextHooks = true

--- @param ctx EntityHookContext
--- @return table[] Ordered list of section entries with key field
function p.getSections(ctx)
	local apiData = ctx.apiData
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end

	local range = tonumber(vw.range)
	if range == nil then
		return {}
	end

	local items = {}
	sectionBuilder.push(items, 'Range', format.formatNum(range) .. ' m')
	return sectionBuilder.build(sectionBuilder.section({
		key = 'salvage',
		label = 'Salvage',
		items = items,
	}))
end

--- Short description prepends the mount size — "S2 salvage head by Greycat" —
--- mirroring the other component descriptors.
---
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local apiData, args, typeInfo, prefix = ctx.apiData, ctx.args, ctx.typeInfo, ctx.prefix
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData = ctx.apiData
	local vw = apiData.vehicle_weapon
	if type(vw) ~= 'table' then
		return {}
	end
	-- The shared salvage_* properties are emitted by the Salvage facet; the head
	-- contributes only the beam range.
	return { beam_range = tonumber(vw.range) }
end

return p
