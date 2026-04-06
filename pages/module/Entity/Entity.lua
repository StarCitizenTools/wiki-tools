require('strict')

local util = require('Module:Entity/Util')
local structuredData = require('Module:Entity/StructuredData')
local infobox = require('Module:InfoboxLua')

local CATEGORY_API_ERROR = '[[Category:Pages with API errors]]'
local CATEGORY_ENTITY_ERROR = '[[Category:Pages with Entity errors]]'
local CATEGORY_SMW_ERROR = '[[Category:Pages with structured data errors]]'

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

--- Main entry point for the Entity module.
---
--- @param frame table The MediaWiki frame object
--- @return string HTML output with optional tracking categories
function p.main(frame)
	local args = parseArgs(frame)
	local hasApiError = false
	local hasSmwError = false

	-- Initial API fetch to determine type.
	-- Uses Base + Item as a preliminary chain since Item defines the shared endpoint.
	-- This is coupled to the Item hierarchy — Vehicle will need its own preliminary chain.
	local apiData = {}
	local fetchedEndpoints = {}

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

	-- Determine entity type
	local apiType = args.type or apiData.type

	-- Validate we have minimum required data
	local name = args.name or apiData.name
	if not args.uuid and not name then
		return '<span class="error">Entity module error: no uuid or name provided</span>' .. CATEGORY_ENTITY_ERROR
	end

	-- Resolve type chain
	local leafModule = resolveLeafModule(apiType)
	local chain = util.buildChain(leafModule)

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

	-- Collect sections from chain
	local sectionsList = {}
	for _, mod in ipairs(chain) do
		if mod.getSections then
			table.insert(sectionsList, mod.getSections(apiData, args))
		end
	end
	local sections = util.mergeSections(sectionsList)

	-- Append metadata section (always last)
	table.insert(sections, {
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
	})

	-- Collect structured data from chain
	local dataList = {}
	for _, mod in ipairs(chain) do
		if mod.getStructuredData then
			table.insert(dataList, mod.getStructuredData(apiData, args))
		end
	end
	local data = util.mergeStructuredData(dataList)

	-- Store structured data (best-effort)
	local storeSuccess = structuredData.store(data)
	if not storeSuccess then
		hasSmwError = true
	end

	-- Resolve display name for type
	local typeNames = mw.loadJsonData('Module:Entity/Item/typeNames.json')
	local displayType = typeNames[apiType] or apiType

	-- Render via InfoboxLua
	local html = infobox.render({
		title = apiData.name or args.name or mw.title.getCurrentTitle().text,
		subtitle = displayType,
		image = args.image,
		sections = sections,
	})

	-- Append tracking categories
	local categories = ''
	if hasApiError then
		categories = categories .. CATEGORY_API_ERROR
	end
	if hasSmwError then
		categories = categories .. CATEGORY_SMW_ERROR
	end

	return html .. categories
end

return p
