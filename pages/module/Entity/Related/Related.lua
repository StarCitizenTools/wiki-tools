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
--- endpoint provides). Non-item entities render nothing.

local data = require('Module:Entity/Data')

local p = {}

local PLACEHOLDER_IMAGE = 'Placeholderv2.png'

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
--- variant_items in API order. Each row is `{ name, primary, secondary }`:
--- primary is the variant differentiator (e.g. `Black`, or `(base)` when
--- the base_item has no variant_name); secondary stays empty because the
--- image + variant name are enough to identify cosmetic variants.
---
--- @param relatedItems table
--- @param currentUuid string|nil
--- @return { name: string, primary: string, secondary: string }[]
local function buildVariantRows(relatedItems, currentUuid)
	local rows = {}
	local base = relatedItems.base_item
	if type(base) == 'table' and base.name and base.uuid ~= currentUuid then
		local primary = base.variant_name
		if not primary or primary == '' then
			primary = '(base)'
		end
		table.insert(rows, { name = base.name, primary = primary, secondary = '' })
	end
	if type(relatedItems.variant_items) == 'table' then
		for _, item in ipairs(relatedItems.variant_items) do
			if item.name then
				table.insert(rows, { name = item.name, primary = item.variant_name or '', secondary = '' })
			end
		end
	end
	return rows
end

--- Builds the set component rows from set_items in API order. Each row
--- is `{ name, primary, secondary }`: primary is the resolved type
--- (`Helmet` / `Torso` / `Legs`) for quick scanning, secondary is the
--- full item name for disambiguation. Unlike buildVariantRows, takes no
--- currentUuid — set components are always distinct from the queried
--- entity (different items entirely, not variants of it), so there's
--- never a self-reference to filter.
---
--- @param relatedItems table
--- @return { name: string, primary: string, secondary: string }[]
local function buildSetRows(relatedItems)
	local rows = {}
	if type(relatedItems.set_items) == 'table' then
		for _, item in ipairs(relatedItems.set_items) do
			if item.name then
				table.insert(rows, { name = item.name, primary = resolveTypeName(item.type), secondary = item.name })
			end
		end
	end
	return rows
end

--- Collects unique page names across any number of row lists, preserving
--- first-seen order. Used to build a single deduplicated query for the
--- SMW image lookup.
---
--- @vararg { name: string }[]
--- @return string[]
local function collectPageNames(...)
	local seen = {}
	local out = {}
	for _, rowList in ipairs({ ... }) do
		for _, row in ipairs(rowList) do
			if not seen[row.name] then
				seen[row.name] = true
				table.insert(out, row.name)
			end
		end
	end
	return out
end

--- Issues one mw.smw.ask query for the Page Image property across every
--- given page name. Returns a `{ pageName -> imageFile }` map. Pages
--- without a Page Image are absent from the map; callers fall back to
--- the placeholder.
---
--- @param pageNames string[]
--- @return table<string, string>
local function fetchPageImages(pageNames)
	if #pageNames == 0 then
		return {}
	end
	local conditions = {}
	for _, name in ipairs(pageNames) do
		table.insert(conditions, '[[' .. name .. ']]')
	end
	local results = mw.smw.ask({
		table.concat(conditions, ' OR '),
		'?Page Image#-=image',
		'?#-=page',
		'limit=' .. tostring(#pageNames),
	})
	local map = {}
	if type(results) == 'table' then
		for _, row in ipairs(results) do
			-- SMW's Page Image property returns values with a leading `File:`
			-- prefix (matching the wiki file-page title). Strip it here so the
			-- map stores bare filenames; the card renderer prepends `File:`
			-- once when building the [[File:...]] wikitext.
			if row.page and type(row.image) == 'string' and row.image ~= '' then
				map[row.page] = (row.image:gsub('^File:', ''))
			end
		end
	end
	return map
end

--- Renders one card grid from pre-built rows. Each card emits the
--- fakelink wrapper, the image, and a two-tier label: primary (the
--- quick-scan identifier) and optional secondary (a muted detail line,
--- line-clamped in CSS so long text can't encroach on the image).
--- Cards with no SMW image fall back to PLACEHOLDER_IMAGE.
---
--- @param rows { name: string, primary: string, secondary: string }[]
--- @param imageMap table<string, string>
--- @return string
local function renderCardGrid(rows, imageMap)
	local grid = mw.html.create('div'):addClass('t-entity-related-grid')
	for _, row in ipairs(rows) do
		local card = grid:tag('div'):addClass('t-entity-related-card')
		local image = imageMap[row.name] or PLACEHOLDER_IMAGE
		card:tag('div'):addClass('t-entity-related-card-link'):wikitext('[[' .. row.name .. '|' .. row.name .. ']]')
		card:tag('div'):addClass('t-entity-related-card-image'):wikitext('[[File:' .. image .. '|320px|link=]]')
		local label = card:tag('div'):addClass('t-entity-related-card-label')
		label:tag('div'):addClass('t-entity-related-card-label-primary'):wikitext(row.primary)
		if row.secondary and row.secondary ~= '' then
			label:tag('div'):addClass('t-entity-related-card-label-secondary'):wikitext(row.secondary)
		end
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
--- @param rows { name: string, primary: string, secondary: string }[]
--- @param imageMap table<string, string>
--- @return string
local function renderSection(heading, rows, imageMap)
	return tostring(mw.html.create('h3'):wikitext(heading)) .. renderCardGrid(rows, imageMap)
end

--- Main entry point. Renders up to two card grids (set components first,
--- variants second). Returns an empty string when the API has no
--- related_items, both buckets are empty, or the upstream fetch failed.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if result.hasApiError then
		return ''
	end

	local relatedItems = result.apiData.related_items
	if type(relatedItems) ~= 'table' then
		return ''
	end

	local setRows = buildSetRows(relatedItems)
	local variantRows = buildVariantRows(relatedItems, args.uuid)

	if #setRows == 0 and #variantRows == 0 then
		return ''
	end

	local imageMap = fetchPageImages(collectPageNames(setRows, variantRows))

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Related/styles.css' },
	})

	local parts = { styles }
	if #setRows > 0 then
		table.insert(parts, renderSection('Set pieces', setRows, imageMap))
	end
	if #variantRows > 0 then
		table.insert(parts, renderSection('Variants', variantRows, imageMap))
	end
	return table.concat(parts)
end

return p
