require('strict')

--- @module Entity/Availability
--- Renders where/how an entity can be acquired in-game, dispatched by kind:
---  * items / vehicles — UEX shop (and rental) terminals from apiData.uex_prices
---  * commodities — a Mining card (deposit locations) + a Trade card (UEX
---    terminals; empty for all commodities today, so it shows a placeholder).
--- Consumes Module:Entity/Data so it shares Apiunto's cache with other Entity
--- templates on the page.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')
local cardLua = require('Module:CardLua')
local tableLua = require('Module:TableLua')
local yesno = require('Module:Yesno')
local commodity = require('Module:Entity/Commodity')

local p = {}

local lang = mw.language.getContentLanguage()

--- Zero prices render as `-` (UEX uses 0 rather than null for "not sold
--- here"). Returns the locale-grouped number otherwise (e.g.
--- 123456 → "123,456"). MediaWiki's tablesorter parses grouped
--- numbers natively, so the table sort stays numerically correct.
---
--- @param price number|nil
--- @return string
local function formatPrice(price)
	if not price or price == 0 then
		return '-'
	end
	return lang:formatNum(price)
end

--- Wraps the Apiunto ISO 8601 timestamp in a <time> element. The visible
--- text is truncated to YYYY-MM-DD because the HH:MM:SS adds precision
--- readers can't act on, while the datetime attribute preserves the full
--- timestamp for machine readers and assistive tech.
--- TableLua's sort strips HTML before comparing, so sorting stays correct.
---
--- @param isoDate string|nil
--- @return string
local function formatDate(isoDate)
	if type(isoDate) ~= 'string' or isoDate == '' then
		return '-'
	end
	return tostring(mw.html.create('time'):attr('datetime', isoDate):wikitext(isoDate:sub(1, 10)))
end

--- Trims the full UEX `game_version` ("4.7.2-LIVE.11674325") down to
--- just the marketing version ("4.7.2"). The `-LIVE.build` suffix is
--- internal CIG release metadata that doesn't help a player judge
--- whether the price is current — knowing it was reported in 4.7.2 is
--- enough context.
---
--- @param version string|nil
--- @return string
local function formatVersion(version)
	if type(version) ~= 'string' or version == '' then
		return '-'
	end
	return version:match('^[^-]+') or '-'
end

--- Min and max of non-zero numeric entries for `key`. Skips zeros because
--- UEX uses 0 to signal "not sold here" — including them would collapse
--- the minimum to 0 and misrepresent the actual price players see.
---
--- @param prices table[]
--- @param key string
--- @return number|nil min, number|nil max
local function priceRange(prices, key)
	local min, max
	for _, entry in ipairs(prices) do
		local p = entry[key]
		if type(p) == 'number' and p > 0 then
			if not min or p < min then
				min = p
			end
			if not max or p > max then
				max = p
			end
		end
	end
	return min, max
end

--- "7 aUEC" when min == max, "7–12 aUEC" otherwise. Returns nil when no
--- non-zero prices exist, so callers can distinguish "no market" from
--- "market with zero price" (which shouldn't happen but is guarded
--- against in priceRange).
---
--- @param min number|nil
--- @param max number|nil
--- @return string|nil
local function formatPriceRange(min, max)
	if not min then
		return nil
	end
	if min == max then
		return lang:formatNum(min) .. ' aUEC'
	end
	return lang:formatNum(min) .. '–' .. lang:formatNum(max) .. ' aUEC'
end

--- "N locations" or "1 location". Pulled out so both description
--- builders share the same phrasing.
---
--- @param prices table[]
--- @return string
local function locationCountLabel(prices)
	local n = #prices
	return n == 1 and '1 location' or (n .. ' locations')
end

--- Two-sided market description: "N locations · Buy X · Sell Y".
--- Only called when at least one row has a non-zero `price_sell`
--- (the caller in renderDetail gates on this), so the sell side is
--- always present here. Buy may be absent on sell-only listings.
---
--- @param prices table[]
--- @return string
local function buildShopTerminalsDescription(prices)
	local buyText = formatPriceRange(priceRange(prices, 'price_buy'))
	local sellText = formatPriceRange(priceRange(prices, 'price_sell'))

	local parts = { locationCountLabel(prices) }
	if buyText then
		table.insert(parts, 'Buy ' .. buyText)
	end
	table.insert(parts, 'Sell ' .. sellText)

	return table.concat(parts, ' · ')
