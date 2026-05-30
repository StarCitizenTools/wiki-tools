require('strict')

--- @module Entity/Base
--- Root type module. Provides properties common to all entity types:
--- name, UUID, and manufacturer.

local format = require('Module:Entity/Format')
local manufacturers = require('Module:Manufacturers')

local p = {}

--- @type string|nil
p.parent = nil

--- Resolves the manufacturer for the current entity.
--- Prefers the wikitext arg (which may be a code like "AEGS" or a name);
--- falls back to API data, filtering placeholder codes.
--- Passes the chosen identifier through Module:Manufacturers to get the
--- canonical record; falls back to a self-referencing record if unknown.
---
--- @param apiData table
--- @param args table
--- @return { code: string, name: string, short: string, page: string }|nil
function p.resolveManufacturer(apiData, args)
	if args.manufacturer then
		return manufacturers.resolve(args.manufacturer)
			or {
				code = args.manufacturer,
				name = args.manufacturer,
				short = args.manufacturer,
				page = args.manufacturer,
			}
	end

	local apiMfr = apiData.manufacturer
	if
		not apiMfr
		or apiMfr.code == 'UNKN'
		or apiMfr.code == 'GENF'
		or apiMfr.code == 'GEND'
		or apiMfr.code == 'NONE'
		or apiMfr.code == 'TBD'
	then
		return nil
	end

	return manufacturers.resolve(apiMfr.code)
		or { code = apiMfr.code, name = apiMfr.name, short = apiMfr.name, page = apiMfr.name }
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local manufacturer = p.resolveManufacturer(apiData, args)
	return {
		uuid = args.uuid,
		name = args.name or apiData.name,
		manufacturer = manufacturer and manufacturer.name,
	}
end

--- @param apiData table
--- @param args table
--- @return EntityItemData[] External site items contributed by this module
function p.getExternalSiteItems(apiData, args)
	local siteDefs = mw.loadJsonData('Module:Entity/officialSites.json')
	local links = format.buildSiteLinks(siteDefs, {
		name = args.name or apiData.name,
		galactapedia_url = args.galactapedia_url,
	})
	if not links then
		return {}
	end
	return { { label = 'Official sites', content = links } }
end

return p
