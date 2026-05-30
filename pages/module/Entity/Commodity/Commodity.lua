require('strict')

--- @module Entity/Commodity
--- Commodity kind. Backed by the /api/commodities endpoint (a substance-level
--- entity), distinct from the per-cargo-box /items records. Renders one unified
--- page per substance; the raw and refined records are merged via the enrich
--- hook (record assembly lives in Module:Entity/Commodity/Records). Material
--- family is curated in families.json — the API has no family field.
--- Mining-stat formatting lives in Module:Entity/Commodity/Mining.

local format = require('Module:Entity/Format')
local mining = require('Module:Entity/Commodity/Mining')
local records = require('Module:Entity/Commodity/Records')

local p = {}

--- @type string
p.parent = 'Entity/Base'

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'commodities/%s',
			-- `items` links the substance to its in-game item records (cargo boxes
			-- and, for edible commodities, a Harvestable item that carries the
			-- `food` object). p.enrich reads it to light up the consumable facet.
			params = { locale = 'en_EN', include = 'items' },
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

--- Post-fetch hook (called by Module:Entity/Data on the matched kind). Delegates
--- record assembly to Module:Entity/Commodity/Records, passing the commodities
--- endpoint config so the counterpart fetch stays single-sourced here.
---
--- @param apiData table
--- @return table apiData (mutated and returned)
function p.enrich(apiData)
	return records.enrich(apiData, p.getApiConfigs()[1])
end

-- Public alias so sibling renderers (Module:Entity/Availability) can title the
-- Mining card with the same method-aware label the infobox uses.
p.acquisitionLabel = mining.acquisitionLabel

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
			{ label = 'Acquisition', content = mining.acquisitionLabel(raw, apiData.kind or (raw and raw.kind)) },
			{ label = 'Refinable', content = refinable ~= nil and (refinable and 'Yes' or 'No') or nil },
		},
	}

	local sections = { overview }

	if raw and raw.is_mineable then
		local items = {}
		-- Signature is a scan/detectability stat that applies to any acquisition
		-- method (ship, vehicle, FPS, harvesting), so it shows whenever present.
		if raw.signature then
			items[#items + 1] = { label = 'Signature', content = format.formatNum(raw.signature) }
		end
		-- Instability / resistance are laser-mining mechanics (ship & ground
		-- vehicle only); FPS and harvesting report them as zero / nil.
		if mining.isLaserMining(raw) then
			if raw.instability and raw.instability > 0 then
				items[#items + 1] = { label = 'Instability', content = format.formatNum(raw.instability) }
			end
			if raw.resistance and raw.resistance > 0 then
				items[#items + 1] = { label = 'Resistance', content = tostring(raw.resistance) }
			end
		end
		local quality = mining.qualityRange(raw)
		if quality then
			items[#items + 1] = { label = 'Quality', content = quality }
		end

		-- Only render the group when it has at least one stat — otherwise a
		-- stat-less acquisition (e.g. a harvestable with no signature/quality)
		-- would leave a labelled-but-empty section.
		if #items > 0 then
			local kind = raw.kind or apiData.kind
			local label = 'Mining'
			if kind == 'harvestable' then
				label = 'Harvesting'
			elseif kind == 'remains' then
				label = 'Collection'
			end
			sections[#sections + 1] = {
				key = 'mining',
				label = label,
				collapsible = true,
				items = items,
			}
		end
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
	local links = format.buildSiteLinks(siteDefs, {
		name = args.name or apiData.name,
		slug = apiData.slug,
	})
	if not links then
		return {}
	end
	return { { label = 'Community sites', content = links } }
end

return p
