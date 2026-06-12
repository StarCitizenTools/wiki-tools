require('strict')

--- @module Entity/Item/JumpModule
--- Jump module subtype (API type "JumpDrive"). A module attached to a quantum
--- drive that lets a ship navigate jump points between star systems. The
--- Component facet renders the shared hardware stats off the durability block;
--- this adds the jump-tunnel rows — alignment rate, tuning rate — and the fuel
--- usage multiplier.

local format = require('Module:Entity/Format')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local jump = apiData.jump_drive
	if type(jump) ~= 'table' then
		return {}
	end

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Alignment rate', jump.alignment_rate and format.formatNum(jump.alignment_rate))
	push('Tuning rate', jump.tuning_rate and format.formatNum(jump.tuning_rate))
	push(
		'Fuel usage multiplier',
		jump.fuel_usage_efficiency_multiplier and (format.formatNum(jump.fuel_usage_efficiency_multiplier) .. '×')
	)

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'jump_module',
			label = 'Jump module',
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local jump = apiData.jump_drive
	if type(jump) ~= 'table' then
		return {}
	end
	return {
		jump_alignment_rate = tonumber(jump.alignment_rate),
		jump_tuning_rate = tonumber(jump.tuning_rate),
		jump_fuel_usage_multiplier = tonumber(jump.fuel_usage_efficiency_multiplier),
	}
end

return p