end

--- Vehicle (and any other single-axis market) description:
--- "N locations · <range>". The label is dropped because there's only
--- one price column to talk about — no ambiguity for the reader to
--- resolve.
---
--- @param prices table[]
--- @param key string price field on each entry (`price_buy`, `price_rent`)
--- @return string
local function buildSinglePriceDescription(prices, key)
	local rangeText = formatPriceRange(priceRange(prices, key))
	local parts = { locationCountLabel(prices) }
	if rangeText then
		table.insert(parts, rangeText)
	end
	return table.concat(parts, ' · ')
end

--- Wikilink to the parent star system, e.g. `[[Stanton system|Stanton]]`.
--- Falls back to `-` when the API didn't enrich the entry with a
--- starmap_location (older terminals haven't been mapped yet).
---
--- @param entry table
--- @return string
local function formatSystemCell(entry)
	local loc = entry.starmap_location
	if type(loc) == 'table' and type(loc.star_system_name) == 'string' and loc.star_system_name ~= '' then
		local system = loc.star_system_name
		return '[[' .. system .. ' system|' .. system .. ']]'
	end
	return '-'
end

--- Wraps the terminal name in a wikilink to its parent location (e.g.
--- "Juice Bar - Seraphim Station" → `[[Seraphim Station|Juice Bar - Seraphim Station]]`).
--- The link target is `starmap_location.name`; most of those names map
--- directly to wiki pages, and red links act as a polite invitation to
--- create them. When starmap_location is missing entirely, falls back
--- to the plain terminal name.
---
--- Gateway stations get the system appended as a disambiguator
--- ("Stanton Gateway" → "Stanton Gateway (Pyro)") because their bare
--- name collides with the destination system's name on the wiki. The
--- visible cell text stays the bare terminal name.
---
--- @param entry table
--- @return string
local function formatLocationCell(entry)
	local terminalName = entry.terminal_name or '-'
	local loc = entry.starmap_location
	if type(loc) ~= 'table' or type(loc.name) ~= 'string' or loc.name == '' then
		return terminalName
	end
	local linkTarget = loc.name
	if linkTarget:match(' Gateway$') and type(loc.star_system_name) == 'string' and loc.star_system_name ~= '' then
		linkTarget = linkTarget .. ' (' .. loc.star_system_name .. ')'
	end
	return '[[' .. linkTarget .. '|' .. terminalName .. ']]'
end

--- Renders a UEX terminal table. The columns System / Location /
--- Updated / Version are fixed (every terminal row carries those);
--- callers supply the price columns that apply to their market —
--- `{ id = 'buy', key = 'price_buy', label = 'Buy' }` for items'
--- buy side, `{ id = 'rent', key = 'price_rent', label = 'Rent' }`
--- for vehicle rentals, etc.
---
--- @param opts { prices: table[], caption: string, priceColumns: { id: string, key: string, label: string }[] }
--- @return string
local function renderTerminalTable(opts)
	local columns = {
		{ id = 'system', label = 'System', textAlign = 'start' },
		{ id = 'location', label = 'Location', textAlign = 'start' },
	}
	for _, col in ipairs(opts.priceColumns) do
		table.insert(columns, { id = col.id, label = col.label, textAlign = 'number' })
	end
	table.insert(columns, { id = 'updated', label = 'Updated', textAlign = 'end' })
	table.insert(columns, { id = 'version', label = 'Version', textAlign = 'end' })

	local rows = {}
	for _, entry in ipairs(opts.prices) do
		local row = { formatSystemCell(entry), formatLocationCell(entry) }
		for _, col in ipairs(opts.priceColumns) do
			table.insert(row, formatPrice(entry[col.key]))
		end
		table.insert(row, formatDate(entry.date_updated))
		table.insert(row, formatVersion(entry.game_version))
		table.insert(rows, row)
	end

	return tableLua.render({
		caption = opts.caption,
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = columns,
		data = rows,
		-- UEX prices are player-reported, so sort by freshness (newest first).
		-- The ISO date string sorts lexicographically the same way as a real
		-- date comparison, so no custom comparator is needed.
		sort = { updated = 'desc' },
	})
end

--- true → "Yes", false → "No", nil → "Unknown". Module:Yesno already
--- collapses input variations to this three-state logic. Rendered as
--- visually-hidden text inside the summary value cell — sighted
--- readers see the icon, assistive tech / reader modes / translators
--- read this text.
---
--- @param value boolean|nil
--- @return string
local function formatFlag(value)
	if value == true then
		return 'Yes'
	end
	if value == false then
		return 'No'
	end
	return 'Unknown'
end

--- Maps the flag value to a state slug used as the BEM modifier
--- suffix on the summary item (`…-item--yes` etc.) and as the
--- canonical `data-state` attribute. CSS uses a descendant selector
--- to set the value icon and color from the item's state, so any
--- future card-level treatment (background tint, etc.) can target the
--- item directly without reaching in.
---
--- @param value boolean|nil
--- @return string
local function flagState(value)
	if value == true then
		return 'yes'
	end
	if value == false then
		return 'no'
	end
	return 'unknown'
end

--- If arg is true/false, honours the arg (editor override). Otherwise
--- falls back to the derived value (when it's a boolean) or nil (unknown).
---
--- @param arg string|nil
--- @param derived boolean|nil
--- @return boolean|nil
local function resolveFlag(arg, derived)
	local override = yesno(arg)
	if override ~= nil then
		return override
	end
	if type(derived) == 'boolean' then
		return derived
	end
	return nil
end

--- Infers whether the entity can be acquired through a given UEX price
--- channel. Present non-zero prices for `key` → Yes; rows exist but all
--- are zero → No (UEX explicitly saw no listings on that side); the
--- array is missing or empty → nil (Unknown), so the editor can supply
--- a direct override via the matching `canX` arg.
---
--- @param prices table[]|nil
--- @param key string price field on each entry (`price_buy`, `price_rent`)
--- @return boolean|nil
local function inferCanAcquire(prices, key)
	if type(prices) ~= 'table' or #prices == 0 then
		return nil
	end
	local min = priceRange(prices, key)
	return min ~= nil
end

--- Scans apiData.entity_tag_map (array of { uuid, name }) for a tag by
--- name. Present → true; map exists without the tag → false; map missing
--- or not an array → nil so the editor can override.
---
--- @param apiData table
--- @param tagName string
--- @return boolean|nil
local function hasEntityTag(apiData, tagName)
	local tags = apiData.entity_tag_map
	if type(tags) ~= 'table' then
		return nil
	end
	for _, tag in ipairs(tags) do
		if tag.name == tagName then
			return true
		end
	end
	return false
end

--- Mirrors Module:Entity/Vehicle.matches() — vehicles always carry the
--- `is_vehicle` key at the top level, items never do. Both endpoints
--- now share the same `uex_prices` dict shape, so the prior dict-vs-array
--- discriminator no longer works; using the kind-canonical signal keeps
--- Availability aligned with the kind registry's idea of "vehicle".
---
--- @param apiData table
--- @return boolean
local function isVehicle(apiData)
	return type(apiData) == 'table' and apiData.is_vehicle ~= nil
end

--- Mirrors Module:Entity/Commodity.matches() — commodity records carry the
--- `box_sizes_scu` ladder, a field neither items nor vehicles return. Lets
--- Availability host commodity acquisition (mining + trade) alongside the
--- item/vehicle paths.
---
--- @param apiData table
--- @return boolean
local function isCommodity(apiData)
	return type(apiData) == 'table' and apiData.box_sizes_scu ~= nil
end

--- Groups a commodity's raw mining `locations[]` by star system, in first-seen
--- order, normalizing each entry to the cells the Mining table renders. Safe on
--- nil / non-table input (returns {}).
---
--- @param locations table[]|nil
--- @return table[] groups of { system, rows = { { body, type, spawn_pct, quality } } }
local function groupBySystem(locations)
	local order, bySystem = {}, {}
	if type(locations) ~= 'table' then
		return {}
	end
	for _, l in ipairs(locations) do
		local sys = l.system or 'Unknown'
		if not bySystem[sys] then
			bySystem[sys] = { system = sys, rows = {} }
			order[#order + 1] = sys
		end
		local quality = nil
		if l.quality_min and l.quality_max then
			quality = tostring(l.quality_min) .. '–' .. tostring(l.quality_max)
		end
		table.insert(bySystem[sys].rows, {
			body = l.display_name or l.name,
			type = l.type,
			spawn_pct = l.relative_probability_percent,
			quality = quality,
		})
	end
	local groups = {}
	for _, sys in ipairs(order) do
		groups[#groups + 1] = bySystem[sys]
	end
	return groups
end

--- Builds the ordered list of summary rows for an item entity:
--- Buy, Loot, Craft, Pledge (Rent only when the editor explicitly
--- sets canRent — items aren't structurally rentable). All derived
--- values can be overridden via the matching `canX` arg.
---
--- @param args table
--- @param apiData table
--- @return { label: string, icon: string, value: boolean|nil }[]
local function buildItemSummaryRows(args, apiData)
	local prices = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local rows = {
		{
			label = 'Buy',
			icon = '🛒',
			value = resolveFlag(args.canBuy, inferCanAcquire(prices.purchase, 'price_buy')),
		},
	}

	local rentValue = yesno(args.canRent)
	if rentValue ~= nil then
		table.insert(rows, { label = 'Rent', icon = '⏳', value = rentValue })
	end

	table.insert(rows, {
		label = 'Loot',
		icon = '📦',
		value = resolveFlag(args.canLoot, hasEntityTag(apiData, 'CanGenerateAsLoot')),
	})
	table.insert(rows, {
		label = 'Craft',
		icon = '🔨',
		value = resolveFlag(args.canCraft, apiData.is_craftable),
	})
	-- Pledge derivation covers two tag families:
	--   PromotionalItem — generic pledge-store items
	--   SubscriberFlair — subscriber-exclusive monthly flair (only
	--                     acquirable through pledge subscriptions)
	-- Either tag makes the item pledge-acquirable. `or` works correctly
	-- because both calls inspect the same entity_tag_map — they both
	-- return nil together when the map is missing.
	table.insert(rows, {
		label = 'Pledge',
		icon = '💵',
		value = resolveFlag(
			args.canPledge,
			hasEntityTag(apiData, 'PromotionalItem') or hasEntityTag(apiData, 'SubscriberFlair')
		),
	})

	return rows
end

--- Builds the ordered list of summary rows for a vehicle entity:
--- Buy, Rent, Pledge. Loot and Craft are omitted — neither concept
--- applies to vehicles in the live game today, and rendering them as
--- "Unknown" forever is noise. Pledge derives from `msrp` presence
--- (vehicle pledge prices are at the top level, not in entity tags).
---
--- @param args table
--- @param apiData table
--- @return { label: string, icon: string, value: boolean|nil }[]
local function buildVehicleSummaryRows(args, apiData)
	local prices = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	return {
		{
			label = 'Buy',
			icon = '🛒',
			value = resolveFlag(args.canBuy, inferCanAcquire(prices.purchase, 'price_buy')),
		},
		{
			label = 'Rent',
			icon = '⏳',
			value = resolveFlag(args.canRent, inferCanAcquire(prices.rental, 'price_rent')),
		},
		{
			label = 'Pledge',
			icon = '💵',
			value = resolveFlag(args.canPledge, apiData.msrp ~= nil),
		},
	}
end

--- Builds the ordered summary rows for a commodity entity: Mine, Harvest,
--- Buy. Mine/Harvest derive from the raw record's mineability flags; Buy
--- derives from UEX purchase listings (empty for all commodities today, so
--- it reads "Unknown" until the API populates commodity prices). All
--- overridable via canMine / canHarvest / canBuy.
---
--- @param args table
--- @param apiData table
--- @return { label: string, icon: string, value: boolean|nil }[]
local function buildCommoditySummaryRows(args, apiData)
	local raw = apiData._rawRecord or apiData
	local refined = apiData._refinedRecord or apiData
	local purchase = type(refined.uex_prices) == 'table' and refined.uex_prices.purchase or nil
	return {
		{ label = 'Mine', icon = '⛏️', value = resolveFlag(args.canMine, raw.is_mineable) },
		{ label = 'Harvest', icon = '🌿', value = resolveFlag(args.canHarvest, raw.has_harvestables) },
		{ label = 'Buy', icon = '🛒', value = resolveFlag(args.canBuy, inferCanAcquire(purchase, 'price_buy')) },
	}
end

--- Dispatches to the item or vehicle summary builder. The `icon`
--- field on each row is a category-level decorative glyph (emoji
--- for now — no Codex icons feel right for these specific concepts).
--- Each card renders it before the label; `aria-hidden` on the icon
--- span keeps screen readers from announcing it on top of the
--- already-clear label text.
---
--- @param args table
--- @param apiData table
--- @return { label: string, icon: string, value: boolean|nil }[]
local function buildSummaryRows(args, apiData)
	if isCommodity(apiData) then
		return buildCommoditySummaryRows(args, apiData)
	end
	if isVehicle(apiData) then
		return buildVehicleSummaryRows(args, apiData)
	end
	return buildItemSummaryRows(args, apiData)
end

--- Renders the summary rows as a grid of label/value items. Each item
--- has a category icon + label on the left and a value `<dd>` on the
--- right styled as a 16×16 mask-image icon. The state ("yes" / "no" /
--- "unknown") lives on the item element (the dt/dd pair's wrapper)
--- rather than the value cell, so card-level treatment (background
--- tint, border accent, etc.) can target the item directly:
---  * `data-state` on the item `<div>` is the canonical
---    machine-readable target — scrapers and AI agents query
---    `[data-state]` rather than parsing class modifiers.
---  * A visually-hidden `<span>` inside the `<dd>` carries the
---    human-readable text ("Yes" / "No" / "Unknown"). Screen readers
---    announce it as the `<dd>`'s content; translation tools and reader
---    modes pick it up too (both of which can ignore `aria-label`).
--- The category icon span carries `aria-hidden="true"` so screen
--- readers don't double-announce it on top of the visible label text.
--- Always shows every row so the layout stays stable across pages.
---
--- @param rows { label: string, icon: string|nil, value: boolean|nil }[]
--- @return string
local function renderSummary(rows)
	local root = mw.html.create('dl'):addClass('t-entity-availability-summary')
	for _, row in ipairs(rows) do
		local state = flagState(row.value)
		local itemHtml = root:tag('div')
			:addClass('t-entity-availability-summary-item')
			:addClass('t-entity-availability-summary-item--' .. state)
			:attr('data-state', state)
		local labelHtml = itemHtml:tag('dt'):addClass('t-entity-availability-summary-label')
		if row.icon and row.icon ~= '' then
			labelHtml
				:tag('span')
				:addClass('t-entity-availability-summary-icon')
				:attr('aria-hidden', 'true')
				:wikitext(row.icon)
		end
		labelHtml:wikitext(row.label)
		itemHtml
			:tag('dd')
			:addClass('t-entity-availability-summary-value')
			:tag('span')
			:addClass('t-entity-availability-summary-value-text')
			:wikitext(formatFlag(row.value))
	end
	return tostring(root)
end

-- Home page, used when no terminal carries a deep `uex_link`.
local UEX_FALLBACK_URL = 'https://uexcorp.space'

--- Returns the first non-empty `uex_link` among the given price rows, or
--- nil when none carry one. UEX exposes `uex_link` per terminal (a deep
--- link into that terminal's listing), not per entity; the footer uses
--- the first as a representative entry point into UEX for this data.
---
--- @param prices table[]|nil
--- @return string|nil
local function firstUexLink(prices)
	if type(prices) ~= 'table' then
		return nil
	end
	for _, entry in ipairs(prices) do
		local link = entry.uex_link
		if type(link) == 'string' and link ~= '' then
			return link
		end
	end
	return nil
end

--- Builds the attribution footer: just the UEX logo (no leading text),
--- linking to `url`. `class=metadata` keeps PageImages from selecting
--- this attribution logo as the page image. "powered by UEX" goes in both
--- `alt` (assistive tech) and the unnamed caption, which MediaWiki maps to
--- the `title` attribute (hover tooltip) for an inline image.
---
--- @param url string
--- @return string
local function uexFooter(url)
	return '[[File:UEX logo.svg|class=metadata|link=' .. url .. '|alt=powered by UEX|x12px|powered by UEX]]'
end

--- Renders the commodity Mining card: the raw record's deposit `locations[]`,
--- one sortable table per star system inside a single collapsible card.
--- Returns nil when there are no locations so the card collapses out.
---
--- @param raw table|nil
--- @return string|nil
local function renderMiningCard(raw)
	local groups = groupBySystem(raw and raw.locations)
	if #groups == 0 then
		return nil
	end

	local parts, total = {}, 0
	for _, g in ipairs(groups) do
		local rows = {}
		for _, r in ipairs(g.rows) do
			rows[#rows + 1] = {
				r.body or '-',
				r.type or '-',
				r.spawn_pct and (tostring(r.spawn_pct) .. '%') or '-',
				r.quality or '-',
			}
		end
		total = total + #g.rows
		parts[#parts + 1] = tableLua.render({
			caption = g.system,
			class = 'wikitable--fluid',
			columns = {
				{ id = 'body', label = 'Body', textAlign = 'start' },
				{ id = 'type', label = 'Type', textAlign = 'start' },
				{ id = 'spawn', label = 'Spawn %', textAlign = 'number' },
				{ id = 'quality', label = 'Quality', textAlign = 'end' },
			},
			data = rows,
		})
	end

	local depositLabel = total == 1 and '1 deposit' or (total .. ' deposits')
	local systemLabel = #groups == 1 and '1 system' or (#groups .. ' systems')

	-- Method-aware title so ship / FPS / vehicle mining and harvesting read
	-- distinctly (e.g. "Ship mining", "FPS mining", "Harvesting"). Falls back
	-- to a generic noun for kinds acquisitionLabel returns nil for (remains).
	local kind = raw.kind
	local title = commodity.acquisitionLabel(raw, kind) or (kind == 'remains' and 'Collection') or 'Mining'
	local icon = kind == 'harvestable' and '🌿' or '⛏️'

	return collapsibleCard.render({
		title = '<span aria-hidden="true">' .. icon .. '</span> ' .. title,
		description = depositLabel .. ' · ' .. systemLabel,
		content = table.concat(parts, '\n'),
	})
end

--- Renders commodity acquisition detail: the Mining card (deposit locations)
--- plus a Trade card. Commodity `uex_prices` is empty for every commodity
--- today, so the Trade card is, for now, a pointer to SC Trade Tools (which
--- carries live commodity prices), keyed on the commodity slug. If/when the
--- API populates commodity prices, the buy/sell terminal table renders too
--- (the entry shape is assumed to match the item/vehicle terminal shape).
---
--- @param apiData table
--- @return string
local function renderCommodityDetail(apiData)
	local out = {}

	local mining = renderMiningCard(apiData._rawRecord)
	if mining then
		out[#out + 1] = mining
	end

	local refined = apiData._refinedRecord or apiData
	local uexPrices = type(refined.uex_prices) == 'table' and refined.uex_prices or {}
	local purchasePrices = type(uexPrices.purchase) == 'table' and uexPrices.purchase or {}

	if #purchasePrices > 0 then
		-- Live terminal prices exist (future-proofing — empty for all
		-- commodities today): a collapsible buy/sell terminal table.
		local hasSellSide = priceRange(purchasePrices, 'price_sell') ~= nil
		local priceColumns = { { id = 'buy', key = 'price_buy', label = 'Buy' } }
		if hasSellSide then
			table.insert(priceColumns, { id = 'sell', key = 'price_sell', label = 'Sell' })
		end
		out[#out + 1] = collapsibleCard.render({
			title = '<span aria-hidden="true">🛒</span> Trade',
			description = hasSellSide and buildShopTerminalsDescription(purchasePrices)
				or buildSinglePriceDescription(purchasePrices, 'price_buy'),
			content = renderTerminalTable({
				prices = purchasePrices,
				caption = 'Trade terminals',
				priceColumns = priceColumns,
			}),
		})
	else
		-- No embedded prices: a link-out card to SC Trade Tools (the live
		-- commodity price source), keyed on slug.
		local slug = refined.slug or apiData.slug
		out[#out + 1] = cardLua.renderLinkCard({
			title = '<span aria-hidden="true">🛒</span> Trade',
			button = {
				label = 'SC Trade Tools',
				url = 'https://sc-trade.tools/commodities/' .. mw.uri.encode(slug or '', 'PATH'),
				weight = 'normal',
			},
		})
	end

	return table.concat(out, '\n')
end

--- Renders the Shops card from `uex_prices.purchase` and, for vehicles
--- only, a Rentals card from `uex_prices.rental`. Items and vehicles
--- now share the same `uex_prices` dict shape, so a single path covers
--- both kinds:
---  * Sell column is added when any purchase row has a non-zero
---    `price_sell` — items pass this check, vehicles don't, so the
---    column appears or disappears without a kind branch.
---  * The Rentals card is gated on kind: rentals aren't structurally
---    available for items today, so the "No rental data in UEX"
---    placeholder would be misleading noise.
---
--- @param apiData table
--- @return string
local function renderDetail(apiData)
	if isCommodity(apiData) then
		return renderCommodityDetail(apiData)
	end

	local uexPrices = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local purchasePrices = type(uexPrices.purchase) == 'table' and uexPrices.purchase or {}
	local hasPurchase = #purchasePrices > 0
	local hasSellSide = hasPurchase and priceRange(purchasePrices, 'price_sell') ~= nil

	local priceColumns = { { id = 'buy', key = 'price_buy', label = 'Buy' } }
	if hasSellSide then
		table.insert(priceColumns, { id = 'sell', key = 'price_sell', label = 'Sell' })
	end

	local shopDescription
	if hasPurchase then
		shopDescription = hasSellSide and buildShopTerminalsDescription(purchasePrices)
			or buildSinglePriceDescription(purchasePrices, 'price_buy')
	else
		shopDescription = 'No shop data in UEX'
	end

	local shopCard = collapsibleCard.render({
		title = '<span aria-hidden="true">🛒</span> Shops',
		description = shopDescription,
		content = hasPurchase and renderTerminalTable({
			prices = purchasePrices,
			caption = 'Shop terminals',
			priceColumns = priceColumns,
		}) or nil,
		footer = uexFooter(firstUexLink(purchasePrices) or UEX_FALLBACK_URL),
	})

	if not isVehicle(apiData) then
		return shopCard
	end

	local rentalPrices = type(uexPrices.rental) == 'table' and uexPrices.rental or {}
	local hasRental = #rentalPrices > 0
	local rentalCard = collapsibleCard.render({
		title = '<span aria-hidden="true">⏳</span> Rentals',
		description = hasRental and buildSinglePriceDescription(rentalPrices, 'price_rent') or 'No rental data in UEX',
		content = hasRental and renderTerminalTable({
			prices = rentalPrices,
			caption = 'Vehicle rental terminals',
			priceColumns = { { id = 'rent', key = 'price_rent', label = 'Rent' } },
		}) or nil,
		footer = uexFooter(firstUexLink(rentalPrices) or UEX_FALLBACK_URL),
	})

	return shopCard .. rentalCard
end

--- Main entry point. Renders:
---   1. Summary — a plain responsive grid of acquisition flags. For
---      items: Buy / Loot / Craft / Pledge (+ Rent when editor sets it).
---      For vehicles: Buy / Rent / Pledge. No card wrapper because the
---      grid already reads as a scannable header above the first card.
---   2. Detail — a 🛒 Shops card from `uex_prices.purchase` (with a
---      Sell column when the entity has a two-sided market), plus a
---      ⏳ Rentals card for vehicles.
--- Future sibling cards (loot table, crafting recipes, etc.) can drop in
--- alongside the detail cards without reshuffling.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)
	local apiData = result.apiData

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Availability/styles.css' },
	})

	local summary = renderSummary(buildSummaryRows(args, apiData))
	local detail = renderDetail(apiData)

	return styles .. summary .. detail
end

-- Test-only exports. Not part of the public API.
p._internal = {
	isCommodity = isCommodity,
	groupBySystem = groupBySystem,
	buildCommoditySummaryRows = buildCommoditySummaryRows,
}

return p
