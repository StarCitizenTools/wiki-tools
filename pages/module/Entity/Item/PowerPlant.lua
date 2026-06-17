require('strict')

--- @module Entity/Item/PowerPlant
--- Power plant subtype. Power plants generate the vehicle's power; in the
--- current resource-network model the API exposes only the segment generation
--- rate (`power_output` is null game-wide for now). Common component stats
--- (health, EM / IR, resistance) come from the Component facet; this adds the
--- power-specific row(s).

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local pp = apiData.power_plant
	if type(pp) ~= 'table' then
		return {}
	end

	local items = {}
	-- power_output is null game-wide in the current model; rendered only if it
	-- ever returns, so the row appears automatically when CIG repopulates it.
	sectionBuilder.pushNonNil(items, 'Power output', format.formatNum(pp.power_output))
	sectionBuilder.pushNonNil(items, 'Power', format.formatNum(pp.power_segment_generation))

	return sectionBuilder.build(sectionBuilder.section({
		key = 'power_plant',
		label = 'Power plant',
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local pp = apiData.power_plant
	if type(pp) ~= 'table' then
		return {}
	end
	return {
		power_output = tonumber(pp.power_output),
		power_generation = tonumber(pp.power_segment_generation),
	}
end

return p
