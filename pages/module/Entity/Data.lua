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

--- Ordered registry of top-level entity kinds. Sequential probing walks
--- this list, calling each module's `getApiConfigs()[1]` endpoint and
--- `matches()` predicate. First match wins.
---
--- Order is probe precedence — Item first because items dominate the
--- page mix (matches on the first fetch, short-circuits before the
--- vehicles endpoint is touched). Vehicle pages pay one cold-cache
--- failed-fetch on the items endpoint, which Apiunto caches.
---
--- Adding a new kind (e.g. Location) is a single entry here, plus a
--- module file exposing `matches`, `getApiConfigs`, and optionally
--- `resolveSubtype`.
local kindModules = {
	require('Module:Entity/Item'),
	require('Module:Entity/Vehicle'),
}

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

--- Probes the kind registry for the entity's kind, fetches its primary
--- data, then expands the chain and fetches any additional APIs the
--- leaf needs.
---
--- @param args table
--- @return table apiData Merged API response data
--- @return table[] chain Module chain (root to leaf)
--- @return boolean hasApiError True if any fetch failed
local function fetchApiData(args)
	local apiData = {}
	local fetchedEndpoints = {}
	local hasApiError = false
	local matchedKind = nil

	if args.uuid then
		-- Sequential probing: fetch each kind's primary endpoint, ask the
		-- kind if the response matches. First match wins; short-circuit so
		-- common-case items pay one fetch.
		for _, mod in ipairs(kindModules) do
			local primaryConfig = mod.getApiConfigs()[1]
			local data, err = util.fetchApi(primaryConfig, args.uuid)
			fetchedEndpoints[primaryConfig.endpoint] = true
			if err then
				hasApiError = true
			end
			if mod.matches(data) then
				apiData = data
				matchedKind = mod
				break
			end
		end
	end

	-- Resolve the leaf module:
	-- - Matched kind: refine via the kind's resolveSubtype if it has one.
	-- - No match (but a UUID was given): fall back to Item so siblings get
	--   a usable chain; surface as hasApiError so callers can render
	--   "no data" placeholders.
	-- - No UUID at all: same Item fallback, no error.
	local leafMod
	if matchedKind then
		if matchedKind.resolveSubtype then
			leafMod = matchedKind.resolveSubtype(apiData) or matchedKind
		else
			leafMod = matchedKind
		end
	else
		leafMod = require('Module:Entity/Item')
		if args.uuid then
			hasApiError = true
		end
	end

	local chain = util.buildChain(leafMod)

	-- Pull any extra endpoints the chain declares, skipping anything we
	-- already fetched during kind probing.
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
