require('strict')

--- @module Entity/Related
--- Renders an entity's related entries as image tile grids: set components
--- first (helmet/torso/legs etc.), then cosmetic variants. Sibling renderer
--- parallel to Module:Entity/Availability — consumes Module:Entity/Data so
--- it shares Apiunto's cache with the Entity infobox and other sibling
--- templates on the same page.
---
--- Tile rendering is delegated to Module:Tiles (image + label + fakelink
--- wikilink). This module's job is to:
---  1. Pull related_items off the merged API response.
---  2. Resolve each item's wiki page + image via the SMW `uuid` property
---     so disambiguated titles (e.g. `Hyperion (quantum drive)`) link
---     correctly.
---  3. Shape rows into the Tiles row schema and call Tiles.render.
---
--- Items read apiData.related_items (set pieces + cosmetic variants, tiles).
--- Commodities instead render their cargo-box packaging variants (the SCU
--- ladder) as a table — those "related entities" share one image and have no
--- own pages, so tiles don't fit. The container always renders so the layout
--- is stable — falls back to a muted empty-state placeholder when the entity
--- has no related entries, isn't a supported kind, or the upstream fetch failed.

local data = require('Module:Entity/Data')
local PageResolver = require('Module:Entity/PageResolver')
local Tiles = require('Module:Tiles')
local tableLua = require('Module:TableLua')
local util = require('Module:Entity/Util')
local collapsibleCard = require('Module:CollapsibleCard')

local p = {}

local EMPTY_STATE_MESSAGE = 'No related items available from the API.'
-- Star Citizen item renders are usually portrait 3D product shots;
-- 3:4 keeps them roughly proportional across all column widths.
local TILE_ASPECT_RATIO = '3 / 4'

--- Maps an API type string (e.g. `Char_Armor_Helmet`) to its display
--- name via Module:Entity/Item/types.json. Falls back to the raw type
--- string when unmapped so new types are still discoverable on-page.
---
--- @param apiType string|nil
--- @return string
local function resolveTypeName(apiType)
	if not apiType or apiType == '' then
		return ''
	end
	local types = mw.loadJsonData('Module:Entity/Item/types.json')
	local typeInfo = types[apiType]
	return (typeInfo and typeInfo.name) or apiType
end

--- Returns true when `key` takes more than one distinct value across
--- the items. Used to decide whether a dimension (size, grade) is
--- worth surfacing as a differentiator — if every variant in the
--- family is size 1, there's no point captioning the tiles with it.
---
--- @param items table[]
--- @param key string
--- @return boolean
local function variantDimensionDiffers(items, key)
	if #items < 2 then
		return false
	end
	local first = items[1][key]
	for i = 2, #items do
		if items[i][key] ~= first then
			return true
		end
	end
	return false
end

--- Builds the differentiator caption for a single variant from the
--- dimensions that actually vary across the family. Returns
--- `'S1 · Grade A'`, `'Grade A'`, `'S1'`, or `''` depending on which
--- dimensions matter. Size uses the SC-native shorthand (`S1`, `S2`,
--- …) — universally understood among Star Citizen readers and shorter
--- than the long-form `Size N`. Grade stays long-form because a bare
--- letter would be ambiguous out of context.
---
--- @param item table
--- @param showSize boolean
--- @param showGrade boolean
--- @return string
local function buildVariantCaption(item, showSize, showGrade)
	local parts = {}
	if showSize and item.size ~= nil then
		table.insert(parts, 'S' .. tostring(item.size))
	end
	if showGrade and type(item.grade_label) == 'string' and item.grade_label ~= '' then
		table.insert(parts, 'Grade ' .. item.grade_label)
	end
	return table.concat(parts, ' · ')
end

