require('strict')

local data = require('Module:Entity/Data')
local util = require('Module:Entity/Util')
local base = require('Module:Entity/Base')
local structuredData = require('Module:Entity/StructuredData')
local infobox = require('Module:InfoboxLua')
local button = require('Module:ButtonLua')

local CATEGORY_API_ERROR = '[[Category:Pages with API errors]]'
local CATEGORY_ENTITY_ERROR = '[[Category:Pages with Entity errors]]'
local CATEGORY_STRUCTURED_DATA_ERROR = '[[Category:Pages with structured data errors]]'
local WIKI_API_SEARCH_URL = 'https://api.star-citizen.wiki/search/'

local p = {}

--- Renders apiData.entity_tag_map as a comma-separated list of <data>
--- elements, so the visible text is the display name while the value
--- attribute carries the tag UUID for scrapers / future JS hooks.
--- Returns nil when no tags are present so the row collapses out of the
--- infobox entirely.
---
--- @param apiData table
--- @return string|nil
local function formatEntityTags(apiData)
	local tags = apiData.entity_tag_map
	if type(tags) ~= 'table' or #tags == 0 then
		return nil
	end
	local parts = {}
	for _, tag in ipairs(tags) do
		table.insert(parts, tostring(mw.html.create('data'):attr('value', tag.uuid):wikitext(tag.name)))
	end
	return table.concat(parts, ', ')
end

--- Builds the Metadata section.
---
--- @param apiData table
--- @param args table
--- @return table section
local function buildMetadataSection(apiData, args)
	return {
		label = 'Metadata',
		collapsible = true,
		collapsed = true,
		items = {
			{ label = 'UUID', content = args.uuid },
			{ label = 'Class name', content = apiData.class_name },
			{ label = 'Classification', content = apiData.classification },
			{
				label = 'Tags',
				content = apiData.tags and #apiData.tags > 0 and table.concat(apiData.tags, ', ') or nil,
			},
			{ label = 'Entity tags', content = formatEntityTags(apiData) },
			{ label = 'Version', content = apiData.version },
		},
	}
end

--- Builds the External sites section by aggregating getExternalSiteItems from
--- every module in the chain. Returns nil when no items are available.
---
--- @param chain table[]
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildExternalSitesSection(chain, apiData, args)
	local items = {}
	for _, mod in ipairs(chain) do
		if mod.getExternalSiteItems then
			for _, item in ipairs(mod.getExternalSiteItems(apiData, args)) do
				table.insert(items, item)
			end
		end
	end
	if #items == 0 then
		return nil
	end
	return {
		label = 'External sites',
		collapsible = true,
		collapsed = true,
		items = items,
	}
end

--- Builds the footer section: a label-less section holding a full-width
--- button linking to the entity's page on the Star Citizen Wiki API
--- (api.star-citizen.wiki). The /search/<uuid> path resolves any entity by
--- UUID regardless of type, so this works for items, vehicles, and any future
--- type. Returns nil when no UUID is available so the section collapses out.
---
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildFooterSection(apiData, args)
	local uuid = args.uuid or apiData.uuid
	if not uuid or uuid == '' then
		return nil
	end

	local buttonHtml = button.render({
		label = 'View on Wiki API',
		url = WIKI_API_SEARCH_URL .. uuid,
		icon = 'Star Citizen Wiki API - Logo.svg',
		weight = 'normal',
	})

	return {
		content = buttonHtml,
		class = 't-infobox-section--footer',
	}
end

--- Assembles all infobox sections: chain contributions, metadata, external sites, footer.
---
--- @param chain table[]
--- @param apiData table
--- @param args table
--- @return table[] sections
local function buildSections(chain, apiData, args)
	local sectionsList = {}
	for _, mod in ipairs(chain) do
		if mod.getSections then
			table.insert(sectionsList, mod.getSections(apiData, args))
		end
	end
	local sections = util.mergeSections(sectionsList)

	table.insert(sections, buildMetadataSection(apiData, args))

	local externalSites = buildExternalSitesSection(chain, apiData, args)
	if externalSites then
		table.insert(sections, externalSites)
	end

	local footer = buildFooterSection(apiData, args)
	if footer then
		table.insert(sections, footer)
	end

	return sections
end

--- Collects structured data from the chain and persists it via the backend.
---
--- @param chain table[]
--- @param apiData table
--- @param args table
--- @return boolean success True if the backend accepted the data
local function storeStructuredData(chain, apiData, args)
	local dataList = {}
	for _, mod in ipairs(chain) do
		if mod.getStructuredData then
			table.insert(dataList, mod.getStructuredData(apiData, args))
		end
	end
	return structuredData.store(util.mergeStructuredData(dataList))
end

--- Sets the page's short description via the SHORTDESC parser function.
--- Displayed under the title, in search suggestions, and related article cards.
--- Uses the most specific getShortDescription implementation in the chain
--- (leaf-first walk); falls back to the type display name.
---
--- @param frame table
--- @param typeInfo table|nil
--- @param chain table[]
--- @param apiData table
--- @param args table
local function setShortDescription(frame, typeInfo, chain, apiData, args)
	if not typeInfo then
		return
	end

	local desc = typeInfo.name
	for i = #chain, 1, -1 do
		if chain[i].getShortDescription then
			desc = chain[i].getShortDescription(apiData, args, typeInfo)
			break
		end
	end

	frame:callParserFunction('SHORTDESC', desc)
end

