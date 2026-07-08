require('strict')

--- @module Entity/Vehicle/Cost
--- Vehicle Cost sub-builder: three keyless subsection tabs — Universe
--- (estimated in-game buy/rent prices from UEX, latest patch), Pledge
--- (standalone/warbond/availability/loaner), and Insurance.

local acq = require('Module:Entity/Acquisition')
local format = require('Module:Entity/Format')
local productionStatus = require('Module:Entity/ProductionStatus')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local uec = require('Module:UEC')
local Util = require('Module:Entity/Facet/Util')
local yesno = require('Module:Yesno')

local p = {}

--- A Universe acquisition cell. An editorial `canX=no` override is a hard "No";
--- otherwise show the estimated UEC price (prefixed "~" — it is a cross-terminal
--- market estimate, not a fixed price). With no price: `canX=yes` → "Yes"; a
--- flight-ready ship, or one with market data but none for this side, → definitive
--- "No"; an unreleased ship with no data at all → nil (row drops, Unknown).
--- @param override string|nil
--- @param rows table[]|nil
--- @param key string
--- @param flightReady boolean
--- @return string|nil
local function universeCell(override, rows, key, flightReady)
	local overrideFlag = nil
	if override ~= nil and override ~= '' then
		overrideFlag = yesno(override) -- explicit: `x and yesno() or nil` would lose a false result
	end
	if overrideFlag == false then
		return 'No'
	end

	local estimate = acq.estimatePrice(rows, key)
	if estimate ~= nil then
		return '~' .. uec._main(estimate)
	end

	if overrideFlag == true then
		return 'Yes'
	end
	if (type(rows) == 'table' and rows[1] ~= nil) or flightReady then
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
	sectionBuilder.push(universe, 'Buy', universeCell(args.canBuy, uex.purchase, 'price_buy', flightReady))
	sectionBuilder.push(universe, 'Rent', universeCell(args.canRent, uex.rental, 'price_rent', flightReady))

	local pledge = {}
	sectionBuilder.push(
		pledge,
		'Standalone',
		pledgeCell(ed:value('pledge_price', apiData.msrp), ed:value('original_pledge_price'))
	)
	sectionBuilder.push(pledge, 'Warbond', pledgeCell(ed:value('warbond_price'), ed:value('original_warbond_price')))
	-- Lore-only vehicles were never for sale, so pledge availability is moot — skip it.
	if productionStatus.key(effectiveState) ~= 'loreonly' then
		sectionBuilder.push(pledge, 'Availability', ed:value('pledge_availability'))
	end
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
