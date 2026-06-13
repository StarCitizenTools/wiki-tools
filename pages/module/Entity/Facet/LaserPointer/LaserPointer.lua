require('strict')

--- @module Entity/Facet/LaserPointer
--- Laser-pointer facet. An underbarrel laser sight carries a top-level
--- `laser_pointer` block; surfaces its effective range. (Colour is present in the
--- block but usually null and needs a swatch to be meaningful, so it is left for
--- a later pass.)

local format = require('Module:Entity/Format')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.laser_pointer) == 'table'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local lp = apiData.laser_pointer
	if type(lp) ~= 'table' then
		return {}
	end
	local range = tonumber(lp.range)
	if range == nil then
		return {}
	end
	return {
		{
			key = 'laser_pointer',
			label = 'Laser pointer',
			collapsible = true,
			items = { { label = 'Range', content = format.formatNum(range) .. ' m' } },
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local lp = apiData.laser_pointer
	if type(lp) ~= 'table' then
		return {}
	end
	return { laser_range = tonumber(lp.range) }
end

return p
