require('strict')

--- @module Entity/Commodity/Trade
--- Body renderer: trade prices from uex_prices (when populated) plus an
--- always-present external link to sc-trade.tools. Consumes Module:Entity/Data.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')

local p = {}

--- @param uex table|nil
--- @return table[] rows of { location, action, price }
local function flattenPrices(uex)
	local rows = {}
	if type(uex) ~= 'table' then
		return rows
	end
	for _, entry in ipairs(uex.purchase or {}) do
		rows[#rows + 1] = { location = entry.location, action = 'buy', price = entry.price }
	end
	for _, entry in ipairs(uex.sale or {}) do
		rows[#rows + 1] = { location = entry.location, action = 'sell', price = entry.price }
	end
	return rows
end

--- @param frame table
--- @return string
function p.render(frame)
	local result = data.get(data.parseArgs(frame))
	local rec = result.apiData._refinedRecord or result.apiData
	local name = result.apiData.name or rec.name or mw.title.getCurrentTitle().text

	local out = {}
	local rows = flattenPrices(rec.uex_prices)
	if #rows > 0 then
		local tbl = mw.html.create('table'):addClass('wikitable sortable')
		local head = tbl:tag('tr')
		head:tag('th'):wikitext('Location')
		head:tag('th'):wikitext('Action')
		head:tag('th'):wikitext('Price')
		for _, r in ipairs(rows) do
			local tr = tbl:tag('tr')
			tr:tag('td'):wikitext(r.location or '')
			tr:tag('td'):wikitext(r.action)
			tr:tag('td'):wikitext(r.price and tostring(r.price) or '')
		end
		out[#out + 1] = collapsibleCard.render({
			title = 'Trade prices',
			description = #rows .. (#rows == 1 and ' terminal' or ' terminals'),
			content = tostring(tbl),
		})
	end

	local url = 'https://sc-trade.tools/commodities/' .. mw.uri.encode(name, 'PATH')
	out[#out + 1] = mw.getCurrentFrame():expandTemplate({
		title = 'Note',
		args = { '[' .. url .. ' Search ' .. name .. ' on SC Trade Tools] for live trade data.' },
	})
	return table.concat(out, '\n')
end

p._internal = { flattenPrices = flattenPrices }

return p
