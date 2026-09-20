require('strict')

--- @module Entity/Vehicle/Util
--- Vehicle-internal shared helpers used across more than one Vehicle sub-builder
--- or a retained Vehicle hook. NOT cross-kind (those live in Module:Entity/Facet/Util) —
--- these are vehicle-domain: the curated career taxonomy, the ship-matrix size
--- override, and the armor damage-type table (damage_*-prefixed keys).

local statFormat = require('Module:Entity/StatFormat')

local p = {}

local ROLE_HUBS_PAGE = 'Module:Entity/Navplates/hubs.json'

--- Career value: the wiki `career` arg wins over the API (curated taxonomy).
--- @param apiData table
--- @param args table
--- @return string|nil
function p.resolveCareer(apiData, args)
	local c = args.career or apiData.career
	return type(c) == 'string' and c ~= '' and c or nil
end

--- Sentence case, which is the wiki's canonical form for a role. The hub pages
--- and categories a role links to are sentence case ("Light fighters",
--- "Category:Light armor"), so a Title Case value would label a link differently
--- from its destination. The upstream API is uniformly Title Case and is not the
--- authority here: it carries game data, not wiki style.
---
--- An all-caps run is left alone, since lowercasing it would destroy an acronym.
---
--- @param role string
--- @return string
local function sentenceCase(role)
	-- A caps run is only an acronym when something around it is cased normally.
	-- A value that is caps throughout is an editor shouting, not "UEE": left
	-- alone it would store a second casing of a role that already exists and
	-- reintroduce the collisions this normalising removes.
	local shouted = mw.ustring.find(role, '%l') == nil
	local out = mw.ustring.gsub(role, '%a+', function(word)
		if not shouted and mw.ustring.find(word, '^%u%u+$') then
			return word
		end
		return mw.ustring.lower(word)
	end)
	return mw.ustring.upper(mw.ustring.sub(out, 1, 1)) .. mw.ustring.sub(out, 2)
end

--- The vehicle's roles, as a list. A vehicle can genuinely hold more than one
--- ("Starter / Light freight"), and both the wiki param and the API deliver them
--- as a single separator-joined string, so they are split here: `Role` is a
--- repeated Bucket field, and storing the whole phrase as one value means no
--- per-role query matches it (a ship listed "Starter / Light fighter" would be
--- absent from every light-fighter listing).
---
--- The wiki `role` param wins over the API, the same curated-taxonomy rule as
--- Career, and is split identically. Every segment is normalised to sentence
--- case whatever its source: the override decides *which* role a vehicle has,
--- not how it is cased.
---
--- @param apiData table
--- @param args table
--- @return string[]|nil
function p.resolveRole(apiData, args)
	local raw = (type(args.role) == 'string' and args.role ~= '') and args.role or apiData.role
	if type(raw) == 'table' then
		local normalised = {}
		for _, segment in ipairs(raw) do
			normalised[#normalised + 1] = sentenceCase(mw.text.trim(segment))
		end
		return normalised[1] and normalised or nil
	end
	if type(raw) ~= 'string' or raw == '' then
		return nil
	end
	local roles = {}
	for segment in mw.text.gsplit(raw, '%s*[/,]%s*') do
		segment = mw.text.trim(segment)
		if segment ~= '' then
			roles[#roles + 1] = sentenceCase(segment)
		end
	end
	return roles[1] and roles or nil
end

--- The browse hub for one role, or nil where none covers it. The map lives
--- beside the other hubs in Module:Entity/Navplates/hubs.json because it points
--- into that catalogue, but it is a section of its own there: role values are
--- generic words ("Medical", "Mining", "Cargo") and the type index is one
--- lowercased keyspace shared with guns and armor, so matching a role against
--- it would let an item hub of the same name capture it.
---
--- Most of these hubs list spacecraft, so an entry names the family it covers
--- and a known mismatch resolves to nothing: a ground vehicle's "Medical" must
--- not link Medical ships, which does not list it. An unknown family still
--- resolves, because a vehicle page with a blank `uuid` has no record to derive
--- one from and would otherwise lose its hub.
---
--- Only roles with a real hub resolve. A rare role returns nil, so the caller
--- renders it plain rather than linking a page that lists one vehicle.
---
--- @param role string
--- @param family string|nil 'ship' | 'ground' | 'gravlev', nil when unknown
--- @return string|nil hub page title
function p.roleHub(role, family)
	if type(role) ~= 'string' or role == '' then
		return nil
	end
	local doc = mw.loadJsonData(ROLE_HUBS_PAGE)
	if type(doc.roles) ~= 'table' then
		return nil
	end
	local wanted = mw.ustring.lower(mw.text.trim(role))
	for name, entry in pairs(doc.roles) do
		if mw.ustring.lower(name) == wanted then
			if family ~= nil and entry.family ~= nil and entry.family ~= family then
				return nil
			end
			return entry.hub
		end
	end
	return nil
end

--- The vehicle family a record describes, or nil when it carries none. Mirrors
--- the leaf subtypes (Ship / GroundVehicle / Gravlev) for callers that hold
--- apiData rather than the resolved chain.
---
--- @param apiData table
--- @return string|nil
function p.family(apiData)
	if type(apiData) ~= 'table' then
		return nil
	end
	if apiData.is_spaceship then
		return 'ship'
	end
	if apiData.is_gravlev then
		return 'gravlev'
	end
	if apiData.is_vehicle then
		return 'ground'
	end
	return nil
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
--- hover) and the per-type stored damage modifiers. Vehicle keeps its own
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

--- Apply an armor signature multiplier to a raw signature value. The API reports the
--- raw emission / cross-section and the armor's `signal_*` multiplier (1.0 = no change,
--- <1 stealthier, >1 louder) as *separate* fields; the effective signature a sensor
--- sees is raw × multiplier. A missing or non-numeric multiplier is treated as 1.0 (no
--- change); nil raw stays nil. Shared by the ship side (Stats / Profile) and the cohort
--- side (ClassStats) so the two ends of the percentile seam apply the same math.
--- @param raw number|nil
--- @param modifier any  armor signal multiplier, or nil/absent for no change
--- @return number|nil
function p.applySignatureModifier(raw, modifier)
	if raw == nil then
		return nil
	end
	return raw * (tonumber(modifier) or 1)
end

--- Effective IR signature: raw `emission.ir` × the armor IR multiplier. nil when the
--- ship reports no IR emission. See applySignatureModifier.
--- @param apiData table
--- @return number|nil
function p.effectiveIrEmission(apiData)
	local emission = type(apiData.emission) == 'table' and apiData.emission or {}
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	return p.applySignatureModifier(tonumber(emission.ir), armor.signal_infrared)
end

--- Effective EM signature: raw `emission.em_max` × the armor EM multiplier. nil when the
--- ship reports no EM emission. See applySignatureModifier.
--- @param apiData table
--- @return number|nil
function p.effectiveEmEmission(apiData)
	local emission = type(apiData.emission) == 'table' and apiData.emission or {}
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	return p.applySignatureModifier(tonumber(emission.em_max), armor.signal_electromagnetic)
end

--- Effective cross-section: the mean axis cross-section × the armor cross-section
--- multiplier. nil when the ship reports no cross-section. See applySignatureModifier.
--- @param apiData table
--- @return number|nil
function p.effectiveCrossSection(apiData)
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	return p.applySignatureModifier(p.meanCrossSection(apiData.cross_section), armor.signal_cross_section)
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
