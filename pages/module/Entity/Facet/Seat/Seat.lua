require('strict')

--- @module Entity/Facet/Seat
--- Seat facet. Any item carrying a `seat` block (manned turrets, and — once
--- migrated — cockpit / pilot seats) gets its traverse limits and ejection
--- capability surfaced: the yaw / pitch range the seated operator can aim
--- through, shown as a degree range, plus whether the seat ejects. Data-driven:
--- appears whenever a `seat` block is present, regardless of the owning kind /
--- subtype (the seat key sits on TurretBase / manned turrets, not the remote
--- Turret subtype).

local format = require('Module:Entity/Format')

local p = {}

--- Data-driven match: presence of the `seat` block.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.seat) == 'table'
end

--- Formats a {min, max} axis as a signed degree range ("−20° — 20°"). Reads the
--- `min`/`max` pair (falling back to `minimum`/`maximum`). Returns nil when either
--- bound is non-numeric so the row collapses. The em dash separator stays clear
--- of the typographic minus on negative bounds.
---
--- @param axis table|nil
--- @return string|nil
local function formatRange(axis)
	if type(axis) ~= 'table' then
		return nil
	end
	local min = tonumber(axis.min)
	if min == nil then
		min = tonumber(axis.minimum)
	end
	local max = tonumber(axis.max)
	if max == nil then
		max = tonumber(axis.maximum)
	end
	if min == nil or max == nil then
		return nil
	end
	return format.formatNum(min) .. '° — ' .. format.formatNum(max) .. '°'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local seat = apiData.seat
	if type(seat) ~= 'table' then
		return {}
	end

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Yaw', formatRange(seat.yaw))
	push('Pitch', formatRange(seat.pitch))
	if type(seat.has_ejection) == 'boolean' then
		push('Ejection seat', seat.has_ejection and 'Yes' or 'No')
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'seat',
			label = 'Seat',
			collapsible = true,
			items = items,
		},
	}
end

--- Seat facets for structured data / query: the yaw / pitch traverse as both a
--- formatted display range (`Yaw` / `Pitch`, for the type index table) and the
--- raw numeric bounds (`Yaw min` … for numeric queries). has_ejection is rendered
--- in the section but kept out of the query layer for now — booleans aren't yet
--- used as Entity facets.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local seat = apiData.seat
	if type(seat) ~= 'table' then
		return {}
	end
	local yawAxis = type(seat.yaw) == 'table' and seat.yaw or {}
	local pitchAxis = type(seat.pitch) == 'table' and seat.pitch or {}
	return {
		yaw = formatRange(seat.yaw),
		pitch = formatRange(seat.pitch),
		yaw_min = tonumber(yawAxis.min) or tonumber(yawAxis.minimum),
		yaw_max = tonumber(yawAxis.max) or tonumber(yawAxis.maximum),
		pitch_min = tonumber(pitchAxis.min) or tonumber(pitchAxis.minimum),
		pitch_max = tonumber(pitchAxis.max) or tonumber(pitchAxis.maximum),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatRange = formatRange,
}

return p
