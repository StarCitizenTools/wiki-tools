require('strict')

--- @module Entity/Location/StarSystem
--- Star-system leaf of the Location kind. Renders from the merged payload the
--- kind assembles: the location record at the top level plus the starmap
--- record at apiData.starsystem (attached by Location.enrich; may be absent —
--- every consumer nil-guards and degrades to location-only rows).

local location = require('Module:Entity/Location')
local meterBar = require('Module:MeterBar')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local statTiles = require('Module:StatTiles')
local Editorial = require('Module:Entity/Editorial')

local p = {}

--- @type string
p.parent = 'Entity/Location'

--- RSI starmap workflow status code → label. Rendered as a plain
--- "Starmap status" row (the label carries the disambiguation): this is
--- RSI's editorial state for the starmap entry, deliberately NOT badged so
--- it cannot be mistaken for an in-game availability state.
local STATUS_LABELS = {
	P = 'Published',
	D = 'Draft',
	R = 'Review',
	S = 'Stub',
	N = 'Probe data incomplete',
	U = 'Undiscovered',
	M = 'UEE Military Classified',
}

--- Star sub_type.name → display form. Ported from the legacy
--- Module:System/config.json subtype_rename map.
local STAR_SUBTYPES = {
	['Main Sequence-Dwarf-O'] = 'O-type main sequence',
	['Main Sequence-Dwarf-B'] = 'B-type main sequence',
	['Main Sequence-Dwarf-A'] = 'A-type main sequence',
	['Main Sequence-Dwarf-F'] = 'F-type main sequence',
	['Main Sequence-Dwarf-G'] = 'G-type main sequence',
	['Main Sequence-Dwarf-K'] = 'K-type main sequence',
	['Main Sequence-Dwarf-M'] = 'M-type main sequence',
}

--- Tile catalog: celestial_objects type → labels, in display order. `one` is
--- the count-1 label; `title` carries the unabbreviated name as a tooltip;
--- `field` names the editorial count-override field (legacy {{System}} arg),
--- resolved through the editorial view so hand counts beat the starmap tally.
local OBJECT_TILES = {
	{ type = 'STAR', one = 'Star', many = 'Stars' },
	{ type = 'PLANET', one = 'Planet', many = 'Planets', field = 'planets' },
	{ type = 'SATELLITE', one = 'Moon', many = 'Moons', field = 'satellites' },
	{ type = 'ASTEROID_BELT', one = 'Belt', many = 'Belts', title = 'Asteroid belts', field = 'asteroidbelts' },
	{ type = 'ASTEROID_FIELD', one = 'Field', many = 'Fields', title = 'Asteroid fields', field = 'asteroidfields' },
	{ type = 'MANMADE', one = 'Station', many = 'Stations', field = 'stations' },
	{ type = 'JUMPPOINT', one = 'Jump point', many = 'Jump points', field = 'jumppoints' },
	{ type = 'ANOMALY', one = 'Anomaly', many = 'Anomalies', field = 'anomalies' },
	{ type = 'BLACKHOLE', one = 'Black hole', many = 'Black holes', field = 'blackholes' },
	{ type = 'POI', one = 'POI', many = 'POIs', field = 'pois' },
}

--- @param apiData table
--- @return table|nil
local function getStarsystem(apiData)
	return type(apiData.starsystem) == 'table' and apiData.starsystem or nil
end

--- The ARK starmap code (the `?location=` key), or nil. Two consumers read it —
--- the Starmap footer button and the Metadata row — and they open-coded the same
--- guard, which let an empty-string code through both: a `?location=` button
--- pointing at the starmap index, and a blank "Starmap code" row. One accessor,
--- so they cannot drift and the empty case is rejected once.
--- @param apiData table
--- @return string|nil
local function starmapCode(apiData)
	local starsystem = getStarsystem(apiData)
	local code = starsystem and starsystem.code or nil
	if type(code) ~= 'string' or code == '' then
		return nil
	end
	return code
end

--- @param starsystem table|nil
--- @return table aggregated ({} when absent)
local function getAggregated(starsystem)
	local aggregated = starsystem and starsystem.aggregated
	return type(aggregated) == 'table' and aggregated or {}
end

--- 0–10 sensor value → display text: one decimal, trailing .0 dropped
--- ("8.13" → "8.1/10", 10 → "10/10"). nil for missing/zero/non-numeric —
--- zero means "no reading" in the starmap data, not an actual rating.
--- @param value any
--- @return string|nil
local function formatSensor(value)
	local n = tonumber(value)
	if not n or n <= 0 then
		return nil
	end
	local rounded = math.floor(n * 10 + 0.5) / 10
	return tostring(rounded) .. '/10'
end

--- Count celestial objects by type.
--- @param starsystem table|nil
--- @return table<string, number>
local function countObjects(starsystem)
	local counts = {}
	local objects = starsystem and starsystem.celestial_objects
	if type(objects) ~= 'table' then
		return counts
	end
	for _, obj in ipairs(objects) do
		if type(obj) == 'table' and type(obj.type) == 'string' then
			counts[obj.type] = (counts[obj.type] or 0) + 1
		end
	end
	return counts
