require('strict')

--- @module Entity/Base
--- Root type module. Provides properties common to all entity types:
--- name, UUID, and manufacturer.

local util = require('Module:Entity/Util')

local p = {}

--- @type string|nil
p.parent = nil

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	return {
		{
			key = 'general',
			items = {},
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	return {
		uuid = args.uuid,
		name = args.name or apiData.name,
		manufacturer = apiData.manufacturer and apiData.manufacturer.name,
		galactapedia_url = args.galactapedia_url,
	}
end

--- @param apiData table
--- @param args table
--- @return EntityItemData[] External site items contributed by this module
function p.getExternalSiteItems(apiData, args)
	local siteDefs = mw.loadJsonData('Module:Entity/officialSites.json')
	local links = util.buildSiteLinks(siteDefs, {
		name = args.name or apiData.name,
		galactapedia_url = args.galactapedia_url,
	})
	if not links then
		return {}
	end
	return { { label = 'Official sites', content = links } }
end

return p
