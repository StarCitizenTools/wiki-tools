require('strict')

--- @module Entity/Facet/Hacking
--- Hacking facet. A cryptokey / hacking chip (type FPS_Consumable, sub_type
--- Hacking — IcePick, Ripper, …) carries a `hacking_chip` block: how many breach
--- charges it holds, the multiplier it applies to the hack duration (below 1 is
--- faster), and the per-attempt error chance. Data-driven: fires on any entity
--- with a `hacking_chip` block.

local format = require('Module:Entity/Format')

local p = {}

--- 0-1 chance as a percentage ("0.9" -> "90%"); nil when absent.
---
--- @param value number|string|nil
--- @return string|nil
local function percent(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(math.floor(n * 1000 + 0.5) / 10) .. '%'
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.hacking_chip) == 'table'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local h = apiData.hacking_chip
	if type(h) ~= 'table' then
		return {}
	end

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	local charges = tonumber(h.max_charges)
	if charges and charges > 0 then
		push('Charges', format.formatNum(charges))
	end
	local dur = tonumber(h.duration_multiplier)
	if dur ~= nil and dur ~= 1 then
		push('Hack time', '×' .. format.formatNum(dur))
	end
	push('Error chance', percent(h.error_chance))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'hacking',
			label = 'Hacking',
			collapsible = true,
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local h = apiData.hacking_chip
	if type(h) ~= 'table' then
		return {}
	end
	local charges = tonumber(h.max_charges)
	local err = tonumber(h.error_chance)
	return {
		charges = (charges and charges > 0) and charges or nil,
		error_chance = err and (math.floor(err * 1000 + 0.5) / 10) or nil,
	}
end

return p
