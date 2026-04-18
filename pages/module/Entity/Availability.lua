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

--- @param prices table[]
--- @return string
local function renderShopTerminalTable(prices)
	local rows = {}
	for _, entry in ipairs(prices) do
		table.insert(rows, {
			entry.terminal_name,
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
--- collapses input variations to this three-state logic.
---
--- @param value boolean|nil
--- @return string
local function formatAcquirabilityStatus(value)
	if value == true then
		return 'Yes'
	end
	if value == false then
		return 'No'
	end
	return 'Unknown'
end

--- If arg is true/false, honours the arg (editor override). Otherwise
--- falls back to the apiValue (when it's a boolean) or nil (unknown).
---
--- @param arg string|nil
--- @param apiValue boolean|nil
--- @return boolean|nil
local function resolveAcquirability(arg, apiValue)
	local override = yesno(arg)
	if override ~= nil then
		return override
	end
	if type(apiValue) == 'boolean' then
		return apiValue
	end
	return nil
end

--- Builds the ordered list of acquirability rows. "Can craft" pulls from
--- apiData.is_craftable (with an optional args.canCraft override); the
--- other flags are editor-supplied because no API source currently
--- reports them reliably.
---
--- @param args table
--- @param apiData table
--- @return { label: string, value: boolean|nil }[]
local function buildAcquirabilityRows(args, apiData)
	return {
		{ label = 'Can buy', value = yesno(args.canBuy) },
		{ label = 'Can rent', value = yesno(args.canRent) },
		{ label = 'Can loot', value = yesno(args.canLoot) },
		{ label = 'Can pledge', value = yesno(args.canPledge) },
		{ label = 'Can craft', value = resolveAcquirability(args.canCraft, apiData.is_craftable) },
	}
end

--- Renders the acquirability rows as a label/value list. Always shows
--- every row (with "Unknown" as default) so the layout stays stable
--- across pages regardless of what data is available.
---
--- @param rows { label: string, value: boolean|nil }[]
--- @return string
local function renderAcquirabilitySummary(rows)
	local root = mw.html.create('dl'):addClass('t-entity-availability-acquirability')
	for _, row in ipairs(rows) do
		local rowHtml = root:tag('div'):addClass('t-entity-availability-acquirability-row')
		rowHtml:tag('dt'):addClass('t-entity-availability-acquirability-label'):wikitext(row.label)
		rowHtml
			:tag('dd')
			:addClass('t-entity-availability-acquirability-value')
			:wikitext(formatAcquirabilityStatus(row.value))
	end
	return tostring(root)
end

--- Main entry point. Renders two cards:
---   1. Acquirability summary (static) — editor-supplied yes/no flags
---      for can buy / rent / loot / pledge. Default Unknown.
---   2. Shop availability (collapsible) — UEX shop terminal prices, or
---      a static "no data" notice when UEX hasn't indexed the item.
--- Each card stands on its own so future sibling cards (loot table,
--- crafting recipes, etc.) can drop in alongside without reshuffling.
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

	local acquirabilityCard = collapsibleCard.render({
		title = 'Acquirability',
		content = renderAcquirabilitySummary(buildAcquirabilityRows(args, result.apiData)),
		collapsible = false,
	})

	local shopFooter = 'Data from [https://uexcorp.space UEX Corp]'
	local prices = result.apiData.uex_prices
	local hasPrices = type(prices) == 'table' and #prices > 0

	local shopCard = collapsibleCard.render({
		title = 'Shop availability',
		description = hasPrices and buildShopTerminalsDescription(prices) or 'No shop data in UEX',
		content = hasPrices and renderShopTerminalTable(prices) or nil,
		footer = shopFooter,
	})

	return styles .. acquirabilityCard .. shopCard
end

return p
