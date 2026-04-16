require('strict')

--- @module Entity/Item
--- Item type module. Extends Base with item-specific properties
--- (size, mass, volume) and the shared item API endpoint.

local util = require('Module:Entity/Util')

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
				{
					label = 'Manufacturer',
					content = args.manufacturer
						or (
							apiData.manufacturer
							and apiData.manufacturer.code ~= 'UNKN'
							and apiData.manufacturer.code ~= 'GENF'
							and apiData.manufacturer.code ~= 'GEND'
							and apiData.manufacturer.name
						),
				},
				{ label = 'Size', content = apiData.size and tostring(apiData.size) },
				{
					label = 'Craftable',
					content = apiData.is_craftable ~= nil and (apiData.is_craftable and 'Yes' or 'No') or nil,
				},
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

--- @param apiData table
--- @param args table
--- @return EntityItemData[] External site items contributed by this module
function p.getExternalSiteItems(apiData, args)
	local siteDefs = mw.loadJsonData('Module:Entity/Item/communitySites.json')
	local links = util.buildSiteLinks(siteDefs, {
		uuid = args.uuid,
		name = args.name or apiData.name,
	})
	if not links then
		return {}
	end
	return { { label = 'Community sites', content = links } }
end

return p
