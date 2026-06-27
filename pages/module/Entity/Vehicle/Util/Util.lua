require('strict')

--- @module Entity/Vehicle/Util
--- Vehicle-internal shared helpers used across more than one Vehicle sub-builder
--- or a retained Vehicle hook. NOT cross-kind (those live in Module:Entity/Facet/Util) —
--- these are vehicle-domain: the curated career taxonomy, the ship-matrix size
--- override, and the armor damage-type table (damage_*-prefixed keys).

local statFormat = require('Module:Entity/StatFormat')

local p = {}

--- Career value: the wiki `career` arg wins over the API (curated taxonomy).
--- @param apiData table
--- @param args table
--- @return string|nil
function p.resolveCareer(apiData, args)
	local c = args.career or apiData.career
	return type(c) == 'string' and c ~= '' and c or nil
end

--- Ship-matrix size string: the curated `|size=` arg wins over `apiData.size`
--- (e.g. the Railen is editorially Large but the API reports medium). nil when neither.
--- @param apiData table
--- @param args table
--- @return string|nil
function p.matrixSize(apiData, args)
	if type(args.size) == 'string' and args.size ~= '' then
		return args.size
	end
	return type(apiData.size) == 'string' and apiData.size ~= '' and apiData.size or nil
end

--- Armor damage types for the resistance tiles (abbr under tile, full name on
--- hover) and the per-type SMW damage modifiers. Vehicle keeps its own
--- `damage_*`-keyed table + order (distinct from Facet/Util.DAMAGE_TYPES).
p.DAMAGE_TYPES = {
	{ key = 'damage_physical', abbr = 'PHY', label = 'Physical' },
	{ key = 'damage_energy', abbr = 'ENG', label = 'Energy' },
	{ key = 'damage_distortion', abbr = 'DST', label = 'Distortion' },
	{ key = 'damage_thermal', abbr = 'THM', label = 'Thermal' },
	{ key = 'damage_biochemical', abbr = 'BIO', label = 'Biochemical' },
	{ key = 'damage_stun', abbr = 'STN', label = 'Stun' },
}

--- Mean damage resistance (percent, 0-100) across the shared damage types, or nil
--- when armor carries no resistance data. Shared by getStructuredData (the stored
--- "Armor resistance" cohort value) and the Stats Profile (the live ship value) so
--- the two sides of the percentile seam cannot drift.
--- @param armor table
--- @return number|nil
function p.meanArmorResistance(armor)
	local sum, count = 0, 0
	for _, dt in ipairs(p.DAMAGE_TYPES) do
		local pct = statFormat.resistancePercent(armor[dt.key])
		if pct ~= nil then
			sum = sum + pct
			count = count + 1
		end
	end
	return count > 0 and (sum / count) or nil
end

--- Mean radar cross-section signature across the three axes, or nil when absent.
--- The API's `cross_section` is a { length, width, height } table of per-axis CS
--- signatures (scales with ship size; distinct from physical `sizes`); the scoring
--- profile ranks the mean (lower = stealthier). Shared by getStructuredData (the
--- stored "Cross section" value) and the Stats Profile so the seam cannot drift.
--- @param cs table|nil  apiData.cross_section
--- @return number|nil
function p.meanCrossSection(cs)
	if type(cs) ~= 'table' then
		return nil
	end
	local sum, count = 0, 0
	for _, axis in ipairs({ 'length', 'width', 'height' }) do
		local v = tonumber(cs[axis])
		if v ~= nil then
			sum = sum + v
			count = count + 1
		end
	end
	return count > 0 and (sum / count) or nil
end

--- Mean armor deflection threshold across the physical and energy damage types,
--- or nil when absent. The live (Alpha 4.7) "Armor Damage Deflection Threshold"
--- is a per-shot damage gate: a shot below the threshold is fully deflected.
--- Only physical and energy thresholds are meaningful (the other damage types
--- read 0 fleet-wide). Higher = tougher. Shared by getStructuredData (the stored
--- "Armor deflection" value) and the Stats Profile so the seam cannot drift.
--- @param armor table|nil  apiData.armor
--- @return number|nil
function p.meanDeflection(armor)
	if type(armor) ~= 'table' or type(armor.deflection) ~= 'table' then
		return nil
	end
	local sum, count = 0, 0
	for _, key in ipairs({ 'physical', 'energy' }) do
		local v = tonumber(armor.deflection[key])
		if v ~= nil then
			sum = sum + v
			count = count + 1
		end
	end
	return count > 0 and (sum / count) or nil
end

return p