--- Derives the content category names for an entity — pure (no namespace
--- logic, no [[Category:]] markup) so the rules are unit-testable in
--- isolation (see Module:Entity/testcases). Emits, when available:
---  * the broad type category (from types.json via typeInfo, e.g. "Guns"),
---  * the sub_type category (from subTypeCategories.json, e.g. PDCTurret ->
---    "PDCs") — a bucket finer than the type category, keyed by the API
---    `sub_type` enum,
---  * the item-type category (from itemTypeCategories.json, e.g. "Laser
---    repeaters") when the in-game label is mapped — unmapped labels are
---    silently skipped, so a partial mapping is safe; items with no label
---    fall back to a weapon-type tag (see below),
---  * the manufacturer category.
--- Size/grade/class are facets, not categories — they live in structured data.
---
--- @param typeInfo table|nil
--- @param apiData table
--- @param args table
--- @return string[] Ordered list of category names
function p.deriveCategories(typeInfo, apiData, args)
	local names = {}

	if typeInfo then
		table.insert(names, typeInfo.category or typeInfo.name)
	end

	-- Sub_type browse category: a bucket finer than the type category for
	-- sub_types that warrant one (e.g. PDCTurret -> "PDCs", a refinement of
	-- the "Turrets" type category). Keyed by the API `sub_type` enum, so it
	-- groups all PDCs regardless of their damage-type "Item Type" label.
	local subType = type(apiData.sub_type) == 'string' and apiData.sub_type ~= '' and apiData.sub_type or nil
	if subType then
		local subTypeCategories = mw.loadJsonData('Module:Entity/Item/subTypeCategories.json')
		local subTypeCategory = subTypeCategories[subType]
		if subTypeCategory then
			table.insert(names, subTypeCategory)
		end
	end

	-- Item-type browse category. Prefer the explicit "Item Type"/"Type" label;
	-- when an item carries no such label (e.g. 'WARLORD' Cannon, empty
	-- description_data), fall back to a weapon-type tag — the CamelCase tag
	-- ("PlasmaCannon") split on case boundaries matches a label key in the same
	-- map ("Plasma Cannon"). A present-but-unmapped label (e.g. the PDC's
	-- damage-type "Laser Turret") deliberately does NOT fall back to tags;
	-- PDCs are instead grouped by sub_type ("PDCs") above, since the label
	-- varies by damage type while the sub_type does not.
	local itemType = util.getItemType(apiData)
	local tags = type(apiData.tags) == 'table' and apiData.tags or nil
	if itemType or tags then
		local itemTypeCategories = mw.loadJsonData('Module:Entity/Item/itemTypeCategories.json')
		local itemTypeCategory
		if itemType then
			itemTypeCategory = itemTypeCategories[itemType]
		else
			for _, tag in ipairs(tags) do
				local spaced = (tag:gsub('(%l)(%u)', '%1 %2'))
				if itemTypeCategories[spaced] then
					itemTypeCategory = itemTypeCategories[spaced]
					break
				end
			end
		end
		if itemTypeCategory then
			table.insert(names, itemTypeCategory)
		end
	end

	local manufacturer = base.resolveManufacturer(apiData, args)
	if manufacturer and manufacturer.page then
		table.insert(names, manufacturer.page)
	end

	return names
end

--- Builds the trailing category wikitext. Content categories (from the pure
--- p.deriveCategories) apply only on article (mainspace) pages so test and
--- User: pages don't pollute the canonical category tree — verify category
--- behavior by parsing wikitext with a mainspace title. Tracking categories
--- apply in every namespace so errors surface wherever the module runs.
---
--- @param typeInfo table|nil
--- @param apiData table
--- @param args table
--- @param hasApiError boolean
--- @param hasStructuredDataError boolean
--- @return string
local function buildCategories(typeInfo, apiData, args, hasApiError, hasStructuredDataError)
	local categories = ''

	if mw.title.getCurrentTitle():inNamespace(0) then
		for _, name in ipairs(p.deriveCategories(typeInfo, apiData, args)) do
			categories = categories .. '[[Category:' .. name .. ']]'
		end
	end

	if hasApiError then
		categories = categories .. CATEGORY_API_ERROR
	end
	if hasStructuredDataError then
		categories = categories .. CATEGORY_STRUCTURED_DATA_ERROR
	end
	return categories
end

--- Main entry point for the Entity module. Renders the infobox and owns
--- page-metadata responsibilities (SMW storage, SHORTDESC, tracking
--- categories). Sibling renderers on the same page should consume
--- Module:Entity/Data directly and leave page metadata to this template.
---
--- @param frame table The MediaWiki frame object
--- @return string HTML output with optional tracking categories
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if not args.uuid and not (args.name or result.apiData.name) then
		return '<span class="error">Entity module error: no uuid or name provided</span>' .. CATEGORY_ENTITY_ERROR
	end

	local sections = buildSections(result.chain, result.apiData, args)
	local storeSuccess = storeStructuredData(result.chain, result.apiData, args)

	setShortDescription(frame, result.typeInfo, result.chain, result.apiData, args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/styles.css' },
	})

	local html = infobox.render({
		title = result.apiData.name or args.name or mw.title.getCurrentTitle().text,
		subtitle = result.displayType,
		image = args.image,
		sections = sections,
	})

	return styles
		.. html
		.. buildCategories(result.typeInfo, result.apiData, args, result.hasApiError, not storeSuccess)
end

return p
