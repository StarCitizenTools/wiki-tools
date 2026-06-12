require('strict')

--- @module Entity/Item/QuantumInterdictionGenerator
--- Quantum interdiction generator subtype. Disrupts nearby ships' quantum
--- drives. Devices combine two capabilities — a snare (pulls ships out of, and
--- blocks, quantum travel) and a dampener (blocks quantum-drive engagement) —
--- which the wiki classifies as QED (snare + dampener), QDMP (dampener only), or
--- QID (snare only). The mode is derived from the API: a snare pulse radius above
--- the placeholder 1 m means it can snare; a jamming range means it can dampen.

local format = require('Module:Entity/Format')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Snare / dampener capability from the interdiction block.
---
--- @param qig table
--- @return boolean hasSnare, boolean hasDampener, number|nil snareRadius, number|nil dampenRange
local function capabilities(qig)
	local pulse = type(qig.pulse) == 'table' and qig.pulse or {}
	local jamming = type(qig.jamming) == 'table' and qig.jamming or {}
	local snareRadius = tonumber(pulse.radius)
	local dampenRange = tonumber(jamming.range)
	-- radius 1 m is the API's "no snare" placeholder.
	local hasSnare = snareRadius ~= nil and snareRadius > 1
	local hasDampener = dampenRange ~= nil and dampenRange > 0
	return hasSnare, hasDampener, snareRadius, dampenRange
end

--- Wiki device class from the capability pair.
---
--- @param hasSnare boolean
--- @param hasDampener boolean
--- @return string|nil  "QED" | "QDMP" | "QID"
local function deviceClass(hasSnare, hasDampener)
	if hasSnare and hasDampener then
		return 'QED'
	elseif hasDampener then
		return 'QDMP'
	elseif hasSnare then
		return 'QID'
	end
	return nil
end

local MODE_DESCRIPTION = {
	QED = 'Snare + dampener (QED)',
	QDMP = 'Dampener (QDMP)',
	QID = 'Snare (QID)',
}

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local qig = apiData.quantum_interdiction_generator
	if type(qig) ~= 'table' then
		return {}
	end
	local pulse = type(qig.pulse) == 'table' and qig.pulse or {}
	local hasSnare, hasDampener, snareRadius, dampenRange = capabilities(qig)

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	local class = deviceClass(hasSnare, hasDampener)
	push('Mode', class and MODE_DESCRIPTION[class])
	if hasSnare then
		push('Snare range', format.formatNum(snareRadius) .. ' m')
	end
	push('Dampener range', dampenRange and (format.formatNum(dampenRange) .. ' m'))
	push('Charge time', pulse.charge_time and (format.formatNum(pulse.charge_time) .. ' s'))
	push('Duration', pulse.discharge_time and (format.formatNum(pulse.discharge_time) .. ' s'))
	push('Cooldown', pulse.cooldown_time and (format.formatNum(pulse.cooldown_time) .. ' s'))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'quantum_interdiction_generator',
			label = 'Quantum interdiction',
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local qig = apiData.quantum_interdiction_generator
	if type(qig) ~= 'table' then
		return {}
	end
	local pulse = type(qig.pulse) == 'table' and qig.pulse or {}
	local hasSnare, hasDampener, snareRadius, dampenRange = capabilities(qig)
	return {
		qig_mode = deviceClass(hasSnare, hasDampener),
		qig_snare_range = hasSnare and snareRadius or nil,
		qig_dampener_range = dampenRange,
		qig_charge_time = tonumber(pulse.charge_time),
		qig_duration = tonumber(pulse.discharge_time),
		qig_cooldown = tonumber(pulse.cooldown_time),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	deviceClass = deviceClass,
}

return p
