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
	WeaponPersonal = 'Entity/Item/WeaponPersonal',
	-- WeaponGun = 'Entity/Item/WeaponGun',
	-- QuantumDrive = 'Entity/Item/QuantumDrive',
}

--- Default module path when the API type is not found in typeMapping.
local defaultModule = 'Entity/Item'

--- Resolves the leaf module from the API type string and response.
---
--- Vehicles dispatch via the `is_vehicle` boolean rather than the type
--- string — vehicle "type" in the API is the role taxonomy ("multi",
--- "freight", …), not a top-level entity kind, so it can't be added to
--- typeMapping the same way item subtypes are.
---
--- @param apiType string|nil The type string from the API response
--- @param apiData table|nil The merged API response (for non-string dispatch signals)
--- @return table The resolved leaf module
local function resolveLeafModule(apiType, apiData)
	if apiData and apiData.is_vehicle then
		return require('Module:Entity/Vehicle')
	end
	local modulePath = defaultModule
	if apiType and typeMapping[apiType] then
		modulePath = typeMapping[apiType]
	end
	return require('Module:' .. modulePath)
end

--- Returns the SMW property prefix for the current page's namespace.
--- Mirrors Module:Entity/StructuredData so reads round-trip with writes:
--- mainspace uses no prefix, other namespaces are prefixed (e.g.
--- `user_` on User: pages) so test pages don't pollute canonical
--- queries.
---
--- @return string
local function getSmwPrefix()
	local nsText = mw.title.getCurrentTitle().nsText
	if nsText == '' then
		return ''
	end
	return nsText:lower():gsub(' ', '_') .. '_'
end

--- Reads the entity UUID stored on the current page via SMW's `#show`
--- parser function. Tries the new lowercase `uuid` property first,
--- then the legacy `UUID` property for compatibility with pages that
--- haven't been re-rendered since the schema change. Sibling renderers
--- can therefore omit the uuid arg as long as Module:Entity was
--- invoked earlier on the page (so the SMW store has the value from
--- the previous parse).
---
--- @param frame table
--- @return string|nil
local function readSmwUuid(frame)
	local prefix = getSmwPrefix()
	local pageName = mw.title.getCurrentTitle().fullText
	for _, propName in ipairs({ prefix .. 'uuid', prefix .. 'UUID' }) do
		local value = frame:callParserFunction('#show', pageName, '?' .. propName)
		if value and value ~= '' then
			return value
		end
	end
	return nil
end

--- Parses frame arguments into a simple table, merging frame.args with
--- parent frame args (template invocation). Empty strings become nil.
--- When `uuid` is absent from both, falls back to the SMW-stored UUID
--- on the current page (set by Module:Entity on a prior parse).
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
	if not args.uuid then
		args.uuid = readSmwUuid(frame)
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

	-- Preliminary chain hits both the items and vehicles endpoints in
	-- parallel so a UUID can resolve regardless of which kind it is. Each
	-- endpoint 404s for the other kind, so only the right one contributes
	-- data; the Apiunto cache absorbs the cost of the failing fetch.
	if args.uuid then
		local prelimChain = {
			require('Module:Entity/Base'),
			require('Module:Entity/Item'),
			require('Module:Entity/Vehicle'),
		}
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
	local chain = util.buildChain(resolveLeafModule(apiType, apiData))

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
