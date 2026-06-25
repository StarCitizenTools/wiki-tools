require('strict')

--- @module Entity/Vehicle/Util
--- Vehicle-internal shared helpers used across more than one Vehicle sub-builder
--- or a retained Vehicle hook. NOT cross-kind (those live in Module:Entity/Facet/Util) —
--- these are vehicle-domain: the curated career taxonomy, the ship-matrix size
--- override, and the armor damage-type table (damage_*-prefixed keys).

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

return p
