require('strict')

--- @module Entity/Item
--- Item type module. Extends Base with item-specific properties
--- (size, mass, volume) and the shared item API endpoint.

local p = {}

--- @type string
p.parent = 'Entity/Base'

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'items/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local dim = apiData.dimension
	local trueDim = dim and dim.true_dimension

	local dimensionContent = nil
	if trueDim then
		dimensionContent = tostring(trueDim.length)
			.. ' x '
			.. tostring(trueDim.width)
			.. ' x '
			.. tostring(trueDim.height)
			.. ' m'
	end

	return {
		{
			key = 'general',
			items = {
				{ label = 'Size', content = apiData.size and tostring(apiData.size) },
				{
					label = 'Volume',
					content = dim
						and dim.volume_converted
						and (tostring(dim.volume_converted) .. ' ' .. (dim.volume_converted_unit or 'SCU')),
				},
				{
					label = 'Mass',
					content = apiData.mass and (tostring(apiData.mass) .. ' kg'),
				},
				{ label = 'Dimension', content = dimensionContent },
			},
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	return {
		size = apiData.size,
		mass = apiData.mass,
		volume = apiData.volume,
	}
end

return p
