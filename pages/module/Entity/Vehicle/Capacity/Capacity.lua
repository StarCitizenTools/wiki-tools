require('strict')

--- @module Entity/Vehicle/Capacity
--- Vehicle Capacity sub-builder: Stats-style tabs. An Overview tab carries the
--- headline (crew / cargo / inventory / ore); Cargo and Crew detail tabs drill
--- down and drop out when a ship has nothing extra, so plain ships render flat —
--- the three-row view this section had before tabs.

local boolean = require('Module:Boolean')
local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

-- Multiplication sign (U+00D7) with surrounding spaces, e.g. "2 × T1", "2.5 × 5 m".
local TIMES = ' \195\151 '

-- Emergency-egress Overview row (ejection seat / escape pod) is gated OFF for now:
-- the API's `ejection_seats` / `escape_pods` data is currently unreliable. The
-- determination logic and its render below are retained; flip this to true to
-- re-enable once the upstream data is trustworthy.
local EGRESS_ENABLED = false

--- Crew as "min–max" (en dash) or a single value. nil when neither present.
--- @return string|nil
local function crewRange(minV, maxV)
	minV, maxV = tonumber(minV), tonumber(maxV)
	if minV and maxV and minV ~= maxV then
		return format.formatNum(minV) .. '\226\128\147' .. format.formatNum(maxV)
	end
	if minV or maxV then
		return format.formatNum(minV or maxV)
	end
	return nil
end

--- True when `value` is a number > 0.
--- @return boolean
local function isPositive(value)
	local n = tonumber(value)
	return n ~= nil and n > 0
end

--- Positive-only "<n><unit>" cell (unit may be ''): nil when non-numeric or <= 0.
--- Drops a miner's cargo_capacity of 0 (its hold is ore, not freight) instead of
--- rendering a misleading "0 SCU".
--- @return string|nil
local function positiveUnit(value, unit)
	if not isPositive(value) then
		return nil
	end
	return format.formatNum(tonumber(value)) .. unit
end

