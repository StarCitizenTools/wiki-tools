require('strict')

--- @module Entity/Vehicle/ClassStats
--- Exposes memoized cohort rows and a percentile helper for the vehicle scoring
--- profile. Fetches and decodes a fixed set of numeric SMW properties for the
--- same-size-class ship cohort with one mw.smw.ask per family|size.
--- Returns nil when comparison is unavailable: no SMW (headless tests),
--- a non-ship family, or a cohort below MIN_COHORT.

local p = {}

--- Stat key to SMW property. Queried with the `#-` plain formatter so values come
--- back unitless. Keys match the stat fields accessed by cohortRows callers (the
--- scoring profile).
local COHORT_PROPS = {
	scm_speed = 'Scm speed',
	max_speed = 'Max speed',
	pitch_rate = 'Pitch rate',
	yaw_rate = 'Yaw rate',
	roll_rate = 'Roll rate',
	health = 'Health point',
	shield_hp = 'Shield health point',
	pilot_dps = 'Pilot DPS',
	turret_dps = 'Turret DPS',
	missile_damage = 'Missile damage',
	pilot_sustained_dps = 'Pilot sustained DPS',
	turret_sustained_dps = 'Turret sustained DPS',
	armor_deflection = 'Armor deflection',
	physical_deflection = 'Physical deflection',
	energy_deflection = 'Energy deflection',
	quantum_speed = 'Quantum speed',
	quantum_range = 'Quantum range',
	quantum_spool_time = 'Quantum spool time',
	quantum_fuel = 'Quantum fuel capacity',
	hydrogen_fuel = 'Hydrogen fuel capacity',
	ir_emission = 'Infrared emission',
	em_emission = 'Electromagnetic emission',
	cross_section = 'Cross section',
}

--- Only ships have a cohort large enough to average; ground/gravlev return nil.
local FAMILY_CATEGORY = { ship = 'Ships' }
local MIN_COHORT = 5

--- Render-local memo for cohortRows, keyed "family|size". Persists across the page's #invoke calls.
local rowCache = {}

--- Coerce an SMW value to a number: HTML-decode (so the nbsp entity "&#160;"
--- does not leak its "160" digits), then strip everything but digits/dot/minus.
--- @param value any
--- @return number|nil
local function decodeNumber(value)
	if type(value) == 'table' then
		value = value[1]
	end
	if type(value) == 'number' then
		return value
	end
	if type(value) ~= 'string' then
		return nil
	end
	return tonumber((mw.text.decode(value, true):gsub('[^%d%.%-]', '')))
end

--- Build the mw.smw.ask query parts for a given category and size class.
--- @param category string  cohort scoping category (e.g. "Ships")
--- @param size number|string  numeric size class
--- @return string[] query parts for mw.smw.ask
local function buildQuery(category, size)
	local queryParts = {
		-- [[:+]] restricts the cohort to main-namespace articles (keeps User:/sandbox
		-- {{Entity}} pages out). After migrating ships it can lag a render or two until
		-- SMW indexes the new pages' namespace data — a forcelinkupdate re-parse of the
		-- cohort pages settles it.
		'[[:+]] [[Category:' .. category .. ']][[Size::' .. tostring(size) .. ']]',
		'mainlabel=-',
		'limit=500',
	}
	for key, prop in pairs(COHORT_PROPS) do
		queryParts[#queryParts + 1] = '?' .. prop .. '#-=' .. key
	end
	return queryParts
end

--- Memoized decoded cohort rows, or nil when comparison is unavailable
--- (no SMW / non-ship family / cohort below MIN_COHORT). Each row is a
--- { stat_key = number } map of the cohort member's stored scoring stats.
--- @param family string
--- @param size number|string|nil
--- @return table[]|nil
function p.cohortRows(family, size)
	if not (mw.smw and mw.smw.ask) then
		return nil
	end
	local category = FAMILY_CATEGORY[family]
	if category == nil or size == nil or size == '' then
		return nil
	end
	local cacheKey = family .. '|' .. tostring(size)
	local entry = rowCache[cacheKey]
	if entry == nil then
		local raw = mw.smw.ask(buildQuery(category, size))
		if type(raw) == 'table' and #raw >= MIN_COHORT then
			local rows = {}
			for _, r in ipairs(raw) do
				local row = {}
				for key in pairs(COHORT_PROPS) do
					local n = decodeNumber(r[key])
					if n ~= nil then
						row[key] = n
					end
				end
				rows[#rows + 1] = row
			end
			entry = { rows = rows }
		else
			entry = { rows = false }
		end
		rowCache[cacheKey] = entry
	end
	return entry.rows or nil
end

--- Hazen-midpoint percentile of `value` within `values`:
--- round(100 * (count(x < value) + 0.5 * count(x == value)) / N). Puts the cohort
--- median at 50, the leader near 100, the floor near 0; ties at a shared value are
--- not inflated. nil for an empty list.
--- @param values number[]
--- @param value number
--- @return number|nil
function p.percentile(values, value)
	local n = #values
	if n == 0 then
		return nil
	end
	local below, equal = 0, 0
	for _, v in ipairs(values) do
		if v < value then
			below = below + 1
		elseif v == value then
			equal = equal + 1
		end
	end
	return math.floor(100 * (below + 0.5 * equal) / n + 0.5)
end

return p
