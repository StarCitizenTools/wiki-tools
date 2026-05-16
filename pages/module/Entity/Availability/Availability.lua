require('strict')

--- @module Entity/Availability
--- Renders where an entity can be acquired in-game. Currently limited to
--- shop terminals sourced from apiData.uex_prices. Consumes
--- Module:Entity/Data so it shares Apiunto's cache with other Entity
--- templates on the page.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')
local tableLua = require('Module:TableLua')
local yesno = require('Module:Yesno')

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

--- Items shop description: "N locations · <prices>". Format adapts to
--- the data — unlabeled when only one side of the market is active,
--- labeled "Buy X · Sell Y" when both are. Sell-only items (rare) show
--- only the sell side.
---
--- @param prices table[]
--- @return string
local function buildShopTerminalsDescription(prices)
	local buyText = formatPriceRange(priceRange(prices, 'price_buy'))
	local sellText = formatPriceRange(priceRange(prices, 'price_sell'))

	local parts = { locationCountLabel(prices) }
	if buyText and sellText then
		table.insert(parts, 'Buy ' .. buyText)
		table.insert(parts, 'Sell ' .. sellText)
	elseif buyText then
		table.insert(parts, buyText)
		table.insert(parts, 'Not sellable')
	elseif sellText then
		table.insert(parts, 'Sell ' .. sellText)
	end

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

--- Two signals that the entity is a vehicle rather than an item:
---   1. `uex_prices` arrives as a dict with `purchase`/`rental` buckets
---      instead of a flat array.
---   2. `msrp` is set at the top level (pledge-store price in USD).
--- Either one is sufficient — vehicles without UEX data yet still
--- carry msrp, and pre-pledge live-service vehicles still get the
--- dict-shaped uex_prices.
---
--- @param apiData table
--- @return boolean
local function isVehicleApiData(apiData)
	if type(apiData) ~= 'table' then
		return false
	end
	local prices = apiData.uex_prices
	if type(prices) == 'table' and (prices.purchase ~= nil or prices.rental ~= nil) then
		return true
	end
	return apiData.msrp ~= nil
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
	local rows = {
		{
			label = 'Buy',
			icon = '🛒',
			value = resolveFlag(args.canBuy, inferCanAcquire(apiData.uex_prices, 'price_buy')),
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
	table.insert(rows, {
		label = 'Pledge',
		icon = '💵',
		value = resolveFlag(args.canPledge, hasEntityTag(apiData, 'PromotionalItem')),
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
	if isVehicleApiData(apiData) then
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

local UEX_FOOTER = 'Data from [https://uexcorp.space UEX Corp]'

--- Items render a single Shops card with both Buy and Sell columns —
--- items have a two-sided market on the same terminal, so one row per
--- terminal carries both prices.
---
--- @param apiData table
--- @return string
local function renderItemDetail(apiData)
	local prices = apiData.uex_prices
	local hasPrices = type(prices) == 'table' and #prices > 0
	return collapsibleCard.render({
		title = '<span aria-hidden="true">🛒</span> Shops',
		description = hasPrices and buildShopTerminalsDescription(prices) or 'No shop data in UEX',
		content = hasPrices and renderTerminalTable({
			prices = prices,
			caption = 'Shop terminals',
			priceColumns = {
				{ id = 'buy', key = 'price_buy', label = 'Buy' },
				{ id = 'sell', key = 'price_sell', label = 'Sell' },
			},
		}) or nil,
		footer = UEX_FOOTER,
	})
end

--- Vehicles split detail into two cards — purchase terminals (🛒
--- Shops) and rental terminals (⏳ Rentals) — mirroring the summary
--- grid's Buy/Rent split. UEX models them as separate arrays under
--- `uex_prices.purchase` and `uex_prices.rental`; vehicles never have
--- a Sell side, so each card carries one price column.
---
--- @param apiData table
--- @return string
local function renderVehicleDetail(apiData)
	local prices = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local purchasePrices = type(prices.purchase) == 'table' and prices.purchase or {}
	local rentalPrices = type(prices.rental) == 'table' and prices.rental or {}
	local hasPurchase = #purchasePrices > 0
	local hasRental = #rentalPrices > 0

	local shopCard = collapsibleCard.render({
		title = '<span aria-hidden="true">🛒</span> Shops',
		description = hasPurchase and buildSinglePriceDescription(purchasePrices, 'price_buy')
			or 'No purchase data in UEX',
		content = hasPurchase and renderTerminalTable({
			prices = purchasePrices,
			caption = 'Vehicle purchase terminals',
			priceColumns = { { id = 'buy', key = 'price_buy', label = 'Buy' } },
		}) or nil,
		footer = UEX_FOOTER,
	})

	local rentalCard = collapsibleCard.render({
		title = '<span aria-hidden="true">⏳</span> Rentals',
		description = hasRental and buildSinglePriceDescription(rentalPrices, 'price_rent') or 'No rental data in UEX',
		content = hasRental and renderTerminalTable({
			prices = rentalPrices,
			caption = 'Vehicle rental terminals',
			priceColumns = { { id = 'rent', key = 'price_rent', label = 'Rent' } },
		}) or nil,
		footer = UEX_FOOTER,
	})

	return shopCard .. rentalCard
end

--- Main entry point. Renders:
---   1. Summary — a plain responsive grid of acquisition flags. For
---      items: Buy / Loot / Craft / Pledge (+ Rent when editor sets it).
---      For vehicles: Buy / Rent / Pledge. No card wrapper because the
---      grid already reads as a scannable header above the first card.
---   2. Detail — collapsible card(s) of UEX terminal prices. Items get
---      one Shops card with Buy/Sell columns; vehicles get a Shops card
---      (purchase) plus a Rentals card.
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
	local detail = isVehicleApiData(apiData) and renderVehicleDetail(apiData) or renderItemDetail(apiData)

	return styles .. summary .. detail
end

return p
