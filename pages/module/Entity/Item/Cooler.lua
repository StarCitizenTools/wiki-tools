require('strict')

--- @module Entity/Item/Cooler
--- Cooler subtype. Coolers dissipate a vehicle's heat; in the current
--- resource-network model the API exposes only the coolant segment generation
--- rate (`cooling_rate` is null game-wide for now, like the power plant's
--- `power_output`). Common component stats (health, EM / IR, resistance) come
--- from the Component facet; this adds the cooling-specific row(s).

local format = require('Module:Entity/Format')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local cooler = apiData.cooler
	if type(cooler) ~= 'table' then
		return {}
	end

	local items = {}
	-- cooling_rate is null game-wide in the current model; rendered only if it
	-- ever returns, so the row appears automatically when CIG repopulates it.
	if cooler.cooling_rate ~= nil then
		table.insert(items, { label = 'Cooling rate', content = format.formatNum(cooler.cooling_rate) })
	end
	if cooler.coolant_segment_generation ~= nil then
		table.insert(items, { label = 'Cooling', content = format.formatNum(cooler.coolant_segment_generation) })
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'cooler',
			label = 'Cooler',
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local cooler = apiData.cooler
	if type(cooler) ~= 'table' then
		return {}
	end
	return {
		cooling_rate = tonumber(cooler.cooling_rate),
		coolant_generation = tonumber(cooler.coolant_segment_generation),
	}
end

return p
