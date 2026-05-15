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
--- Items only today (reads apiData.related_items, which only the items
--- endpoint provides). The container always renders so the layout is
--- stable — falls back to a muted empty-state placeholder when the
--- entity has no related items, isn't an item at all, or the upstream
--- fetch failed.

local data = require('Module:Entity/Data')
local Tiles = require('Module:Tiles')

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
--- resolveItemPages).
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

--- Resolves item uuids to their wiki pages and page images via a single
--- mw.smw.ask query against the `uuid` property set by
--- Module:Entity/StructuredData. The query matches both the canonical
--- lowercase `uuid` and the legacy capitalized `UUID` so pages that
--- haven't been re-rendered under the new schema still resolve — mirrors
--- the dual-read in Module:Entity/Data.readSmwUuid.
---
--- Results are filtered to mainspace, non-subobject pages only:
---  * Subobjects (`PageName#subobjectId`) would otherwise link to a
---    template-data anchor rather than the canonical article.
---  * Non-mainspace stores (User:, Template: test pages) already go
---    under prefixed property names in StructuredData, but legacy
---    `UUID` values and ad-hoc edits could leak through; the explicit
---    namespace check is cheap insurance.
--- We over-fetch (5× the UUID count) so a UUID that matches both a
--- subobject and its mainspace page isn't truncated to only the
--- subobject by the SMW limit.
---
--- Decouples display name from page title so disambiguated pages
--- (e.g. `Hyperion (quantum drive)`, while the API name is just
--- `Hyperion`) link correctly. Uuids that match no mainspace page —
--- item never rendered with Template:Entity, or the property hasn't
--- propagated yet — are absent from the returned map; callers fall back
--- to the API name (yielding the same possibly-wrong link as the
--- pre-resolution code, never worse).
---
--- @param uuids string[]
--- @return table<string, { page: string, image: string|nil }>
local function resolveItemPages(uuids)
	if #uuids == 0 then
		return {}
	end
	local uuidList = table.concat(uuids, '||')
	local results = mw.smw.ask({
		'[[uuid::' .. uuidList .. ']] OR [[UUID::' .. uuidList .. ']]',
		'?uuid#-=uuid',
		'?UUID#-=uuid_legacy',
		'?#-=page',
		'?Page Image#-=image',
		'limit=' .. tostring(#uuids * 5),
	})
	local map = {}
	if type(results) == 'table' then
		for _, row in ipairs(results) do
			-- Whichever property matched, use its value as the join key —
			-- the UUIDs themselves are identical across the two property
			-- names, so transitional pages with both set produce the same
			-- entry under either branch.
			local uuid = (type(row.uuid) == 'string' and row.uuid ~= '' and row.uuid)
				or (type(row.uuid_legacy) == 'string' and row.uuid_legacy ~= '' and row.uuid_legacy)
				or nil
			if uuid and type(row.page) == 'string' and row.page ~= '' and not row.page:find('#', 1, true) then
				local title = mw.title.new(row.page)
				if title and title.namespace == 0 then
					-- SMW's Page Image property returns values with a leading `File:`
					-- prefix (matching the wiki file-page title). Strip it here so the
					-- map stores bare filenames; Tiles prepends `File:` once when
					-- building the [[File:...]] wikitext.
					local image = nil
					if type(row.image) == 'string' and row.image ~= '' then
						image = row.image:gsub('^File:', '')
					end
					-- First mainspace match wins. If a UUID somehow appears on more
					-- than one mainspace page, we keep the earliest result and ignore
					-- the rest rather than letting later rows clobber the canonical hit.
					if not map[uuid] then
						map[uuid] = { page = row.page, image = image }
					end
				end
			end
		end
	end
	return map
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

--- Main entry point. Returns either two tile grids (set components +
--- variants) or the empty-state placeholder.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if result.hasApiError then
		return renderEmpty()
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

	local pageMap = resolveItemPages(collectUuids(setRows, variantRows))

	local parts = {}
	if #setRows > 0 then
		table.insert(parts, renderSection('Set pieces', toTilesRows(setRows, pageMap)))
	end
	if #variantRows > 0 then
		table.insert(parts, renderSection('Variants', toTilesRows(variantRows, pageMap)))
	end
	return table.concat(parts)
end

return p