end

--- StatTiles items for the object counts, catalog order, zeros omitted.
--- Editorial overrides (`ed`, optional) beat the starmap tallies per tile.
--- @param starsystem table|nil
--- @param ed table|nil Editorial view
--- @return StatTilesItem[]
local function buildObjectTiles(starsystem, ed)
	local counts = countObjects(starsystem)
	local tiles = {}
	for _, def in ipairs(OBJECT_TILES) do
		local count = counts[def.type]
		if def.field and ed then
			count = ed:value(def.field, count)
		end
		count = tonumber(count)
		if count and count > 0 then
			tiles[#tiles + 1] = {
				value = count,
				label = count == 1 and def.one or def.many,
				title = def.title,
			}
		end
	end
	return tiles
end

--- Display list of the system's star types (renamed sub_types, deduplicated,
--- comma-joined). nil when no star carries a sub_type.
--- @param starsystem table|nil
--- @return string|nil
local function starTypeList(starsystem)
	local objects = starsystem and starsystem.celestial_objects
	if type(objects) ~= 'table' then
		return nil
	end
	local names, seen = {}, {}
	for _, obj in ipairs(objects) do
		if type(obj) == 'table' and obj.type == 'STAR' and type(obj.sub_type) == 'table' then
			local raw = obj.sub_type.name
			local name = STAR_SUBTYPES[raw] or raw
			if type(name) == 'string' and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	if #names == 0 then
		return nil
	end
	return table.concat(names, ', ')
end