--- Medical-bed tier summary from the API's { T1 = n, T2 = m } map, ascending by
--- tier: { T2 = 1 } -> "1 × T2"; { T1 = 2, T2 = 1 } -> "2 × T1, 1 × T2". nil when
--- empty or not a table. (Tiers are single-digit T1–T3, so lexical sort == tier
--- order.)
--- @return string|nil
local function medicalBedText(beds)
	if type(beds) ~= 'table' then
		return nil
	end
	-- Collect string tier keys only ("T1", "T2", …); skipping any stray numeric
	-- key keeps table.sort from comparing mixed types.
	local tiers = {}
	for tier in pairs(beds) do
		if type(tier) == 'string' then
			tiers[#tiers + 1] = tier
		end
	end
	if tiers[1] == nil then
		return nil
	end
	table.sort(tiers)
	local parts = {}
	for _, tier in ipairs(tiers) do
		local count = tonumber(beds[tier])
		if count and count > 0 then
			parts[#parts + 1] = format.formatNum(count) .. TIMES .. tier
		end
	end
	return parts[1] and table.concat(parts, ', ') or nil
end

--- Weapon-rack summary from `weapon_storage`: rifle and pistol slot counts on
--- separate lines (the bare total is not useful on its own). nil when neither
--- rifle nor pistol slots are present.
--- @param weaponStorage table|nil
--- @return string|nil
local function weaponRackText(weaponStorage)
	if type(weaponStorage) ~= 'table' then
		return nil
	end
	local lines = {}
	if isPositive(weaponStorage.slots_rifle) then
		lines[#lines + 1] = format.formatNum(tonumber(weaponStorage.slots_rifle)) .. ' rifle'
	end
	if isPositive(weaponStorage.slots_pistol) then
		lines[#lines + 1] = format.formatNum(tonumber(weaponStorage.slots_pistol)) .. ' pistol'
	end
	return lines[1] and table.concat(lines, '<br>') or nil
end

--- Split the vehicle's cargo into internal vs external SCU by totalling
--- `cargo_grids`. Each grid instance carries its own `scu` and an `external` flag
--- (true = exposed deck; false/nil = enclosed hold); the API exposes no pre-summed
--- internal/external figure, so we total the grids here. Returns two numbers
--- (0 when absent).
--- @param grids table|nil
--- @return number internalScu
--- @return number externalScu
local function cargoGridSplit(grids)
	local internal, external = 0, 0
	if type(grids) == 'table' then
		for _, grid in ipairs(grids) do
			if type(grid) == 'table' then
				local scu = tonumber(grid.scu) or 0
				if grid.external == true then
					external = external + scu
				else
					internal = internal + scu
				end
			end
		end
	end
	return internal, external
end

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local crew = type(apiData.crew) == 'table' and apiData.crew or {}
	local cargoLimits = type(apiData.cargo_limits) == 'table' and apiData.cargo_limits or {}
	local seating = type(apiData.seating) == 'table' and apiData.seating or {}
	local internalScu, externalScu = cargoGridSplit(apiData.cargo_grids)

	local crewText = crewRange(ed:value('crew_min', crew.min), ed:value('crew_max', crew.max))
	local cargoText = positiveUnit(ed:value('cargo_capacity', apiData.cargo_capacity), ' SCU')
	local inventoryText = positiveUnit(apiData.vehicle_inventory, ' µSCU')
	local oreText = positiveUnit(apiData.ore_capacity, ' SCU')
	local medicalText = medicalBedText(seating.medical_beds)
	local weaponText = weaponRackText(apiData.weapon_storage)
	local medicalTier = type(apiData.max_medical_tier) == 'string'
			and apiData.max_medical_tier ~= ''
			and apiData.max_medical_tier
		or nil
	-- Emergency egress: an ejection seat if the ship has one, else an escape pod.
	-- Shown only when present — a positive highlight, never a "No".
	local ejection = tonumber(seating.ejection_seats)
	local escapePods = tonumber(seating.escape_pods)
	local egressLabel = nil
	if ejection ~= nil and ejection >= 1 then
		egressLabel = 'Ejection seat'
	elseif escapePods ~= nil and escapePods >= 1 then
		egressLabel = 'Escape pod'
	end

	-- Overview: the headline (the pre-tabs view, plus Ore for miners).
	local overview = {}
	sectionBuilder.push(overview, 'Crew', crewText)
	sectionBuilder.push(overview, 'Cargo', cargoText)
	sectionBuilder.push(overview, 'Inventory', inventoryText)
	sectionBuilder.push(overview, 'Ore', oreText)
	sectionBuilder.push(overview, 'Max medical', medicalTier)
	if EGRESS_ENABLED and egressLabel ~= nil then
		sectionBuilder.push(overview, egressLabel, boolean.render(true))
	end

	-- Cargo detail: freight drill-down. Internal vs external is totalled from the
	-- per-grid cargo_grids; the unified total stays on the Overview tab.
	local cargo = {}
	sectionBuilder.push(cargo, 'Internal cargo', positiveUnit(internalScu, ' SCU'))
	sectionBuilder.push(cargo, 'External cargo', positiveUnit(externalScu, ' SCU'))
	sectionBuilder.push(cargo, 'Max container', positiveUnit(cargoLimits.max_scu_box, ' SCU'))
	sectionBuilder.push(cargo, 'Ore hold', oreText)

	-- Crew detail: people & their gear.
	local crewDetail = {}
	sectionBuilder.push(crewDetail, 'Crew', crewText)
	sectionBuilder.push(crewDetail, 'Stations', positiveUnit(seating.crew_stations, ''))
	sectionBuilder.push(crewDetail, 'Beds', positiveUnit(seating.beds, ''))
	sectionBuilder.push(crewDetail, 'Medical bed', medicalText)
	if EGRESS_ENABLED then
		sectionBuilder.push(crewDetail, 'Ejection seats', positiveUnit(seating.ejection_seats, ''))
		sectionBuilder.push(crewDetail, 'Escape pods', positiveUnit(seating.escape_pods, ''))
	end
	sectionBuilder.push(crewDetail, 'Jump seats', positiveUnit(seating.jump_seats, ''))
	sectionBuilder.push(crewDetail, 'Weapon racks', weaponText)

	-- A detail tab renders only on a "rich signal" — otherwise its data already
	-- lives in the Overview headline and a tab would just repeat it.
	local crewMax = tonumber(ed:value('crew_max', crew.max))
	local cargoRich = isPositive(cargoLimits.max_scu_box) or isPositive(apiData.ore_capacity)
	local crewRich = isPositive(seating.beds)
		or medicalText ~= nil
		or (EGRESS_ENABLED and isPositive(seating.escape_pods))
		or isPositive(seating.jump_seats)
		or weaponText ~= nil
		or (isPositive(seating.crew_stations) and crewMax ~= nil and tonumber(seating.crew_stations) > crewMax)

	if cargoRich or crewRich then
		local tabs = {}
		if overview[1] ~= nil then
			tabs[#tabs + 1] = { label = 'Overview', items = overview }
		end
		if cargoRich and cargo[1] ~= nil then
			tabs[#tabs + 1] = { label = 'Cargo', items = cargo }
		end
		if crewRich and crewDetail[1] ~= nil then
			tabs[#tabs + 1] = { label = 'Crew', items = crewDetail }
		end
		-- Two or more tabs → a real tab strip. A single tab (empty Overview plus one
		-- rich detail — e.g. malformed data with no crew/cargo/inventory) would render
		-- a lone tab strip; fall back to that tab's rows as a flat list instead.
		if tabs[2] ~= nil then
			return sectionBuilder.section({ key = 'capacity', label = 'Capacity', sections = tabs })
		end
		if tabs[1] ~= nil then
			return sectionBuilder.section({ key = 'capacity', label = 'Capacity', items = tabs[1].items })
		end
	end

	-- No rich data: the flat three-row view (matching the pre-tabs render).
	return sectionBuilder.section({ key = 'capacity', label = 'Capacity', items = overview })
end

return p
