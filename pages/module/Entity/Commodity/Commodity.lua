require('strict')

--- @module Entity/Commodity
--- Commodity kind. Backed by the /api/commodities endpoint (a substance-level
--- entity), distinct from the per-cargo-box /items records. Renders one unified
--- page per substance; the raw and refined records are merged via the enrich
--- hook (record assembly lives in Module:Entity/Commodity/Records).
--- Type/group come from the API `commodity_groups` taxonomy (parent + finest
--- leaf); see the LABELS / CATEGORIES maps below.
--- Mining-stat formatting lives in Module:Entity/Commodity/Mining.

local format = require('Module:Entity/Format')
local mining = require('Module:Entity/Commodity/Mining')
local records = require('Module:Entity/Commodity/Records')
local acq = require('Module:Entity/Acquisition')

-- API commodity_groups token → singular display label. Drives the infobox Type
-- row, the short description, and the stored Commodity group / Commodity type
-- SMW values (so the Data table facets read in plain English).
local LABELS = {
	ProcessedGoods = 'Processed goods',
	Vice = 'Vice',
	SyntheticMaterials = 'Synthetic materials',
	Bulk_Supplies = 'Bulk supplies',
	Metal = 'Metal',
	Alloy = 'Alloy',
	UnrefinedOres = 'Unrefined ores',
	Organic = 'Organic',
	Food = 'Food',
	Mineral = 'Mineral',
	Raw_Minerals = 'Raw minerals',
	Gas = 'Gas',
	Nonmetal = 'Non-metal',
	Halogen = 'Halogen',
	Waste = 'Waste',
}

-- Parent (first commodity_groups element) → group category page name. A parent
-- absent here is a placeholder / unknown (HeatPlaceholder, PowerPlaceholder,
-- LifeSupportPlaceholder, CleanAir) → no group, no category. Doubles as the
-- valid-parent allowlist.
local CATEGORIES = {
	ProcessedGoods = 'Processed goods',
	Metal = 'Metals',
	Organic = 'Organic commodities',
	Mineral = 'Minerals',
	Gas = 'Gases',
	Nonmetal = 'Non-metals',
	Waste = 'Waste',
}

--- Parses apiData.commodity_groups (ordered parent→child; last = finest type)
--- into its parent + leaf tokens. Returns nil when the array is absent/empty or
--- the parent is a placeholder/unknown (not in CATEGORIES), so unmapped
--- commodities collapse cleanly (no Type row, no group, no group category).
---
--- @param apiData table
--- @return { parent: string, leaf: string }|nil
local function resolveGroups(apiData)
	local groups = apiData.commodity_groups
	if type(groups) ~= 'table' or groups[1] == nil then
		return nil
	end
	local parent = groups[1]
	if CATEGORIES[parent] == nil then
		return nil
	end
	return { parent = parent, leaf = groups[#groups] }
end

local p = {}

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on. Every kind declares one (enforced by the Registry conformance test).
p.name = 'Commodity'

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

--- Resolves display metadata from the API commodity_groups taxonomy. `name` is
--- the finest type (leaf) label → infobox subtitle + Type row. `category` is the
--- parent group category (Metals, …). `categories` carries the extra Commodities
--- membership so the index Data table can query every commodity in one category
--- (Module:Entity/Categories honours typeInfo.categories). Returns nil for
--- placeholder/unmapped parents so the subtitle and categories collapse out.
---
--- @param apiData table
--- @return table|nil { name, category, categories }
function p.getTypeInfo(apiData)
	local g = resolveGroups(apiData)
	if not g then
		return nil
	end
	return {
		name = LABELS[g.leaf],
		category = CATEGORIES[g.parent],
		categories = { 'Commodities' },
	}
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
			{ label = 'Type', content = typeInfo and typeInfo.name },
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
	local g = resolveGroups(apiData)
	return {
		commodity_group = g and LABELS[g.parent] or nil,
		commodity_type = g and LABELS[g.leaf] or nil,
		tier = apiData.tier or (raw and raw.tier),
		mineable = (raw and raw.is_mineable) or false,
		acquisition_kind = apiData.kind or (raw and raw.kind),
		density = raw and raw.density_g_per_cc,
		signature = raw and raw.signature,
		-- `systems` is intentionally NOT an infobox row: the set of star systems
		-- grows as the game expands, so an enumerated list doesn't scale. It is
		-- persisted to structured data for querying.
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

--- Acquisition data for {{Entity/Availability}}: Mine/Harvest/Buy summary flags
--- and a Mining deposit card (pre-rendered HTML) + a Trade card (UEX terminal
--- table when priced, else a SC-Trade-Tools/UEX link-out keyed on slug).
---
--- @param apiData table
--- @param args table
--- @return { summary: table[], cards: table[] }
function p.getAcquisition(apiData, args)
	local raw = apiData._rawRecord or apiData
	local refined = apiData._refinedRecord or apiData
	local purchase = type(refined.uex_prices) == 'table' and refined.uex_prices.purchase or nil

	local summary = {
		{ label = 'Mine', icon = '⛏️', value = acq.resolveFlag(args.canMine, raw.is_mineable) },
		{ label = 'Harvest', icon = '🌿', value = acq.resolveFlag(args.canHarvest, raw.has_harvestables) },
		{
			label = 'Buy',
			icon = '🛒',
			value = acq.resolveFlag(args.canBuy, acq.inferCanAcquire(purchase, 'price_buy')),
		},
	}

	local cards = {}
	local miningHtml = mining.renderMiningCard(apiData._rawRecord)
	if miningHtml then
		cards[#cards + 1] = { type = 'html', html = miningHtml }
	end

	local purchasePrices = type(purchase) == 'table' and purchase or {}
	if #purchasePrices > 0 then
		local hasSell = acq.priceRange(purchasePrices, 'price_sell') ~= nil
		local priceColumns = { { id = 'buy', key = 'price_buy', label = 'Buy' } }
		if hasSell then
			priceColumns[#priceColumns + 1] = { id = 'sell', key = 'price_sell', label = 'Sell' }
		end
		cards[#cards + 1] = {
			type = 'terminals',
			title = '<span aria-hidden="true">🛒</span> Trade',
			caption = 'Trade terminals',
			description = hasSell and acq.buildShopTerminalsDescription(purchasePrices)
				or acq.buildSinglePriceDescription(purchasePrices, 'price_buy'),
			prices = purchasePrices,
			priceColumns = priceColumns,
		}
	else
		local slug = mw.uri.encode(refined.slug or apiData.slug or '', 'PATH')
		cards[#cards + 1] = {
			type = 'links',
			title = 'Browse trade data',
			buttons = {
				{ label = 'SC Trade Tools', url = 'https://sc-trade.tools/commodities/' .. slug, weight = 'normal' },
				{ label = 'UEX', url = 'https://uexcorp.space/commodities/info/name/' .. slug, weight = 'normal' },
			},
		}
	end

	return { summary = summary, cards = cards }
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
