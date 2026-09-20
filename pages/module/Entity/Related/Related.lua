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
---  2. Resolve each item's wiki page + image from its uuid through
---     Module:Entity/PageResolver, so disambiguated titles (e.g.
---     `Hyperion (quantum drive)`) link correctly.
---  3. Shape rows into the Tiles row schema and call Tiles.render.
---
--- The chain decides what "related" means: getRelated resolves leaf-first,
--- skipping a nil answer (Module:Entity/Assembly.resolveMostSpecific with
--- acceptNonEmpty) so a kind's "no data" case falls through to Base rather
--- than standing as the final word, and this module draws the payload it
--- gets. `items` (Base: the record's related_items block — set pieces +
--- cosmetic variants) renders as tiles; `cargo` (Commodity: the cargo-box
--- packaging ladder, which shares one image and has no own pages) renders
--- as a table; `vehicleSeries` (Vehicle: the editorial series name) queries
--- Module:Entity/Store for the rest of the series and renders as wider
--- tiles with the current page highlighted. The container always renders
--- so the layout is stable — falls back to a muted empty-state placeholder
--- when the payload has nothing to show or the upstream fetch failed.

local data = require('Module:Entity/Data')
local assembly = require('Module:Entity/Assembly')
local PageResolver = require('Module:Entity/PageResolver')
local Store = require('Module:Entity/Store')
local Tiles = require('Module:Tiles')
local tableLua = require('Module:TableLua')
local format = require('Module:Entity/Format')
local collapsibleCard = require('Module:CollapsibleCard')

local p = {}

