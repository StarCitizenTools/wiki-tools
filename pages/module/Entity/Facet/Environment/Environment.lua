require('strict')

--- @module Entity/Facet/Environment
--- Environment facet. Every wearable (armor or clothing) carries the environmental
--- protection blocks the suit provides: `temperature_resistance` (the survivable
--- temperature range), `radiation_resistance` (capacity + dissipation rate), and
--- `gforce_resistance`. This facet surfaces whichever are meaningful. Data-driven:
--- fires on any entity with a `temperature_resistance` block (the universal wearable
--- signal). Clothing shows only the temperature row; armor lights up radiation and
--- g-force too.

local format = require('Module:Entity/Format')

local p = {}

--- Reads a temperature block ({min,max}, falling back to {minimum,maximum}) and
--- formats it as a degree-Celsius range ("−75 °C — 105 °C"). Returns nil when a
--- bound is missing or the range is a meaningless 0–0 (a garment with no thermal
--- rating), so the row collapses. The em dash separator stays clear of the
--- typographic minus on negative bounds (matches the Seat facet).
---
--- @param temp table|nil
--- @return string|nil
local function formatTemperature(temp)
	if type(temp) ~= 'table' then
		return nil
	end
	local min = tonumber(temp.min)
	if min == nil then
		min = tonumber(temp.minimum)
	end
	local max = tonumber(temp.max)
	if max == nil then
		max = tonumber(temp.maximum)
	end
	if min == nil or max == nil then
		return nil
	end
	if min == 0 and max == 0 then
		return nil
	end
	return format.formatNum(min) .. ' °C — ' .. format.formatNum(max) .. ' °C'
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.temperature_resistance) == 'table'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Temperature', formatTemperature(apiData.temperature_resistance))

	local rad = apiData.radiation_resistance
	if type(rad) == 'table' then
		local capacity = tonumber(rad.maximum_radiation_capacity)
		if capacity and capacity > 0 then
			push('Radiation capacity', format.formatNum(capacity))
		end
		local dissipation = tonumber(rad.radiation_dissipation_rate)
		if dissipation and dissipation > 0 then
			push('Radiation dissipation', format.formatNum(dissipation))
		end
	end

	local gforce = tonumber(apiData.gforce_resistance)
	if gforce and gforce ~= 0 then
		push('G-force resistance', format.formatNum(gforce))
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'environment',
			label = 'Environment',
			collapsible = true,
			items = items,
		},
	}
end

--- Contributes environmental-protection facets for querying: the temperature
--- bounds, radiation capacity / dissipation, and g-force resistance. Each is
--- omitted when absent or non-meaningful (temperature only when not a 0–0 range;
--- radiation only when positive; g-force only when non-zero) so the stored set —
--- and the slot index columns — stay clean.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local data = {}

	local temp = apiData.temperature_resistance
	if type(temp) == 'table' then
		local min = tonumber(temp.min) or tonumber(temp.minimum)
		local max = tonumber(temp.max) or tonumber(temp.maximum)
		if not (min == 0 and max == 0) then
			data.minimum_temperature = min
			data.maximum_temperature = max
		end
	end

	local rad = apiData.radiation_resistance
	if type(rad) == 'table' then
		local capacity = tonumber(rad.maximum_radiation_capacity)
		if capacity and capacity > 0 then
			data.radiation_capacity = capacity
		end
		local dissipation = tonumber(rad.radiation_dissipation_rate)
		if dissipation and dissipation > 0 then
			data.radiation_dissipation = dissipation
		end
	end

	local gforce = tonumber(apiData.gforce_resistance)
	if gforce and gforce ~= 0 then
		data.g_force_resistance = gforce
	end

	return data
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatTemperature = formatTemperature,
}

return p
