require('strict')

--- @module Entity/Related
--- Renders an entity's related entries as image card grids: set components
--- first (helmet/torso/legs etc.), then cosmetic variants. Sibling renderer
--- parallel to Module:Entity/Availability — consumes Module:Entity/Data so
--- it shares Apiunto's cache with the Entity infobox and other sibling
--- templates on the same page.
---
--- Cards adopt the visual pattern of Module:ItemVariants: image with a
--- small label overlay at the bottom. The whole card is clickable via a
--- transparent absolute-positioned wikilink (the "fakelink" pattern —
--- MediaWiki's sanitizer strips raw <a> tags, so anchors only exist when
--- the parser generates them from [[Page|Text]] wikitext).
---
--- Items only today (reads apiData.related_items, which only the items
--- endpoint provides). The container always renders so the layout is
--- stable — falls back to a muted empty-state placeholder when the
--- entity has no related items, isn't an item at all, or the upstream
--- fetch failed.

local data = require('Module:Entity/Data')

local p = {}

local PLACEHOLDER_IMAGE = 'Placeholderv2.png'
local EMPTY_STATE_MESSAGE = 'No related items available from the API.'

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

--- Builds the variant rows: base_item first (unless it's the queried
--- page — the only self-reference case the API exposes), then
--- variant_items in API order. Each row is
--- `{ name, uuid, primary, secondary }`: primary is the variant
--- differentiator (e.g. `Black`) when one is set, otherwise falls back
--- to the full item name so the card is never unlabeled. Secondary
--- stays empty because the image + label are enough to identify
--- cosmetic variants. The uuid is the join key for resolving the wiki
--- page through SMW (see resolveItemPages).
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

	local rows = {}
	local base = relatedItems.base_item
	if type(base) == 'table' and base.name and base.uuid ~= currentUuid then
		table.insert(rows, { name = base.name, uuid = base.uuid, primary = variantPrimary(base), secondary = '' })
	end
	if type(relatedItems.variant_items) == 'table' then
		for _, item in ipairs(relatedItems.variant_items) do
			if item.name then
				table.insert(
					rows,
					{ name = item.name, uuid = item.uuid, primary = variantPrimary(item), secondary = '' }
				)
			end
		end
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
					-- map stores bare filenames; the card renderer prepends `File:`
					-- once when building the [[File:...]] wikitext.
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

--- Renders one card grid from pre-built rows. Each card emits the
--- fakelink wrapper, the image, and a two-tier label: optional
--- secondary (a small kicker above) and primary (the prominent name
--- below). Ordering matches the Entity infobox header (subtitle above
--- title). Both lines are single-line + ellipsis in CSS so the label
--- can never encroach on the image.
---
--- Link target comes from the SMW page map (keyed by uuid). When the
--- uuid resolves, the wikilink uses the resolved page as the target and
--- the API name as the display text — so disambiguated wiki titles like
--- `Hyperion (quantum drive)` link correctly while the card still reads
--- `Hyperion`. When the uuid doesn't resolve (missing on the page, or
--- the row lacks a uuid entirely), the link falls back to the API name.
--- Cards with no SMW image fall back to PLACEHOLDER_IMAGE.
---
--- @param rows { name: string, uuid: string|nil, primary: string, secondary: string }[]
--- @param pageMap table<string, { page: string, image: string|nil }>
--- @return string
local function renderCardGrid(rows, pageMap)
	local grid = mw.html.create('div'):addClass('t-entity-related-grid')
	for _, row in ipairs(rows) do
		local resolved = row.uuid and pageMap[row.uuid] or nil
		local linkPage = (resolved and resolved.page) or row.name
		local image = (resolved and resolved.image) or PLACEHOLDER_IMAGE
		local card = grid:tag('div'):addClass('t-entity-related-card')
		card:tag('div'):addClass('t-entity-related-card-link'):wikitext('[[' .. linkPage .. '|' .. row.name .. ']]')
		card:tag('div'):addClass('t-entity-related-card-image'):wikitext('[[File:' .. image .. '|320px|link=]]')
		local label = card:tag('div'):addClass('t-entity-related-card-label')
		if row.secondary and row.secondary ~= '' then
			label:tag('div'):addClass('t-entity-related-card-label-secondary'):wikitext(row.secondary)
		end
		label:tag('div'):addClass('t-entity-related-card-label-primary'):wikitext(row.primary)
	end
	return tostring(grid)
end

--- Renders a section: subheading + card grid. Subheading helps readers
--- distinguish set components from variants when both are present.
--- Uses mw.html (raw <h3>) rather than wikitext === heading === so the
--- subheadings stay out of the page TOC — they're intra-section labels,
--- not navigable sections.
---
--- @param heading string
--- @param rows { name: string, uuid: string|nil, primary: string, secondary: string }[]
--- @param pageMap table<string, { page: string, image: string|nil }>
--- @return string
local function renderSection(heading, rows, pageMap)
	return tostring(mw.html.create('h3'):wikitext(heading)) .. renderCardGrid(rows, pageMap)
end

--- Main entry point. Always renders the templatestyles block plus either
--- the card grids or the empty-state placeholder, so the page layout
--- stays stable whether or not the entity has related items.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Related/styles.css' },
	})

	local function renderEmpty()
		local empty = mw.html.create('p'):addClass('t-entity-related-empty'):wikitext(EMPTY_STATE_MESSAGE)
		return styles .. tostring(empty)
	end

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

	local parts = { styles }
	if #setRows > 0 then
		table.insert(parts, renderSection('Set pieces', setRows, pageMap))
	end
	if #variantRows > 0 then
		table.insert(parts, renderSection('Variants', variantRows, pageMap))
	end
	return table.concat(parts)
end

return p
