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

--- Zero prices render as `-` (UEX uses 0 rather than null for "not sold
--- here"). Returns the raw number otherwise.
---
--- @param price number|nil
--- @return string
local function formatPrice(price)
	if not price or price == 0 then
		return '-'
	end
	return tostring(price)
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
		return tostring(min) .. ' aUEC'
	end
	return tostring(min) .. '–' .. tostring(max) .. ' aUEC'
end

--- Builds the card's description line: "N locations · <prices>". Format
--- adapts to the data: unlabeled price when only one side of the market
--- is active, labeled "Buy X · Sell Y" when both are. Sell-only items
--- (rare) show only the sell side.
---
--- @param prices table[]
--- @return string
local function buildShopTerminalsDescription(prices)
	local locationCount = #prices
	local locationLabel = locationCount == 1 and '1 location' or (locationCount .. ' locations')

	local buyText = formatPriceRange(priceRange(prices, 'price_buy'))
	local sellText = formatPriceRange(priceRange(prices, 'price_sell'))

	local parts = { locationLabel }
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
--- @param entry table
--- @return string
local function formatLocationCell(entry)
	local terminalName = entry.terminal_name or '-'
	local loc = entry.starmap_location
	if type(loc) == 'table' and type(loc.name) == 'string' and loc.name ~= '' then
		return '[[' .. loc.name .. '|' .. terminalName .. ']]'
	end
	return terminalName
end

--- @param prices table[]
--- @return string
local function renderShopTerminalTable(prices)
	local rows = {}
	for _, entry in ipairs(prices) do
		table.insert(rows, {
			formatSystemCell(entry),
			formatLocationCell(entry),
			formatPrice(entry.price_buy),
			formatPrice(entry.price_sell),
			formatDate(entry.date_updated),
		})
	end

	return tableLua.render({
		caption = 'Shop terminals',
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = {
			{ id = 'system', label = 'System', textAlign = 'start' },
			{ id = 'location', label = 'Location', textAlign = 'start' },
			{ id = 'buy', label = 'Buy', textAlign = 'number' },
			{ id = 'sell', label = 'Sell', textAlign = 'number' },
			{ id = 'updated', label = 'Updated', textAlign = 'end' },
		},
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

--- Infers whether the item is buyable from shop data. Present buy prices
--- in uex_prices → Yes. Prices rows exist but all buy prices are zero →
--- No (UEX explicitly saw no buy listings). Missing uex_prices → Unknown
--- so the editor can supply canBuy directly.
---
--- @param prices table[]|nil
--- @return boolean|nil
local function inferCanBuy(prices)
	if type(prices) ~= 'table' or #prices == 0 then
		return nil
	end
	local min = priceRange(prices, 'price_buy')
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

--- Builds the ordered list of summary rows — one flag per acquisition
--- method. "Buy" derives from UEX shop data, "Loot"/"Pledge" from
--- entity_tag_map, "Craft" from apiData.is_craftable. All derived
--- values can be overridden via args.canBuy / args.canLoot /
--- args.canPledge / args.canCraft. Rent is editor-only because no API
--- source currently reports it.
---
--- The `icon` field is a category-level decorative glyph (emoji for
--- now — no Codex icons feel right for these specific concepts). Each
--- card renders it before the label; `aria-hidden` keeps screen
--- readers from announcing it on top of the already-clear label text.
---
--- @param args table
--- @param apiData table
--- @param prices table[]|nil uex_prices passed through from the API
--- @return { label: string, icon: string, value: boolean|nil }[]
local function buildSummaryRows(args, apiData, prices)
	return {
		{ label = 'Buy', icon = '🛒', value = resolveFlag(args.canBuy, inferCanBuy(prices)) },
		{ label = 'Rent', icon = '⏳', value = yesno(args.canRent) },
		{
			label = 'Loot',
			icon = '📦',
			value = resolveFlag(args.canLoot, hasEntityTag(apiData, 'CanGenerateAsLoot')),
		},
		{
			label = 'Pledge',
			icon = '💵',
			value = resolveFlag(args.canPledge, hasEntityTag(apiData, 'PromotionalItem')),
		},
		{ label = 'Craft', icon = '🔨', value = resolveFlag(args.canCraft, apiData.is_craftable) },
	}
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

--- Main entry point. Renders:
---   1. Summary — a plain responsive grid of buy / rent / loot /
---      pledge / craft flags. No card wrapper because the grid already
---      reads as a scannable header above the first card.
---   2. Shop availability (collapsible card) — UEX shop terminal prices,
---      or a static "no data" notice when UEX hasn't indexed the item.
--- Future sibling cards (loot table, crafting recipes, etc.) can drop in
--- alongside the shop card without reshuffling.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Availability/styles.css' },
	})

	local prices = result.apiData.uex_prices
	local hasPrices = type(prices) == 'table' and #prices > 0

	local summary = renderSummary(buildSummaryRows(args, result.apiData, prices))

	local shopFooter = 'Data from [https://uexcorp.space UEX Corp]'

	local shopCard = collapsibleCard.render({
		title = 'Shop availability',
		description = hasPrices and buildShopTerminalsDescription(prices) or 'No shop data in UEX',
		content = hasPrices and renderShopTerminalTable(prices) or nil,
		footer = shopFooter,
	})

	return styles .. summary .. shopCard
end

return p
