require('strict')

--- @module Entity/Availability
--- Renders where an entity can be acquired in-game. Currently limited to
--- shop terminals sourced from apiData.uex_prices. Consumes
--- Module:Entity/Data so it shares Apiunto's cache with other Entity
--- templates on the page.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')
local tableLua = require('Module:TableLua')

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

--- Average of non-zero numeric entries for `key`. Excludes zeros because
--- UEX uses 0 to signal "not sold here" — including them would pull the
--- average down and misrepresent the actual price players see.
---
--- @param prices table[]
--- @param key string
--- @return number|nil
local function averagePrice(prices, key)
	local sum = 0
	local count = 0
	for _, entry in ipairs(prices) do
		local p = entry[key]
		if type(p) == 'number' and p > 0 then
			sum = sum + p
			count = count + 1
		end
	end
	if count == 0 then
		return nil
	end
	return math.floor(sum / count + 0.5)
end

--- Builds the card's description line: "N locations · avg buy X · avg
--- sell X". Averages show "-" when no non-zero prices exist on that side
--- of the market.
---
--- @param prices table[]
--- @return string
local function buildShopTerminalsDescription(prices)
	local locationCount = #prices
	local locationLabel = locationCount == 1 and '1 location' or (locationCount .. ' locations')
	local avgBuy = averagePrice(prices, 'price_buy')
	local avgSell = averagePrice(prices, 'price_sell')
	return table.concat({
		locationLabel,
		'avg buy ' .. (avgBuy and tostring(avgBuy) or '-'),
		'avg sell ' .. (avgSell and tostring(avgSell) or '-'),
	}, ' · ')
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

--- Main entry point. Returns an empty string when the API has no
--- availability data so the template can be dropped on any page safely.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local prices = result.apiData.uex_prices
	if type(prices) ~= 'table' or #prices == 0 then
		return ''
	end

	return collapsibleCard.render({
		title = 'Shop terminals',
		description = buildShopTerminalsDescription(prices),
		content = renderShopTerminalTable(prices),
	})
end

return p
