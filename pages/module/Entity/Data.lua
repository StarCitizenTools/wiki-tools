require('strict')

--- @module Entity/Data
--- Entity data provider. Parses wikitext args, fetches API data through the
--- type chain, resolves the type's display metadata, and returns a normalized
--- result consumable by any sibling renderer (Entity, Description, etc.).
---
--- Stateless — module locals do not persist across #invoke calls. Repeated
--- calls within a page parse rely on the Apiunto HTTP cache to stay cheap,
--- so each sibling template can call p.get independently without coordination.

local api = require('Module:Entity/Api')
local assembly = require('Module:Entity/Assembly')
local registry = require('Module:Entity/Registry')

local p = {}

--- Returns the list of facet modules whose matches(apiData) is true. Pure and
--- nil-safe so it is unit-testable against the real registry.
---
--- @param apiData table|nil
--- @return table[]
local function detectFacets(apiData)
	local matched = {}
	for _, facet in ipairs(registry.facets) do
		if facet.matches(apiData) then
			table.insert(matched, facet)
		end
	end
	return matched
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

	-- Note: args.type no longer influences kind selection (it did under the
	-- old item-only typeMapping dispatch). It still flows through `p.get`'s
	-- `resolveType` call, but only as the type-map fallback key for
	-- typeInfo / displayType — for items, a mapped `Ship.*` classification
	-- takes precedence over it. The kind is still determined entirely by the
	-- API response shape via matches().

	if args.uuid then
		-- Sequential probing: fetch each kind's primary endpoint, ask the
		-- kind if the response matches. First match wins; short-circuit so
		-- common-case items pay one fetch.
		--
		-- Probe failures on a non-matching kind don't count toward
		-- hasApiError — a 404 on the items endpoint for a vehicle UUID is
		-- expected, not an error. Only the matched kind's fetch (and the
		-- "no kind matched" case below) sets the flag.
		for _, mod in ipairs(registry.kinds) do
			local primaryConfig = mod.getApiConfigs()[1]
			local data, err = api.fetchApi(primaryConfig, args.uuid)
			fetchedEndpoints[primaryConfig.endpoint] = true
			if mod.matches(data) then
				apiData = data
				matchedKind = mod
				if err then
					hasApiError = true
				end
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

	local chain = assembly.buildChain(leafMod)

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
		local additionalData, additionalError = api.fetchAllApis(additionalConfigs, args.uuid)
		if additionalError then
			hasApiError = true
		end
		for k, v in pairs(additionalData) do
			apiData[k] = v
		end
	end

	if matchedKind and matchedKind.enrich then
		apiData = matchedKind.enrich(apiData)
	end

	return apiData, chain, hasApiError
end

--- Resolves an item's `classification` path (item-endpoint only) to curated
--- display metadata via Module:Entity/Item/classifications.json, by most-specific
--- matching prefix: try the full path, then drop trailing `.segment`s. Only
--- `Ship.*` paths are consulted; returns nil otherwise (callers fall back to the
--- type map). The API's generated `classification_label` is intentionally unused.
---
--- @param classification string|nil
--- @return table|nil { name, category }
local function resolveClassification(classification)
	if type(classification) ~= 'string' or classification:sub(1, 5) ~= 'Ship.' then
		return nil
	end
	local map = mw.loadJsonData('Module:Entity/Item/classifications.json')
	local path = classification
	while path and path ~= '' do
		local entry = map[path]
		if type(entry) == 'table' then
			return entry
		end
		path = path:match('^(.*)%.[^.]+$')
	end
	return nil
end

--- Resolves display metadata (typeInfo + display name). For items the curated
--- classification map wins (most-specific Ship.* prefix); otherwise falls back to
--- the type map (types.json) — which covers FPS items and any kind without a
--- mapped classification (e.g. vehicles, whose endpoint has no `classification`).
---
--- @param apiType string|nil
--- @param classification string|nil
--- @return table|nil typeInfo
--- @return string|nil displayType Display name (falls back to apiType when unmapped)
local function resolveType(apiType, classification)
	local typeInfo = resolveClassification(classification)
	if not typeInfo then
		local types = mw.loadJsonData('Module:Entity/Item/types.json')
		typeInfo = types[apiType]
	end
	return typeInfo, typeInfo and typeInfo.name or apiType
end

--- Primary entry point for sibling renderers. Fetches API data, resolves the
--- type chain, and packages everything a renderer needs into a single table.
---
--- @param args table Parsed wikitext args (use p.parseArgs to produce)
--- @return { args: table, apiData: table, chain: table[], typeInfo: table|nil, displayType: string|nil, hasApiError: boolean }
function p.get(args)
	local apiData, chain, hasApiError = fetchApiData(args)

	local leaf = chain[#chain]
	local typeInfo, displayType
	if leaf and leaf.getTypeInfo then
		typeInfo = leaf.getTypeInfo(apiData, args)
		displayType = typeInfo and typeInfo.name
	end
	if not typeInfo then
		typeInfo, displayType = resolveType(args.type or apiData.type, apiData.classification)
	end

	return {
		args = args,
		apiData = apiData,
		chain = chain,
		facets = detectFacets(apiData),
		typeInfo = typeInfo,
		displayType = displayType,
		hasApiError = hasApiError,
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolveClassification = resolveClassification,
	resolveType = resolveType,
	detectFacets = detectFacets,
}

return p