--- Builds the variant rows: base_item first (unless it's the queried
--- page — the only self-reference case the API exposes), then
--- variant_items in API order. Each row is
--- `{ name, uuid, primary, secondary }`: primary is the variant
--- differentiator (e.g. `Black`) when one is set, otherwise falls back
--- to the full item name so the tile is never unlabeled. Secondary
--- captions only the dimensions that actually differentiate the family
--- — for a quantum drive family where every variant is size 1 but
--- grades differ, secondary reads `Grade A` / `Grade B` and size is
--- omitted; for a gimbal family that's all grade A but spans sizes,
--- it reads `S1` / `S2` / …. When nothing varies, secondary stays
--- empty and the image + primary label do the differentiating. The
--- uuid is the join key for resolving the wiki page through SMW (see
--- PageResolver.resolve).
---
--- @param relatedItems table
--- @param currentUuid string|nil
--- @return { name: string, uuid: string|nil, primary: string, secondary: string }[]
local function buildVariantRows(relatedItems, currentUuid)
	local function variantPrimary(item)
		if item.variant_name and item.variant_name ~= '' then
			return item.variant_name
		end
		return item.name
	end

	-- Collect raw items in display order: base first (when distinct
	-- from current page), then variant_items in API order. Holding
	-- onto the raw records lets us look up size/grade in the caption
	-- step without re-walking the API response.
	local rawItems = {}
	local base = relatedItems.base_item
	if type(base) == 'table' and base.name and base.uuid ~= currentUuid then
		table.insert(rawItems, base)
	end
	if type(relatedItems.variant_items) == 'table' then
		for _, item in ipairs(relatedItems.variant_items) do
			if item.name then
				table.insert(rawItems, item)
			end
		end
	end

	-- Decide which dimensions are worth captioning. Only the ones that
	-- vary across the family carry useful information for the reader.
	local showSize = variantDimensionDiffers(rawItems, 'size')
	local showGrade = variantDimensionDiffers(rawItems, 'grade_label')

	local rows = {}
	for _, item in ipairs(rawItems) do
		table.insert(rows, {
			name = item.name,
			uuid = item.uuid,
			primary = variantPrimary(item),
			secondary = buildVariantCaption(item, showSize, showGrade),
		})
	end
	return rows
end

--- Builds the set component rows from set_items in API order. Each row
--- is `{ name, uuid, primary, secondary }`: primary is the full item
--- name (prominent), secondary is the resolved type (`Helmet` /
--- `Torso` / `Legs`, rendered as a small kicker above the name).
--- Matches the Entity infobox header pattern where the subtitle sits
--- above the title. Unlike buildVariantRows, takes no currentUuid —
--- set components are always distinct from the queried entity
--- (different items entirely, not variants of it), so there's never a
--- self-reference to filter.
---
--- @param relatedItems table
--- @return { name: string, uuid: string|nil, primary: string, secondary: string }[]
local function buildSetRows(relatedItems)
	local rows = {}
	if type(relatedItems.set_items) == 'table' then
		for _, item in ipairs(relatedItems.set_items) do
			if item.name then
				table.insert(rows, {
					name = item.name,
					uuid = item.uuid,
					primary = item.name,
					secondary = resolveTypeName(item.type),
				})
			end
		end
	end
	return rows
end

--- Collects unique uuids across any number of row lists, preserving
--- first-seen order. Used to build a single deduplicated SMW query for
--- both the wiki page and page image. Rows without a uuid (defensive
--- against malformed API responses) are skipped.
---
--- @vararg { uuid: string|nil }[]
--- @return string[]
local function collectUuids(...)
	local seen = {}
	local out = {}
	for _, rowList in ipairs({ ... }) do
		for _, row in ipairs(rowList) do
			if row.uuid and not seen[row.uuid] then
				seen[row.uuid] = true
				table.insert(out, row.uuid)
			end
		end
	end
	return out
end

--- Shapes internal rows into the Tiles row schema. When the SMW lookup
--- resolved a row's uuid, the wikilink target is the canonical page and
--- the image is the SMW Page Image. When it didn't resolve, both fall
--- back to the API name (same possibly-wrong link as the
--- pre-resolution code) and Tiles applies its placeholder image.
---
--- @param rows { name: string, uuid: string|nil, primary: string, secondary: string }[]
--- @param pageMap table<string, { page: string, image: string|nil }>
--- @return TilesRow[]
local function toTilesRows(rows, pageMap)
	local tilesRows = {}
	for _, row in ipairs(rows) do
		local resolved = row.uuid and pageMap[row.uuid] or nil
		table.insert(tilesRows, {
			page = (resolved and resolved.page) or row.name,
			linkLabel = row.name,
			image = resolved and resolved.image or nil,
			primary = row.primary,
			secondary = row.secondary,
		})
	end
	return tilesRows
end

--- Renders the empty-state placeholder: a muted single-line `<p>` with
--- this module's own templatestyles tag (Tiles styles aren't needed
--- when no tiles will render).
---
--- @return string
local function renderEmpty()
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Related/styles.css' },
	})
	local empty = mw.html.create('p'):addClass('t-entity-related-empty'):wikitext(EMPTY_STATE_MESSAGE)
	return styles .. tostring(empty)
end

--- Renders one labeled section: a raw `<h3>` subheading followed by a
--- Tiles grid. Uses mw.html for the heading rather than wikitext
--- `=== … ===` so the subheading stays out of the page TOC — they're
--- intra-section labels, not navigable sections.
---
--- @param heading string
--- @param tilesRows TilesRow[]
--- @return string
local function renderSection(heading, tilesRows)
	local h3 = tostring(mw.html.create('h3'):wikitext(heading))
	return h3 .. Tiles.render({ rows = tilesRows, aspectRatio = TILE_ASPECT_RATIO })
end

