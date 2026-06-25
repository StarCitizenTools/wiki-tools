require('strict')

--- @module Entity/Vehicle/Cost
--- Vehicle Cost sub-builder: three keyless subsection tabs — Universe
--- (buyable/rentable, linking to {{Entity/Availability}}), Pledge
--- (standalone/warbond/availability/loaner), and Insurance.

local format = require('Module:Entity/Format')
local productionStatus = require('Module:Entity/ProductionStatus')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local uec = require('Module:UEC')
local Util = require('Module:Entity/Facet/Util')
local yesno = require('Module:Yesno')

local p = {}

--- Min–max of non-zero numeric values at `key` across an array, as "lo – hi aUEC"
--- (single value when lo==hi, en dash between). nil when no non-zero entry.
--- @return string|nil
local function priceRange(rows, key)
	if type(rows) ~= 'table' then
		return nil
	end
	local lo, hi
	for _, row in ipairs(rows) do
		local v = tonumber(row[key])
		if v and v > 0 then
			lo = (lo == nil or v < lo) and v or lo
			hi = (hi == nil or v > hi) and v or hi
		end
	end
	if not lo then
		return nil
	end
	if lo == hi then
		return format.formatNum(lo) .. ' aUEC'
	end
	return format.formatNum(lo) .. ' \226\128\147 ' .. format.formatNum(hi) .. ' aUEC' -- en dash
end

--- Whether the vehicle can be acquired (bought/rented) per UEX data: true when a
--- real price exists, false when there are entries but no price for this side,
--- nil (Unknown) when there's no price array to judge from.
--- @return boolean|nil
local function inferCanAcquire(prices, key)
	if type(prices) ~= 'table' or prices[1] == nil then
		return nil
	end
	return priceRange(prices, key) ~= nil
end

--- A Universe acquisition row value: an editorial `canX` override (yes/no) wins,
--- else inferred from UEX prices. "Yes" links to the page's Acquisition section;
--- a flight-ready ship with no price is a definitive "No"; an unreleased ship
--- with no data stays Unknown and the row drops.
--- @return string|nil
local function acquireRow(override, prices, key, flightReady)
	local flag = nil
	if override ~= nil and override ~= '' then
		flag = yesno(override)
	end
	if flag == nil then
		flag = inferCanAcquire(prices, key)
	end
	if flag == nil and flightReady then
		flag = false
	end
	if flag == true then
		return '[[#Acquisition|Yes]]'
	elseif flag == false then
		return 'No'
	end
	return nil
end

--- A pledge price cell: "$N", with " (was $M)" appended when an original differs. nil when no current.
--- @return string|nil
local function pledgeCell(current, original)
	local c = tonumber(current)
	if c == nil then
		return nil
	end
	local s = '$' .. format.formatNum(c)
	local o = tonumber(original)
	if o and o ~= c then
		s = s .. ' (was $' .. format.formatNum(o) .. ')'
	end
	return s
end

--- A UEC amount rendered via Module:UEC (currency glyph + grouped number), nil
--- when the value isn't numeric.
--- @return string|nil
local function uecAmount(value)
	local n = tonumber(value)
	return n and uec._main(n) or nil
end

--- Loaner ships as a comma-joined wikilink list, or nil. Suppressed for
--- flight-ready ships (implemented → no loaner granted even when the API still
--- returns stale loaner data).
--- @param apiData table
--- @param state any  effective production state
--- @return string|nil
local function loanerList(apiData, state)
	if productionStatus.key(state) == 'flightready' then
		return nil
	end
	local loaner = apiData.loaner
	if type(loaner) ~= 'table' or loaner[1] == nil then
		return nil
	end
	local links = {}
	for _, entry in ipairs(loaner) do
		if type(entry) == 'table' and type(entry.name) == 'string' and entry.name ~= '' then
			links[#links + 1] = '[[' .. entry.name .. ']]'
		end
	end
	return links[1] and table.concat(links, ', ') or nil
end

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local uex = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local insurance = type(apiData.insurance) == 'table' and apiData.insurance or {}

	local effectiveState = ed:value('production_state', apiData.production_status)
	local flightReady = productionStatus.key(effectiveState) == 'flightready'
	local universe = {}
	sectionBuilder.push(universe, 'Buyable', acquireRow(args.canbuy, uex.purchase, 'price_buy', flightReady))
	sectionBuilder.push(universe, 'Rentable', acquireRow(args.canrent, uex.rental, 'price_rent', flightReady))

	local pledge = {}
	sectionBuilder.push(
		pledge,
		'Standalone',
		pledgeCell(ed:value('pledge_price', apiData.msrp), ed:value('original_pledge_price'))
	)
	sectionBuilder.push(pledge, 'Warbond', pledgeCell(ed:value('warbond_price'), ed:value('original_warbond_price')))
	sectionBuilder.push(pledge, 'Availability', ed:value('pledge_availability'))
	sectionBuilder.push(pledge, 'Loaner', loanerList(apiData, effectiveState))

	local insuranceItems = {}
	sectionBuilder.push(insuranceItems, 'Claim time', Util.withUnit(insurance.claim_time, ' min'))
	sectionBuilder.push(insuranceItems, 'Expedite time', Util.withUnit(insurance.expedite_time, ' min'))
	sectionBuilder.push(insuranceItems, 'Expedite fee', uecAmount(insurance.expedite_cost))

	-- Subsection tabs are raw InfoboxLua section data ({ label, items }) with NO
	-- `key` — a keyed subsection fails InfoboxLua's schema validation.
	local costTabs = {}
	if universe[1] ~= nil then
		costTabs[#costTabs + 1] = { label = 'Universe', items = universe }
	end
	if pledge[1] ~= nil then
		costTabs[#costTabs + 1] = { label = 'Pledge', items = pledge }
	end
	if insuranceItems[1] ~= nil then
		costTabs[#costTabs + 1] = { label = 'Insurance', items = insuranceItems }
	end
	return costTabs[1] and sectionBuilder.section({ key = 'cost', label = 'Cost', sections = costTabs }) or nil
end

return p