local EMPTY_STATE_MESSAGE = 'No related items available from the API.'
-- Star Citizen item renders are usually portrait 3D product shots;
-- 3:4 keeps them roughly proportional across all column widths.
local TILE_ASPECT_RATIO = '3 / 4'
-- Vehicle tiles are their own shape: promo shots are landscape, so they take
-- a 16:9 image the grid does not crop to portrait, and a wider column, since
-- vehicle names are long enough to ellipsize inside an item-sized tile.
local VEHICLE_TILE_ASPECT_RATIO = '16 / 9'
local VEHICLE_TILE_MIN_WIDTH = '240px'
local VEHICLE_TILE_IMAGE_WIDTH = '480px'

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
--- uuid is the join key for resolving the wiki page (see
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
--- first-seen order. Used to build a single deduplicated page-resolution
--- query for both the wiki page and page image. Rows without a uuid (defensive
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

--- Shapes internal rows into the Tiles row schema. When PageResolver
--- resolved a row's uuid, the wikilink target is the canonical page and
--- the image is that page's stored infobox image. When it didn't resolve,
--- both fall back to the API name and Tiles applies its placeholder image.
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
--- intra-section labels, not navigable sections. The `t-tiles__tile--selected`
--- modifier rule lives in Tiles/styles.css (the class' own primitive),
--- already loaded by Tiles.render, so this module needs no styles of its
--- own here.
---
--- @param heading string
--- @param tilesRows TilesRow[]
--- @param options { aspectRatio: string|nil, tileMinWidth: string|nil, imageWidth: string|nil }|nil
--- @return string
local function renderSection(heading, tilesRows, options)
	options = options or {}
	local h3 = tostring(mw.html.create('h3'):wikitext(heading))
	return h3
		.. Tiles.render({
			rows = tilesRows,
			aspectRatio = options.aspectRatio or TILE_ASPECT_RATIO,
			tileMinWidth = options.tileMinWidth,
			imageWidth = options.imageWidth,
		})
end

--- Queries Bucket for the other vehicles sharing `series`, sorted by name.
--- Series lives in the `vehicle` table, so the filter alone restricts the
--- rows to vehicle pages; a category filter on top would drop gravlevs,
--- which sit in no vehicle browse category.
--- A Store failure (rate limit, bad manifest) yields no rows rather than
--- erroring the page, same containment as the rest of this module's
--- API-shaped failure modes.
--- @param series string
--- @return table[] rows: { page, name, role, image }
local function queryVehicleVariants(series)
	local ok, rows = pcall(Store.query, {
		kind = 'Vehicle',
		filters = { { 'Series', series } },
		columns = {
			{ builtin = 'page_name', as = 'page' },
			{ property = 'Name', as = 'name' },
			{ property = 'Role', as = 'role' },
			{ property = 'Image', as = 'image' },
		},
		limit = 100,
	})
	if not ok or type(rows) ~= 'table' then
		return {}
	end
	table.sort(rows, function(a, b)
		return (a.name or '') < (b.name or '')
	end)
	return rows
end

--- Shapes Store rows into Tiles rows, flagging the queried page's own tile
--- as `selected` (Module:Tiles' `t-tiles__tile--selected` modifier) so a
--- reader can see which of the series tiles is the current page.
--- @param rows table[] { page, name, role, image }
--- @param currentPage string mw.title.getCurrentTitle().prefixedText
--- @return TilesRow[]
local function toVehicleTilesRows(rows, currentPage)
	local tilesRows = {}
	for _, row in ipairs(rows) do
		table.insert(tilesRows, {
			page = row.page,
			linkLabel = row.name or row.page,
			image = row.image,
			primary = row.name,
			-- Role is a repeated Bucket field, so the read returns a list; the
			-- tile caption is one line.
			secondary = type(row.role) == 'table' and table.concat(row.role, ' / ') or row.role,
			selected = row.page == currentPage,
		})
	end
	return tilesRows
end

--- Renders the vehicle-series branch of getRelated (Vehicle.getRelated's
--- `vehicleSeries` payload): every other vehicle sharing the series, wider
--- tiles than the item-variant grid, current page highlighted. A series of
--- one (nothing else to compare against) falls back to the empty state,
--- same as an entity with no related items.
--- @param series string
--- @param currentPage string
--- @return string
local function renderVehicleVariants(series, currentPage)
	local rows = queryVehicleVariants(series)
	if #rows < 2 then
		return renderEmpty()
	end
	return renderSection('Variants', toVehicleTilesRows(rows, currentPage), {
		aspectRatio = VEHICLE_TILE_ASPECT_RATIO,
		tileMinWidth = VEHICLE_TILE_MIN_WIDTH,
		imageWidth = VEHICLE_TILE_IMAGE_WIDTH,
	})
end

-- Standard CIG cargo-container external dimensions { length, width, height }
-- in metres, keyed by SCU. A game constant, identical for every commodity,
-- verified against the items endpoint's cargo_dimension (the Stor*All container
-- line for 1/8 to 8 SCU; official RSI material for 16 to 32). The 0.125 box is
-- the smallest standard container (a "1/8 SCU" box, 0.5 m cube).
local BOX_DIMENSIONS = {
	[0.125] = { 0.5, 0.5, 0.5 },
	[1] = { 1.25, 1.25, 1.25 },
	[2] = { 2.5, 1.25, 1.25 },
	[4] = { 2.5, 2.5, 1.25 },
	[8] = { 2.5, 2.5, 2.5 },
	[16] = { 5, 2.5, 2.5 },
	[24] = { 7.5, 2.5, 2.5 },
	[32] = { 10, 2.5, 2.5 },
}

--- Standard box dimensions { length, width, height } (metres) for an SCU size,
--- or nil for non-standard sizes.
---
--- @param scu number
--- @return number[]|nil
local function boxDimensions(scu)
	return BOX_DIMENSIONS[scu]
end

--- Display label for an SCU box size: the sub-SCU box reads as a fraction
--- (1/8), whole sizes as their number.
---
--- @param scu number
--- @return string
local function scuLabel(scu)
	if scu == 0.125 then
		return '1/8'
	end
	return format.formatNum(scu)
end

--- Renders cargo-box variants (Commodity's getRelated payload) as a sortable
--- table (SCU / dimensions / mass). Falls back to the empty-state when there
--- are no rows.
---
--- @param rows { scu: number, mass_kg: number }[]
--- @return string
local function renderCargoVariants(rows)
	if rows[1] == nil then
		return renderEmpty()
	end
	local function metres(v)
		return v and (format.formatNum(v) .. ' m') or '-'
	end
	local tableRows = {}
	for _, r in ipairs(rows) do
		local dims = boxDimensions(r.scu)
		tableRows[#tableRows + 1] = {
			scuLabel(r.scu),
			metres(dims and dims[1]),
			metres(dims and dims[2]),
			metres(dims and dims[3]),
			format.formatNum(r.mass_kg) .. ' kg',
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

--- Main entry point. Draws the chain's getRelated payload: the cargo table
--- for `cargo`, the vehicle-series tile grid for `vehicleSeries`, up to two
--- tile grids (set components + variants) for `items`, otherwise the
--- empty-state placeholder. Resolved with acceptNonEmpty (not the default
--- leaf-wins-even-nil) so Vehicle's nil (no series) falls through to Base's
--- `items` instead of standing as the final answer.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if result.hasApiError then
		return renderEmpty()
	end

	local payload = assembly.resolveMostSpecific(result.chain, 'getRelated', assembly.acceptNonEmpty, result.ctx) or {}
	if type(payload.cargo) == 'table' then
		return renderCargoVariants(payload.cargo)
	end
	if type(payload.vehicleSeries) == 'string' and payload.vehicleSeries ~= '' then
		return renderVehicleVariants(payload.vehicleSeries, mw.title.getCurrentTitle().prefixedText)
	end

	local relatedItems = payload.items
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
	boxDimensions = boxDimensions,
	queryVehicleVariants = queryVehicleVariants,
	toVehicleTilesRows = toVehicleTilesRows,
	renderVehicleVariants = renderVehicleVariants,
}

return p