--- Mirrors Module:Entity/Commodity.matches() — commodities carry the
--- `box_sizes_scu` ladder. Their related entities are the physical cargo-box
--- instances of the substance, rendered as a table rather than tiles (the
--- boxes share one image and have no own pages).
---
--- @param apiData table
--- @return boolean
local function isCommodity(apiData)
	return type(apiData) == 'table' and apiData.box_sizes_scu ~= nil
end

-- Standard CIG cargo-container external dimensions { length, width, height }
-- in metres, keyed by SCU. These are a game constant — identical for every
-- commodity, confirmed against the items endpoint's true_dimension. The
-- sub-SCU hand-carryable (0.125) is an irregular mined chunk, not a standard
-- box, so it has no entry.
local BOX_DIMENSIONS = {
	[1] = { 1.25, 1.25, 1.25 },
	[2] = { 2.5, 1.25, 1.25 },
	[4] = { 2.5, 2.5, 1.25 },
	[8] = { 2.5, 2.5, 2.5 },
	[16] = { 5, 2.5, 2.5 },
	[24] = { 7.5, 2.5, 2.5 },
	[32] = { 10, 2.5, 2.5 },
}

--- Standard box dimensions { length, width, height } (metres) for an SCU size,
--- or nil for non-standard sizes (e.g. the 0.125 hand-carryable).
---
--- @param scu number
--- @return number[]|nil
local function boxDimensions(scu)
	return BOX_DIMENSIONS[scu]
end

--- Cargo packaging variants as table rows { scu, mass_kg } (mass = SCU ×
--- density × 1000), ascending. Safe on nil/non-table boxSizes (returns {}).
---
--- @param boxSizes number[]|nil
--- @param density number|nil
--- @return table[]
local function buildCargoRows(boxSizes, density)
	local rows = {}
	if type(boxSizes) ~= 'table' then
		return rows
	end
	local d = tonumber(density) or 0
	for _, scu in ipairs(boxSizes) do
		rows[#rows + 1] = { scu = scu, mass_kg = scu * d * 1000 }
	end
	table.sort(rows, function(a, b)
		return a.scu < b.scu
	end)
	return rows
end

--- Renders the commodity's cargo-box variants as a sortable table (SCU / Mass),
--- read from the refined record's box ladder + density. Falls back to the
--- empty-state when there are no box sizes.
---
--- @param apiData table
--- @return string
local function renderCargoVariants(apiData)
	local rec = apiData._refinedRecord or apiData
	local rows = buildCargoRows(rec.box_sizes_scu, rec.density_g_per_cc)
	if #rows == 0 then
		return renderEmpty()
	end
	local function metres(v)
		return v and (util.formatNum(v) .. ' m') or '-'
	end
	local tableRows = {}
	for _, r in ipairs(rows) do
		local dims = boxDimensions(r.scu)
		tableRows[#tableRows + 1] = {
			util.formatNum(r.scu),
			metres(dims and dims[1]),
			metres(dims and dims[2]),
			metres(dims and dims[3]),
			util.formatNum(r.mass_kg) .. ' kg',
		}
	end
	local table_ = tableLua.render({
		caption = 'Cargo variants',
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = {
			{ id = 'scu', label = 'SCU', textAlign = 'number' },
			{ id = 'length', label = 'Length', textAlign = 'number' },
			{ id = 'width', label = 'Width', textAlign = 'number' },
			{ id = 'height', label = 'Height', textAlign = 'number' },
			{ id = 'mass', label = 'Mass', textAlign = 'number' },
		},
		sort = { scu = 'asc' },
		data = tableRows,
	})
	return collapsibleCard.render({
		title = 'Cargo variants',
		description = #rows == 1 and '1 size' or (#rows .. ' sizes'),
		content = table_,
	})
end

--- Main entry point. For commodities, renders the cargo-variants table; for
--- items, returns up to two tile grids (set components + variants); otherwise
--- the empty-state placeholder.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if result.hasApiError then
		return renderEmpty()
	end

	if isCommodity(result.apiData) then
		return renderCargoVariants(result.apiData)
	end

	local relatedItems = result.apiData.related_items
	if type(relatedItems) ~= 'table' then
		return renderEmpty()
	end

	local setRows = buildSetRows(relatedItems)
	local variantRows = buildVariantRows(relatedItems, args.uuid)

	if #setRows == 0 and #variantRows == 0 then
		return renderEmpty()
	end

	local pageMap = PageResolver.resolve(collectUuids(setRows, variantRows))

	local parts = {}
	if #setRows > 0 then
		table.insert(parts, renderSection('Set pieces', toTilesRows(setRows, pageMap)))
	end
	if #variantRows > 0 then
		table.insert(parts, renderSection('Variants', toTilesRows(variantRows, pageMap)))
	end
	return table.concat(parts)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	isCommodity = isCommodity,
	buildCargoRows = buildCargoRows,
	boxDimensions = boxDimensions,
}

return p
