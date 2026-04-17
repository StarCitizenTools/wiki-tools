require('strict')

--- @module Entity/Data
--- Entity data provider. Parses wikitext args, fetches API data through the
--- type chain, resolves the type's display metadata, and returns a normalized
--- result consumable by any sibling renderer (Entity, Description, etc.).
---
--- Stateless — module locals do not persist across #invoke calls. Repeated
--- calls within a page parse rely on the Apiunto HTTP cache to stay cheap,
--- so each sibling template can call p.get independently without coordination.

local util = require('Module:Entity/Util')

local p = {}

--- Maps API type strings to module paths. Add new entries here when creating
--- new subtypes.
local typeMapping = {
	Food = 'Entity/Item/Food',
	Drink = 'Entity/Item/Drink',
	-- WeaponGun = 'Entity/Item/WeaponGun',
	-- QuantumDrive = 'Entity/Item/QuantumDrive',
}

--- Default module path when the API type is not found in typeMapping.
local defaultModule = 'Entity/Item'

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

--- Parses frame arguments into a simple table, merging frame.args with
--- parent frame args (template invocation). Empty strings become nil.
---
--- @param frame table The MediaWiki frame object
--- @return table args
function p.parseArgs(frame)
	local args = {}
	for key, value in pairs(frame.args) do
		if value and value ~= '' then
			args[key] = value
		end
	end
	if frame:getParent() then
		for key, value in pairs(frame:getParent().args) do
			if value and value ~= '' and not args[key] then
				args[key] = value
			end
		end
	end
	return args
end

--- Fetches API data and resolves the type chain. Runs a preliminary Base+Item
--- fetch to determine entity type, then expands the chain and fetches any
--- additional APIs the subtype needs.
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
	-- Coupled to the Item hierarchy — Vehicle will need its own preliminary chain.
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

--- Resolves display metadata for an API type from types.json.
---
--- @param apiType string|nil
--- @return table|nil typeInfo
--- @return string|nil displayType Display name (falls back to apiType when unmapped)
local function resolveType(apiType)
	local types = mw.loadJsonData('Module:Entity/Item/types.json')
	local typeInfo = types[apiType]
	return typeInfo, typeInfo and typeInfo.name or apiType
end

--- Primary entry point for sibling renderers. Fetches API data, resolves the
--- type chain, and packages everything a renderer needs into a single table.
---
--- @param args table Parsed wikitext args (use p.parseArgs to produce)
--- @return { args: table, apiData: table, chain: table[], typeInfo: table|nil, displayType: string|nil, hasApiError: boolean }
function p.get(args)
	local apiData, chain, hasApiError = fetchApiData(args)
	local typeInfo, displayType = resolveType(args.type or apiData.type)
	return {
		args = args,
		apiData = apiData,
		chain = chain,
		typeInfo = typeInfo,
		displayType = displayType,
		hasApiError = hasApiError,
	}
end

return p
