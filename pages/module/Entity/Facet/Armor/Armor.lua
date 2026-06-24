require('strict')

--- @module Entity/Facet/Armor
--- Armor facet. Any wearable carrying a `suit_armor` block (helmets, torsos,
--- arms, legs, backpacks, and undersuits) gets its per-damage-type protection
--- surfaced: how much incoming damage of each type the piece reduces. It also
--- contributes the weight class (Heavy / Medium / Light) both as a short-
--- description prefix ("Heavy torso armor by CDS") and as a queryable facet.
--- Data-driven: fires on any entity with a `suit_armor` block.

local progressTiles = require('Module:ProgressTiles')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local statFormat = require('Module:Entity/StatFormat')

local p = {}

-- Damage types in display order. `impact` is a flat multiplier; the others are
-- {multiplier, threshold} objects, but `damage_resistance_map` flattens them all
-- to a bare damage-taken multiplier, which is what we read.
local DAMAGE_TYPES = {
	{ key = 'physical', label = 'Physical', abbr = 'PHY' },
	{ key = 'energy', label = 'Energy', abbr = 'ENG' },
	{ key = 'distortion', label = 'Distortion', abbr = 'DST' },
	{ key = 'thermal', label = 'Thermal', abbr = 'THM' },
	{ key = 'biochemical', label = 'Biochemical', abbr = 'BIO' },
	{ key = 'stun', label = 'Stun', abbr = 'STN' },
	{ key = 'impact', label = 'Impact', abbr = 'IMP' },
}

--- The damage-reduction percentage for a type, derived from its damage-taken
--- multiplier (0.6 means 60% of damage is taken, i.e. 40% resistance). Returns
--- nil when the multiplier is absent or non-numeric. Rounds to a whole percent.
---
--- @param map table
--- @param key string
--- @return number|nil resistance as a whole-number percentage
local function resistancePercent(map, key)
	return statFormat.resistancePercent(map[key])
end

-- Real armor weight classes. Other sub_types (e.g. "Helmet" on a flight helmet,
-- "UNDEFINED" on an undersuit) are NOT weight classes and must not be treated as
-- one, or the short description doubles up ("Helmet helmet").
local WEIGHT_CLASSES = {
	['Heavy'] = true,
	['Medium'] = true,
	['Light'] = true,
	['Super Heavy'] = true,
}

--- The in-game "Item Type" label from description_data (e.g. "Flight Helmet",
--- "Heavy Armor"). Returns nil when absent.
---
--- @param apiData table
--- @return string|nil
local function getItemType(apiData)
	local dd = apiData.description_data
	if type(dd) ~= 'table' then
		return nil
	end
	for _, entry in ipairs(dd) do
		if entry.name == 'Item Type' or entry.name == 'Type' then
			return entry.value or entry.type
		end
	end
	return nil
end

--- The armor weight class from `sub_type`, but ONLY when it is a real weight
--- class (Heavy / Medium / Light / Super Heavy). Flight helmets report sub_type
--- "Helmet" and undersuits "UNDEFINED"; those are not weight classes and return
--- nil. CamelCase ("SuperHeavy") is spaced before matching.
---
--- @param apiData table
--- @return string|nil
local function weightClass(apiData)
	local sub = apiData.sub_type
	if type(sub) ~= 'string' or sub == '' then
		return nil
	end
	local norm = (sub:gsub('(%l)(%u)', '%1 %2'))
	return WEIGHT_CLASSES[norm] and norm or nil
end

--- The short-description qualifier: the weight class for armor pieces ("Heavy"
--- -> "Heavy helmet"), or "Flight" for flight gear whose in-game item type leads
--- with "Flight" ("Flight Helmet" -> "Flight helmet"). Nil when neither applies,
--- so the piece reads as the bare slot name ("Undersuit by X").
---
--- @param apiData table
--- @return string|nil
local function descriptorPrefix(apiData)
	local wc = weightClass(apiData)
	if wc then
		return wc
	end
	local itemType = getItemType(apiData)
	if type(itemType) == 'string' and itemType:match('^%a+') == 'Flight' then
		return 'Flight'
	end
	return nil
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.suit_armor) == 'table'
end

--- Builds the resistance tiles (one per damage type with a value) for the
--- progress-tile row. Tiles use the default single accent (resistance is a
--- "more is better, none is bad" stat, so a diverging red→green heatmap would
--- mislead); the abbreviation is the visible label and the full name the hover
--- title. Empty when no damage type has a value.
---
--- @param map table the damage_resistance_map
--- @return ProgressTile[]
local function buildTiles(map)
	local tiles = {}
	for _, dt in ipairs(DAMAGE_TYPES) do
		local pct = resistancePercent(map, dt.key)
		if pct ~= nil then
			table.insert(tiles, {
				value = pct,
				label = dt.abbr,
				title = dt.label,
			})
		end
	end
	return tiles
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local sa = apiData.suit_armor
	if type(sa) ~= 'table' then
		return {}
	end
	local map = type(sa.damage_resistance_map) == 'table' and sa.damage_resistance_map or {}

	local tiles = buildTiles(map)
	if #tiles == 0 then
		return {}
	end

	-- The resistance set renders as a Module:ProgressTiles row, carried as a
	-- full-width, label-less section item so it shares the infobox item spacing.
	return sectionBuilder.build(sectionBuilder.section({
		key = 'armor',
		label = 'Damage resistance',
		items = {
			{ content = progressTiles.render({ tiles = tiles }), class = 't-infobox-item--block' },
		},
	}))
end

--- Weight class as the short-description prefix ("Heavy" -> "Heavy torso armor
--- by CDS"). Nil for undersuits (no weight class), which read "Undersuit by X".
---
--- @param apiData table
--- @param args table
--- @return string|nil
function p.getShortDescriptionPrefix(apiData, args)
	if type(apiData.suit_armor) ~= 'table' then
		return nil
	end
	return descriptorPrefix(apiData)
end

--- Contributes per-damage-type resistance percentages and the weight class as
--- structured data for querying / the slot index tables. Each resistance is
--- omitted when its multiplier is absent; weight_class is omitted for undersuits.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local sa = apiData.suit_armor
	if type(sa) ~= 'table' then
		return {}
	end
	local map = type(sa.damage_resistance_map) == 'table' and sa.damage_resistance_map or {}

	local data = { weight_class = weightClass(apiData) }
	for _, dt in ipairs(DAMAGE_TYPES) do
		local pct = resistancePercent(map, dt.key)
		if pct ~= nil then
			data[dt.key .. '_resistance'] = pct
		end
	end
	return data
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resistancePercent = resistancePercent,
	weightClass = weightClass,
	descriptorPrefix = descriptorPrefix,
	buildTiles = buildTiles,
}

return p
