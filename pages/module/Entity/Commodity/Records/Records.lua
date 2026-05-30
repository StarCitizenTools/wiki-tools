require('strict')

--- @module Entity/Commodity/Records
--- Record-assembly for the Commodity kind. A commodity substance is rendered
--- from up to three linked API records: its raw/refined counterpart (fetched
--- via the commodities endpoint) and, for edible commodities, a linked
--- Harvestable item that carries the `food` object. enrich() fetches those and
--- attaches normalized `_rawRecord` / `_refinedRecord` pointers. Split out of
--- Module:Entity/Commodity so the kind module keeps only its contract + hooks.

local api = require('Module:Entity/Api')

local p = {}

-- Config for fetching a linked harvestable item's full record (the commodity
-- `items` relation only returns stubs). The `food` object is on the plain item
-- record, so no `include` is needed here.
local HARVESTABLE_ITEM_CONFIG = {
	name = 'StarCitizenWikiAPI',
	endpoint = 'items/%s',
	params = { locale = 'en_EN' },
	responseDataPath = 'data',
}

--- Finds the uuid of the first linked item with `sub_type == 'Harvestable'` in
--- the commodity's `items` relation (populated by include=items). That item's
--- record carries the `food` object for edible commodities. Returns nil when
--- there is no items list or no harvestable entry.
---
--- @param items table[]|nil
--- @return string|nil
local function findHarvestableUuid(items)
	if type(items) ~= 'table' then
		return nil
	end
	for _, item in ipairs(items) do
		if item.sub_type == 'Harvestable' and item.uuid then
			return item.uuid
		end
	end
	return nil
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

--- Post-fetch assembly (called by Module:Entity/Commodity.enrich on the matched
--- kind). Fetches the raw/refined counterpart via the commodities endpoint
--- (passed in as `commodityConfig` so the endpoint config stays single-sourced
--- on the kind) and attaches normalized `_rawRecord` / `_refinedRecord`
--- pointers (each may be nil). Idempotent and cache-friendly: Apiunto
--- HTTP-caches the counterpart fetch, so repeated sibling-renderer invocations
--- stay cheap.
---
--- @param apiData table
--- @param commodityConfig EntityApiConfig The commodities endpoint config
--- @return table apiData (mutated and returned)
function p.enrich(apiData, commodityConfig)
	local counterpart = nil
	local cpUuid = counterpartUuid(apiData)
	if cpUuid then
		local data = api.fetchApi(commodityConfig, cpUuid)
		if data and data.box_sizes_scu then
			counterpart = data
		end
	end
	apiData._rawRecord, apiData._refinedRecord = resolveRoles(apiData, counterpart)

	-- Edible commodities (e.g. Blue Bilva) carry no food data on the substance
	-- record; it lives on the linked Harvestable item. Attach it so the
	-- consumable facet (matches apiData.food) lights up on the commodity page.
	-- Only fetches when a Harvestable item is present, so non-edible commodities
	-- pay nothing. Reads the invoked record's `items` (not the counterpart's) —
	-- the food belongs to this substance, not its raw/refined sibling.
	if not apiData.food then
		local harvestableUuid = findHarvestableUuid(apiData.items)
		if harvestableUuid then
			local item = api.fetchApi(HARVESTABLE_ITEM_CONFIG, harvestableUuid)
			if item and item.food then
				apiData.food = item.food
			end
		end
	end

	return apiData
end

p._internal = {
	resolveRoles = resolveRoles,
	counterpartUuid = counterpartUuid,
	findHarvestableUuid = findHarvestableUuid,
}

return p
