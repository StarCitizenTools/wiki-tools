require('strict')

--- @module Entity/Vehicle
--- Vehicle type module. Barebones for now — exposes the vehicles API
--- endpoint so sibling renderers (Availability, Description, etc.) can
--- consume vehicle data through the standard Module:Entity/Data path.
--- Full vehicle infobox treatment (sections, structured data) lands
--- later; this is the minimum needed to route vehicle UUIDs.

local p = {}

--- @type string
p.parent = 'Entity/Base'

--- The vehicles endpoint includes uex_prices and msrp by default, so
--- no `include` param is required for Availability to render.
---
--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'vehicles/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- Positive identification: vehicles set `is_vehicle = true` at the
--- top level of the API response. Items don't have this field.
--- Safe on nil / empty / malformed apiData (returns false, never throws).
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.is_vehicle == true
end

return p
