require('strict')

--- @module Entity/Base
--- Root type module. Provides properties common to all entity types:
--- name, UUID, and manufacturer.

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
	}
end

return p
