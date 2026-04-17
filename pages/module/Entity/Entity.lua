require('strict')

local util = require('Module:Entity/Util')
local structuredData = require('Module:Entity/StructuredData')
local infobox = require('Module:InfoboxLua')

local CATEGORY_API_ERROR = '[[Category:Pages with API errors]]'
local CATEGORY_ENTITY_ERROR = '[[Category:Pages with Entity errors]]'
local CATEGORY_STRUCTURED_DATA_ERROR = '[[Category:Pages with structured data errors]]'

--- Maps API type strings to module paths.
--- Add new entries here when creating new subtypes.
local typeMapping = {
	Food = 'Entity/Item/Food',
	Drink = 'Entity/Item/Drink',
	-- WeaponGun = 'Entity/Item/WeaponGun',
	-- QuantumDrive = 'Entity/Item/QuantumDrive',
}

--- Default module path when the API type is not found in typeMapping.
local defaultModule = 'Entity/Item'

local p = {}

--- Resolves the leaf module from the API type string.
---
--- @param apiType string|nil The type string from the API response
--- @return table The resolved leaf module
local function resolveLeafModule(apiType)
	local modulePath = defaultModule
	if apiType and typeMapping[apiType] then
		modulePath = typeMapping[apiType]
	end
	return require('Module:' .. modulePath)
end

--- Parses frame arguments into a simple table.
---
--- @param frame table The MediaWiki frame object
--- @return table args The parsed arguments
local function parseArgs(frame)
	local args = {}
	for key, value in pairs(frame.args) do
		if value and value ~= '' then
			args[key] = value
		end
	end
	-- Also check parent frame args (template invocation)
	if frame:getParent() then
		for key, value in pairs(frame:getParent().args) do
			if value and value ~= '' and not args[key] then
				args[key] = value
			end
		end
	end
	return args
end

--- Fetches API data and resolves the type chain.
--- Runs a preliminary Base+Item fetch to determine entity type, then expands
--- the chain and fetches any additional APIs the subtype needs.
---
--- @param args table
--- @return table apiData Merged API response data
--- @return table[] chain Module chain (root to leaf)
--- @return boolean hasApiError True if any fetch failed
local function fetchApiData(args)
	local apiData = {}
	local fetchedEndpoints = {}
	local hasApiError = false

	-- Preliminary chain: Base + Item since Item defines the shared endpoint.
	-- This is coupled to the Item hierarchy — Vehicle will need its own preliminary chain.
	if args.uuid then
		local prelimChain = { require('Module:Entity/Base'), require('Module:Entity/Item') }
		local prelimConfigs = util.collectApiConfigs(prelimChain)
		for _, config in ipairs(prelimConfigs) do
			fetchedEndpoints[config.endpoint] = true
		end
		local data, err = util.fetchAllApis(prelimConfigs, args.uuid)
		if err then
			hasApiError = true
		end
		apiData = data
	end

	local apiType = args.type or apiData.type
	local chain = util.buildChain(resolveLeafModule(apiType))

	-- Fetch any additional APIs from subtypes not already fetched
	local additionalConfigs = {}
	for _, mod in ipairs(chain) do
		if mod.getApiConfigs then
			for _, config in ipairs(mod.getApiConfigs()) do
				if not fetchedEndpoints[config.endpoint] then
					table.insert(additionalConfigs, config)
					fetchedEndpoints[config.endpoint] = true
				end
			end
		end
	end

	if #additionalConfigs > 0 and args.uuid then
		local additionalData, additionalError = util.fetchAllApis(additionalConfigs, args.uuid)
		if additionalError then
			hasApiError = true
		end
		for k, v in pairs(additionalData) do
			apiData[k] = v
		end
	end

	return apiData, chain, hasApiError
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

--- Resolves display metadata for an API type from Module:Entity/Item/types.json.
---
--- @param apiType string|nil
--- @return table|nil typeInfo Entry from types.json, or nil if unmapped
--- @return string displayType Display name (falls back to apiType when unmapped)
local function resolveType(apiType)
	local types = mw.loadJsonData('Module:Entity/Item/types.json')
	local typeInfo = types[apiType]
	return typeInfo, typeInfo and typeInfo.name or apiType
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

--- Main entry point for the Entity module.
---
--- @param frame table The MediaWiki frame object
--- @return string HTML output with optional tracking categories
function p.main(frame)
	local args = parseArgs(frame)
	local apiData, chain, hasApiError = fetchApiData(args)

	if not args.uuid and not (args.name or apiData.name) then
		return '<span class="error">Entity module error: no uuid or name provided</span>' .. CATEGORY_ENTITY_ERROR
	end

	local sections = buildSections(chain, apiData, args)
	local storeSuccess = storeStructuredData(chain, apiData, args)
	local typeInfo, displayType = resolveType(args.type or apiData.type)

	setShortDescription(frame, typeInfo, chain, apiData, args)

	local html = infobox.render({
		title = apiData.name or args.name or mw.title.getCurrentTitle().text,
		subtitle = displayType,
		image = args.image,
		sections = sections,
	})

	return html .. buildCategories(typeInfo, hasApiError, not storeSuccess)
end

return p
