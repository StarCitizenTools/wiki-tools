require('strict')

--- @module Entity/Vehicle/Cost
--- Vehicle Cost sub-builder: three keyless subsection tabs — Universe
--- (estimated in-game buy/rent prices from UEX, latest patch), Pledge
--- (standalone/warbond/availability/loaner), and Insurance.

local format = require('Module:Entity/Format')
local productionStatus = require('Module:Entity/ProductionStatus')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local uec = require('Module:UEC')
local Util = require('Module:Entity/Facet/Util')
local yesno = require('Module:Yesno')

local p = {}

--- All maximal digit runs in a version string as a numeric vector, so versions
--- compare component-wise (4.10 > 4.8) rather than lexicographically (where the
--- string "4.8" sorts after "4.10"). The trailing build number becomes the last,
--- tie-breaking component. e.g. "4.10.0-LIVE.100" → { 4, 10, 0, 100 }.
--- @param version string
--- @return number[]
local function versionVector(version)
	local v = {}
	for digits in version:gmatch('%d+') do
		v[#v + 1] = tonumber(digits)
	end
	return v
end

--- True when version vector `a` is strictly newer than `b`, compared
--- component-wise (missing components count as 0).
--- @param a number[]
--- @param b number[]
--- @return boolean
local function versionNewer(a, b)
	for i = 1, math.max(#a, #b) do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then
			return x > y
		end
	end
	return false
end

--- The newest `game_version` present across price rows, or nil when none carry
--- one (older UEX records that predate version stamping).
--- @param rows table[]
--- @return string|nil
local function latestVersion(rows)
	local best, bestVec
	for _, row in ipairs(rows) do
		local gv = row.game_version
		if type(gv) == 'string' and gv ~= '' then
			local vec = versionVector(gv)
			if not best or versionNewer(vec, bestVec) then
				best, bestVec = gv, vec
			end
		end
	end
	return best
end

--- Non-zero numeric prices at `key`, restricted to rows matching `version` when
--- given (nil → every row). Skips UEX zero-sentinels.
--- @param rows table[]
--- @param key string
--- @param version string|nil
--- @return number[]
local function collectPrices(rows, key, version)
	local out = {}
	for _, row in ipairs(rows) do
		if version == nil or row.game_version == version then
			local v = tonumber(row[key])
			if v and v > 0 then
				out[#out + 1] = v
			end
		end
	end
	return out
end

--- Median of a numeric list, rounded to the nearest integer (prices are whole
--- aUEC); even counts average the middle pair. nil for an empty list. Median over
--- mean resists a single mispriced terminal; with the common 1–2 terminal case
--- the two coincide.
--- @param values number[]
--- @return number|nil
local function median(values)
	local n = #values
	if n == 0 then
		return nil
	end
	table.sort(values)
	local m
	if n % 2 == 1 then
		m = values[(n + 1) / 2]
	else
		m = (values[n / 2] + values[n / 2 + 1]) / 2
	end
	return math.floor(m + 0.5)
end

--- Estimated in-game price at `key` (price_buy / price_rent): the median across
--- the newest patch's terminals, falling back to all patches when the newest
--- carries no usable price for this side. nil when there is no non-zero price.
--- @param rows table[]|nil
--- @param key string
--- @return number|nil
local function estimatePrice(rows, key)
	if type(rows) ~= 'table' or rows[1] == nil then
		return nil
	end
	local version = latestVersion(rows)
	local values = collectPrices(rows, key, version)
	if #values == 0 and version ~= nil then
		values = collectPrices(rows, key, nil) -- newest patch lacks this side → any patch
	end
	return median(values)
end

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

	local estimate = estimatePrice(rows, key)
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
	sectionBuilder.push(universe, 'Buy', universeCell(args.canbuy, uex.purchase, 'price_buy', flightReady))
	sectionBuilder.push(universe, 'Rent', universeCell(args.canrent, uex.rental, 'price_rent', flightReady))

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
