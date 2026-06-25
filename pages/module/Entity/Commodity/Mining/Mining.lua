require('strict')

--- @module Entity/Commodity/Mining
--- Pure mining-stat helpers for the Commodity kind: the acquisition label
--- (kind + raw `methods` → "Ship mining" / "Harvesting" / etc), the
--- laser-mining test, and the quality range. No I/O — split out of
--- Module:Entity/Commodity so the kind module keeps only its contract + hooks.

local p = {}

local tableLua = require('Module:TableLua')
local collapsibleCard = require('Module:CollapsibleCard')

local KIND_VERBS = { mineable = 'mining', harvestable = 'harvesting', salvage = 'salvage' }

-- API `methods` tokens → display label. `Harvestable` is intentionally absent:
-- it merely restates the harvesting verb, so it's dropped (a harvestable then
-- reads as plain "Harvesting"). Unknown tokens pass through unchanged.
local METHOD_LABELS = { ['Ship'] = 'Ship', ['FPS'] = 'FPS', ['Ground Vehicle'] = 'Vehicle' }

-- Methods that use the laser-mining minigame, where signature / instability /
-- resistance are meaningful. FPS and harvestable acquisition don't, so those
-- stats (all zero / nil there) are suppressed for them.
local LASER_METHODS = { ['Ship'] = true, ['Ground Vehicle'] = true }

--- Acquisition label from kind + the raw record's `methods` list, e.g.
--- "Ship mining", "FPS mining", "Vehicle mining", "Harvesting". All methods are
--- joined (commodities are single-method today, but the data permits more).
---
--- @param raw table|nil
--- @param kind string|nil
--- @return string|nil
function p.acquisitionLabel(raw, kind)
	if not kind or kind == 'remains' then
		return nil
	end
	local verb = KIND_VERBS[kind] or kind
	local labels = {}
	for _, m in ipairs(raw and raw.methods or {}) do
		local label = METHOD_LABELS[m] or (m ~= 'Harvestable' and m or nil)
		if label then
			labels[#labels + 1] = label
		end
	end
	if #labels > 0 then
		return table.concat(labels, ', ') .. ' ' .. verb
	end
	return verb:gsub('^%l', string.upper)
end

--- @param raw table|nil
--- @return boolean
function p.isLaserMining(raw)
	for _, m in ipairs(raw and raw.methods or {}) do
		if LASER_METHODS[m] then
			return true
		end
	end
	return false
end

--- Min/max quality across the raw record's locations, as "min–max".
--- @param raw table|nil
--- @return string|nil
function p.qualityRange(raw)
	local locs = raw and raw.locations
	if type(locs) ~= 'table' or not locs[1] then
		return nil
	end
	local lo, hi
	for _, l in ipairs(locs) do
		if l.quality_min and (not lo or l.quality_min < lo) then
			lo = l.quality_min
		end
		if l.quality_max and (not hi or l.quality_max > hi) then
			hi = l.quality_max
		end
	end
	if not lo or not hi then
		return nil
	end
	return tostring(lo) .. '–' .. tostring(hi)
end

--- Groups a commodity's raw mining `locations[]` by star system, in first-seen
--- order, normalizing each entry to the cells the Mining table renders. Safe on
--- nil / non-table input (returns {}).
--- @param locations table[]|nil
--- @return table[] groups of { system, rows = { { body, type, spawn_pct, quality } } }
function p.groupBySystem(locations)
	local order, bySystem = {}, {}
	if type(locations) ~= 'table' then
		return {}
	end
	for _, l in ipairs(locations) do
		local sys = l.system or 'Unknown'
		if not bySystem[sys] then
			bySystem[sys] = { system = sys, rows = {} }
			order[#order + 1] = sys
		end
		local quality = nil
		if l.quality_min and l.quality_max then
			quality = tostring(l.quality_min) .. '–' .. tostring(l.quality_max)
		end
		table.insert(bySystem[sys].rows, {
			body = l.display_name or l.name,
			type = l.type,
			spawn_pct = l.relative_probability_percent,
			quality = quality,
		})
	end
	local groups = {}
	for _, sys in ipairs(order) do
		groups[#groups + 1] = bySystem[sys]
	end
	return groups
end

--- Renders the commodity Mining card: the raw record's deposit `locations[]`,
--- one sortable table per star system inside a single collapsible card. Returns
--- nil when there are no locations.
--- @param raw table|nil
--- @return string|nil
function p.renderMiningCard(raw)
	local groups = p.groupBySystem(raw and raw.locations)
	if #groups == 0 then
		return nil
	end

	local parts, total = {}, 0
	for _, g in ipairs(groups) do
		local rows = {}
		for _, r in ipairs(g.rows) do
			rows[#rows + 1] = {
				r.body or '-',
				r.type or '-',
				r.spawn_pct and (tostring(r.spawn_pct) .. '%') or '-',
				r.quality or '-',
			}
		end
		total = total + #g.rows
		parts[#parts + 1] = tableLua.render({
			caption = g.system,
			class = 'wikitable--fluid',
			columns = {
				{ id = 'body', label = 'Body', textAlign = 'start' },
				{ id = 'type', label = 'Type', textAlign = 'start' },
				{ id = 'spawn', label = 'Spawn %', textAlign = 'number' },
				{ id = 'quality', label = 'Quality', textAlign = 'end' },
			},
			data = rows,
		})
	end

	local depositLabel = total == 1 and '1 deposit' or (total .. ' deposits')
	local systemLabel = #groups == 1 and '1 system' or (#groups .. ' systems')

	local kind = raw.kind
	local title = p.acquisitionLabel(raw, kind) or (kind == 'remains' and 'Collection') or 'Mining'
	local icon = kind == 'harvestable' and '🌿' or '⛏️'

	return collapsibleCard.render({
		title = '<span aria-hidden="true">' .. icon .. '</span> ' .. title,
		description = depositLabel .. ' · ' .. systemLabel,
		content = table.concat(parts, '\n'),
	})
end

return p