--- Affiliation display text: canonical entries link their label
--- ("[[United Empire of Earth]]"), a free-text entry renders exactly what the
--- editor wrote (`display`) — they decide whether [[Kr'Thak]] links, so
--- 'Unknown' is never painted red by an auto-link.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return string|nil
local function affiliationDisplay(starsystem, resolved)
	local affiliation = location.resolveAffiliation(starsystem, resolved)
	if not affiliation then
		return nil
	end
	return affiliation.display or ('[[' .. affiliation.label .. ']]')
end

--- Append a MeterBar sensor row as a full-width block item.
--- @param items EntityItemData[]
--- @param label string
--- @param value any
local function appendMeter(items, label, value)
	local text = formatSensor(value)
	if not text then
		return
	end
	items[#items + 1] = {
		content = meterBar.render({ label = label, value = tonumber(value), max = 10, text = text }),
		class = 't-infobox-item--block',
	}
end

--- Type info runs before editorial resolution in Data.get, so the editorial
--- system type is read from the raw args here (same alias order as the
--- manifest: systemtype, then the legacy `type`); everything downstream of
--- resolution goes through location.resolveSystemType instead.
--- @param apiData table
--- @param args table|nil
--- @return { name: string, category: string }
function p.getTypeInfo(apiData, args)
	local _, editorialEntry = location.systemTypeEntry(args and (args.systemtype or args.type) or nil)
	local starsystem = getStarsystem(apiData)
	local typeInfo = editorialEntry or (starsystem and location.SYSTEM_TYPES[starsystem.type] or nil)
	return {
		name = typeInfo and typeInfo.label or 'Star system',
		category = 'Systems',
	}
end

--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return EntitySectionEntry[]
function p.getSections(apiData, args, resolved)
	local ed = Editorial.view(resolved)
	local starsystem = getStarsystem(apiData)
	local aggregated = getAggregated(starsystem)

	local general = {}
	sectionBuilder.push(general, 'Affiliation', affiliationDisplay(starsystem, resolved))
	local jurisdiction = type(apiData.jurisdiction) == 'table' and apiData.jurisdiction.name or nil
	sectionBuilder.push(general, 'Jurisdiction', jurisdiction and ('[[' .. jurisdiction .. ']]'))
	local size = ed:value('size', aggregated.size)
	sectionBuilder.push(general, 'Size', size and (tostring(size) .. ' AU'))
	local starTypes = ed:value('startypes', starTypeList(starsystem))
	local starLabel = (type(starTypes) == 'string' and starTypes:find(',', 1, true)) and 'Star types' or 'Star type'
	sectionBuilder.push(general, starLabel, starTypes)
	sectionBuilder.push(general, 'Population', ed:value('population'))
	sectionBuilder.push(general, 'Starmap status', starsystem and STATUS_LABELS[starsystem.status] or nil)

	local sensor = {}
	appendMeter(sensor, 'Economy', aggregated.economy)
	appendMeter(sensor, 'Population', aggregated.population)

	local objects = {}
	local tiles = buildObjectTiles(starsystem, ed)
	if #tiles > 0 then
		objects[#objects + 1] = {
			content = statTiles.render({ items = tiles }),
			class = 't-infobox-item--block',
		}
	end

	local lore = {}
	sectionBuilder.push(lore, 'Discovered in', ed:value('discoveredin'))
	sectionBuilder.push(lore, 'Discovered by', ed:value('discoveredby'))
	sectionBuilder.push(lore, 'Historical names', ed:value('historicalnames'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		sectionBuilder.section({ key = 'sensor', label = 'Sensor readings', items = sensor }),
		sectionBuilder.section({ key = 'objects', label = 'Astronomical objects', items = objects }),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- Pure-API structured data. size / discoveredin / discoveredby storage is
--- owned by the editorial manifest (smw fields there) — do not double-store.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table<string, any>
function p.getStructuredData(apiData, args, resolved)
	local starsystem = getStarsystem(apiData)
	local ed = Editorial.view(resolved)
	local counts = countObjects(starsystem)
	-- No early return without a starmap record: the no-record lore systems
	-- (Hyoton, Krell, …) carry their identity and counts editorially, and
	-- those must store exactly like everyone else's.
	-- System type stores the SYSTEM_TYPES display label ('Single star
	-- system'), the same string the infobox subtitle shows, so store and
	-- display cannot disagree — the raw-code vocabulary existed to share one
	-- query bucket with the legacy Module:System pages, and that constraint
	-- retired with the module (this leaf is now the property's only writer).
	-- An unmapped code stores raw as the fallback: a future ARK type degrades
	-- to a visible code instead of vanishing, and self-heals once mapped.
	-- Affiliation stores the compact form (UEE / Unclaimed), or the delinked
	-- free text for affiliations only lore knows (Kr'Thak). Counts go through
	-- the editorial view so the stored numbers always equal the displayed
	-- tiles (hand counts beat the starmap tallies).
	local typeCode, typeEntry = location.resolveSystemType(starsystem, resolved)
	local affiliation = location.resolveAffiliation(starsystem, resolved)
	return {
		system_type = typeEntry and typeEntry.label or typeCode,
		affiliation = affiliation and (affiliation.short or affiliation.label) or nil,
		star_count = counts.STAR,
		planet_count = tonumber(ed:value('planets', counts.PLANET)),
		moon_count = tonumber(ed:value('satellites', counts.SATELLITE)),
		station_count = tonumber(ed:value('stations', counts.MANMADE)),
		jump_point_count = tonumber(ed:value('jumppoints', counts.JUMPPOINT)),
	}
end

--- Legacy Module:System's planet-count formula, refined per design review:
--- the affiliation joins as a compact prefix (an improvement over legacy) and
--- the legacy trailing period is dropped (SHORTDESC convention).
--- "UEE single star system with 4 planets" / "Unclaimed single star system
--- with 6 planets"; fallbacks: no planets → no count clause; no type →
--- "System with N planets"; no record at all → the legacy catch-all.
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @param resolved table|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix, resolved)
	local starsystem = getStarsystem(apiData)
	local _, typeEntry = location.resolveSystemType(starsystem, resolved)
	local planets = tonumber(Editorial.view(resolved):value('planets', countObjects(starsystem).PLANET)) or 0
	local countClause = planets == 1 and ' with 1 planet' or (' with ' .. planets .. ' planets')

	if typeEntry then
		local label = typeInfo and typeInfo.name or 'Star system'
		local affiliation = location.resolveAffiliation(starsystem, resolved)
		-- Only canonical affiliations join the prefix: a free-text one reads
		-- wrong there ("Unknown trinary star system" says the wrong thing
		-- entirely), and free text is unbounded — the row and category carry
		-- it; the short description stays predictable.
		local desc = affiliation
				and not affiliation.display
				and ((affiliation.short or affiliation.label) .. ' ' .. label:gsub('^%u', string.lower))
			or label
		if planets > 0 then
			desc = desc .. countClause
		end
		return desc
	end
	if planets > 0 then
		return 'System' .. countClause
	end
	return 'A star system in Star Citizen'
end

--- RSI Starmap as a footer action button (from the starsystem code), sitting
--- beside the Galactapedia and Wiki API buttons. The Galactapedia mark doubles
--- as the icon — it is technically the Starmap's logo. Galactapedia itself is
--- NOT handled here: the Infobox footer already renders it from
--- args.galactapediaurl.
--- @param apiData table
--- @param args table
--- @return table[]
function p.getFooterButtons(apiData, args)
	local code = starmapCode(apiData)
	if not code then
		return {}
	end
	return {
		{
			label = 'Starmap',
			url = 'https://robertsspaceindustries.com/starmap?location=' .. code,
			icon = 'Sc-icon-galactapedia.svg',
			class = 't-button--branded t-button--starmap',
		},
	}
end

--- Chain-contributed Metadata rows: the ARK starmap code — the `?location=`
--- key on the RSI starmap, the same vocabulary the legacy System and
--- Astronomical object templates expose.
--- @param apiData table
--- @param args table
--- @return EntityItemData[]
function p.getMetadataItems(apiData, args)
	local code = starmapCode(apiData)
	if not code then
		return {}
	end
	return { { label = 'Starmap code', content = code } }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatSensor = formatSensor,
	countObjects = countObjects,
	buildObjectTiles = buildObjectTiles,
	starTypeList = starTypeList,
	affiliationDisplay = affiliationDisplay,
	starmapCode = starmapCode,
	STATUS_LABELS = STATUS_LABELS,
}

return p
