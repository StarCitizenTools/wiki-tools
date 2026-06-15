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
local statFormat = require('Module:Entity/StatFormat')
local rangeBar = require('Module:RangeBar')
local meterBar = require('Module:MeterBar')

local p = {}

-- Ice–fire gradient: cold cyan -> near-white neutral -> hot orange-red, in domain
-- units. Fixed hex so the palette reads identically across themes. (Axis bounds and
-- units live in Module:Entity/StatFormat; only the palette is temperature-specific.)
local TEMPERATURE_STOPS = {
	{ at = -250, color = '#2bd0e6' },
	{ at = 0, color = '#eef3f6' },
	{ at = 250, color = '#ff5630' },
}

--- Reads a temperature block ({min,max}, falling back to {minimum,maximum}) and
--- returns its survivable bounds. Returns nil when a bound is missing or the range
--- is a meaningless 0–0 (a garment with no thermal rating), so the row collapses.
---
--- @param temp table|nil
--- @return number|nil min
--- @return number|nil max
local function temperatureBounds(temp)
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
	return min, max
end

--- Formats a temperature value with a typographic minus on negatives ("−77", "0").
---
--- @param v number
--- @return string
local function numLabel(v)
	return v < 0 and '−' .. format.formatNum(-v) or format.formatNum(v)
end

--- Formats the g-force modifier with an explicit sign ("+1", "−0.5"), coloured by
--- sign: a positive value is a bonus (success), a negative one a high-g penalty
--- (destructive).
---
--- @param v number
--- @return string
local function gforceLabel(v)
	return format.colorBySign((v < 0 and '−' or '+') .. format.formatNum(math.abs(v)), v)
end

--- Renders the survivable temperature range as a labeled RangeBar, with a 0 °C
--- reference tick line. Axis bounds + unit come from Module:Entity/StatFormat; the
--- header value is the range ("−75 – 105 °C", en dash). Returns nil when there is
--- no usable range.
---
--- @param temp table|nil
--- @return string|nil
local function temperatureBar(temp)
	local min, max = temperatureBounds(temp)
	if min == nil then
		return nil
	end
	local scale = statFormat.get('temperature')
	return rangeBar.render({
		label = 'Temperature',
		value = numLabel(min) .. ' – ' .. numLabel(max) .. ' ' .. scale.unit,
		min = min,
		max = max,
		domain = { min = scale.min, max = scale.max },
		stops = TEMPERATURE_STOPS,
		tick = 0,
	})
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

	-- Each bar is its own full-width, label-less graph item; the section's item
	-- list owns the spacing. G-force stays a plain label:value item.
	local function graphItem(content)
		if content then
			table.insert(items, { content = content, class = 't-infobox-item--block' })
		end
	end

	graphItem(temperatureBar(apiData.temperature_resistance))

	local rad = apiData.radiation_resistance
	if type(rad) == 'table' then
		local capacity = tonumber(rad.maximum_radiation_capacity)
		if capacity and capacity > 0 then
			local scale = statFormat.get('radiation_capacity')
			graphItem(meterBar.render({
				label = 'Radiation capacity',
				value = capacity,
				max = scale.max,
				text = format.formatNum(capacity) .. ' ' .. scale.unit,
			}))
		end
		local dissipation = tonumber(rad.radiation_dissipation_rate)
		if dissipation and dissipation > 0 then
			local scale = statFormat.get('radiation_dissipation')
			graphItem(meterBar.render({
				label = 'Radiation dissipation',
				value = dissipation,
				max = scale.max,
				text = format.formatNum(dissipation) .. ' ' .. scale.unit,
			}))
		end
	end

	local gforce = tonumber(apiData.gforce_resistance)
	if gforce and gforce ~= 0 then
		table.insert(items, { label = 'G-force', content = gforceLabel(gforce) })
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
	temperatureBounds = temperatureBounds,
	numLabel = numLabel,
	gforceLabel = gforceLabel,
}

return p
