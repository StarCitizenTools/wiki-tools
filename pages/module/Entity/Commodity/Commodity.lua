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

local KIND_LABELS = { mineable = 'mining', harvestable = 'harvesting', salvage = 'salvage' }

--- "Ship mining" / "FPS harvesting" / "Salvage" from kind + methods.
--- @param raw table|nil
--- @param kind string|nil
--- @return string|nil
local function acquisitionLabel(raw, kind)
	if not kind or kind == 'remains' then
		return nil
	end
	local verb = KIND_LABELS[kind] or kind
	local methods = raw and raw.methods
	if methods and methods[1] then
		return methods[1] .. ' ' .. verb -- e.g. "Ship mining"
	end
	return verb:gsub('^%l', string.upper)
end

--- Min/max quality across the raw record's locations, as "min–max".
--- @param raw table|nil
--- @return string|nil
local function qualityRange(raw)
	local locs = raw and raw.locations
	if type(locs) ~= 'table' or not locs[1] then
		return nil
	end
	local lo, hi
	for _, l in ipairs(locs) do
		if l.quality_min and (not lo or l.quality_min < lo) then
			lo = l.quality_min
		end
		if l.quality_max and (not hi or l.quality_max > hi) then
			hi = l.quality_max
		end
	end
	if not lo or not hi then
		return nil
	end
	return tostring(lo) .. '–' .. tostring(hi)
end

p._internal = { resolveRoles = resolveRoles, acquisitionLabel = acquisitionLabel, qualityRange = qualityRange }

--- Resolves display metadata (subtitle name + browse category) from the
--- curated family map. The commodities API exposes no type/classification,
--- so this leaf hook (preferred by Module:Entity/Data over resolveType)
--- supplies it. Returns nil for unmapped/junk keys so the subtitle and
--- category collapse out.
---
--- @param apiData table
--- @return table|nil { name, category }
function p.getTypeInfo(apiData)
	local map = mw.loadJsonData('Module:Entity/Commodity/families.json')
	local family = apiData.key and map[apiData.key]
	if type(family) ~= 'string' then
		return nil
	end
	local categories = map['%categories'] or {}
	return { name = family, category = categories[family] or family }
end

--- @param apiData table
--- @param args table
--- @return table[]
function p.getSections(apiData, args)
	local raw = apiData._rawRecord
	local refined = apiData._refinedRecord or apiData
	local typeInfo = p.getTypeInfo(apiData, args)

	local tier = apiData.tier or (raw and raw.tier)
	local refinable = (apiData.refined_version and apiData.refined_version.uuid)
		or (refined and refined.raw_versions and refined.raw_versions[1])

	-- `systems` is intentionally NOT an infobox row: the set of star systems
	-- grows as the game expands, so an enumerated list doesn't scale. The
	-- per-system Deposit-locations tables are the scalable home for "where",
	-- and `systems` is still persisted to structured data for querying.
	local overview = {
		key = 'overview',
		items = {
			{ label = 'Family', content = typeInfo and typeInfo.name },
			{ label = 'Rarity', content = tier and (tier:gsub('^%l', string.upper)) },
			{ label = 'Acquisition', content = acquisitionLabel(raw, apiData.kind or (raw and raw.kind)) },
			{ label = 'Refinable', content = refinable ~= nil and (refinable and 'Yes' or 'No') or nil },
		},
	}

	local sections = { overview }

	if raw and raw.is_mineable then
		sections[#sections + 1] = {
			key = 'mining',
			label = 'Mining',
			collapsible = true,
			items = {
				{ label = 'Signature', content = util.formatNum(raw.signature) },
				{ label = 'Instability', content = raw.instability and util.formatNum(raw.instability) },
				{ label = 'Resistance', content = raw.resistance and tostring(raw.resistance) },
				{ label = 'Quality', content = qualityRange(raw) },
			},
		}
	end

	return sections
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local raw = apiData._rawRecord
	local typeInfo = p.getTypeInfo(apiData, args)
	return {
		family = typeInfo and typeInfo.name,
		tier = apiData.tier or (raw and raw.tier),
		mineable = (raw and raw.is_mineable) or false,
		acquisition_kind = apiData.kind or (raw and raw.kind),
		density = raw and raw.density_g_per_cc,
		signature = raw and raw.signature,
		systems = (raw and raw.systems) or apiData.systems,
	}
end

--- "<Tier> <kind> <family>", any component optional. e.g. "Uncommon mineable mineral".
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @return string
function p.getShortDescription(apiData, args, typeInfo)
	local parts = {}
	local tier = apiData.tier or (apiData._rawRecord and apiData._rawRecord.tier)
	if tier then
		parts[#parts + 1] = tier:gsub('^%l', string.upper)
	end
	local kind = apiData.kind or (apiData._rawRecord and apiData._rawRecord.kind)
	if kind and kind ~= 'remains' then
		parts[#parts + 1] = kind
	end
	parts[#parts + 1] = (typeInfo and typeInfo.name and typeInfo.name:lower()) or 'commodity'
	local desc = table.concat(parts, ' ')
	return desc:gsub('^%l', string.upper)
end

--- Contributes commodity community-site links (UEX, SC Trade Tools) to the
--- infobox External sites section, mirroring Module:Entity/Item. Keyed on the
--- commodity `slug` (url-safe; both sites resolve commodities by slug).
---
--- @param apiData table
--- @param args table
--- @return EntityItemData[]
function p.getExternalSiteItems(apiData, args)
	local siteDefs = mw.loadJsonData('Module:Entity/Commodity/communitySites.json')
	local links = util.buildSiteLinks(siteDefs, {
		name = args.name or apiData.name,
		slug = apiData.slug,
	})
	if not links then
		return {}
	end
	return { { label = 'Community sites', content = links } }
end

return p
