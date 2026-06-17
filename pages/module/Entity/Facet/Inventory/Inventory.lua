require('strict')

--- @module Entity/Facet/Inventory
--- Inventory facet. An item carrying an `inventory` block with a usable capacity
--- (storage garments — torso armor, jackets, backpacks — and, later, containers)
--- gets its carrying capacity surfaced. Data-driven: fires on any entity with an
--- `inventory` block, regardless of kind.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- The storage capacity in microSCU. The API exposes both `scu` (SCU as a
--- fraction) and `scu_converted` (the precision-preserving µSCU integer the
--- display uses, e.g. 10500 for a 0.0105 SCU torso); read the latter. Returns nil
--- when absent or non-positive, so an empty inventory block collapses the section.
---
--- @param inventory table|nil
--- @return number|nil
local function capacityMicroScu(inventory)
	if type(inventory) ~= 'table' then
		return nil
	end
	local scu = tonumber(inventory.scu_converted)
	if scu == nil or scu <= 0 then
		return nil
	end
	return scu
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and capacityMicroScu(apiData.inventory) ~= nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local capacity = capacityMicroScu(apiData.inventory)
	if capacity == nil then
		return {}
	end

	local items = {}
	sectionBuilder.push(items, 'Storage capacity', format.formatNum(capacity) .. ' µSCU')
	return sectionBuilder.build(sectionBuilder.section({
		key = 'inventory',
		label = 'Storage',
		collapsible = true,
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local capacity = capacityMicroScu(apiData.inventory)
	if capacity == nil then
		return {}
	end
	return { storage_capacity = capacity }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	capacityMicroScu = capacityMicroScu,
}

return p
