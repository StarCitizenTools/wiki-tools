require('strict')

local data = require('Module:Entity/Data')
local util = require('Module:Entity/Util')
local structuredData = require('Module:Entity/StructuredData')
local infobox = require('Module:InfoboxLua')

local CATEGORY_API_ERROR = '[[Category:Pages with API errors]]'
local CATEGORY_ENTITY_ERROR = '[[Category:Pages with Entity errors]]'
local CATEGORY_STRUCTURED_DATA_ERROR = '[[Category:Pages with structured data errors]]'

local p = {}

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

--- Assembles all infobox sections: chain contributions, metadata, external sites.
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

--- Builds the trailing category wikitext: item type + tracking categories.
---
--- @param typeInfo table|nil
--- @param hasApiError boolean
--- @param hasStructuredDataError boolean
--- @return string
local function buildCategories(typeInfo, hasApiError, hasStructuredDataError)
	local categories = ''
	if typeInfo then
		categories = categories .. '[[Category:' .. (typeInfo.category or typeInfo.name) .. ']]'
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

	local html = infobox.render({
		title = result.apiData.name or args.name or mw.title.getCurrentTitle().text,
		subtitle = result.displayType,
		image = args.image,
		sections = sections,
	})

	return html .. buildCategories(result.typeInfo, result.hasApiError, not storeSuccess)
end

return p
