require('strict')

--- @module Entity/Commodity
--- Commodity kind. Backed by the /api/commodities endpoint (a substance-level
--- entity), distinct from the per-cargo-box /items records. Renders one unified
--- page per substance; the raw and refined records are merged via the enrich
--- hook (see p.enrich). Material family is curated in families.json — the API
--- has no family field.

local util = require('Module:Entity/Util')

local p = {}

--- @type string
p.parent = 'Entity/Base'

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'commodities/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- Positive identification: commodity records carry `box_sizes_scu` (the SCU
--- packaging ladder), a field neither items nor vehicles return. Safe on
--- nil / empty / malformed apiData (returns false, never throws).
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.box_sizes_scu ~= nil
end

--- Determines which of (self, counterpart) is the raw record and which is the
--- refined record. The raw record links forward via `refined_version`; the
--- refined record links back via `raw_versions`. Either may be nil (one-sided).
---
--- @param self_ table The invoked record
--- @param counterpart table|nil The linked record, if fetched
--- @return table|nil rawRecord
--- @return table|nil refinedRecord
local function resolveRoles(self_, counterpart)
	if self_.refined_version and self_.refined_version.uuid then
		return self_, counterpart -- self is raw
	end
	if self_.raw_versions and self_.raw_versions[1] and self_.raw_versions[1].uuid then
		return counterpart, self_ -- self is refined
	end
	-- No link: classify the lone record by its own mineability.
	if self_.is_mineable then
		return self_, nil
	end
	return nil, self_
end

--- Returns the counterpart UUID to fetch, or nil when one-sided.
---
--- @param apiData table
--- @return string|nil
local function counterpartUuid(apiData)
	if apiData.refined_version and apiData.refined_version.uuid then
		return apiData.refined_version.uuid
	end
	if apiData.raw_versions and apiData.raw_versions[1] and apiData.raw_versions[1].uuid then
		return apiData.raw_versions[1].uuid
	end
	return nil
end

--- Post-fetch hook (called by Module:Entity/Data on the matched kind). Fetches
--- the raw/refined counterpart via the commodities endpoint and attaches
--- normalized `_rawRecord` / `_refinedRecord` pointers (each may be nil).
--- Idempotent and cache-friendly: Apiunto HTTP-caches the counterpart fetch,
--- so repeated sibling-renderer invocations stay cheap.
---
--- @param apiData table
--- @return table apiData (mutated and returned)
function p.enrich(apiData)
	local counterpart = nil
	local cpUuid = counterpartUuid(apiData)
	if cpUuid then
		local data = util.fetchApi(p.getApiConfigs()[1], cpUuid)
		if data and data.box_sizes_scu then
			counterpart = data
		end
	end
	apiData._rawRecord, apiData._refinedRecord = resolveRoles(apiData, counterpart)
	return apiData
end

p._internal = { resolveRoles = resolveRoles }

return p
