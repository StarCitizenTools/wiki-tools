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
local typeResolver = require('Module:Entity/TypeResolver')

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

--- Probes the kind registry: fetches each kind's identity endpoint and asks
--- matches(); first match wins, short-circuiting so common-case items pay one
--- fetch. Probe failures on a NON-matching kind don't count toward hasApiError
--- (a 404 on the items endpoint for a vehicle UUID is expected) — only the
--- matched kind's own fetch error does. With no uuid, nothing is probed.
---
--- @param args table
--- @return table|nil matchedKind
--- @return table apiData  ({} when nothing matched)
--- @return table<string, boolean> fetchedEndpoints  endpoints already fetched
--- @return boolean hasApiError
local function probeKind(args)
	local apiData = {}
	local fetchedEndpoints = {}
	local matchedKind = nil
	local hasApiError = false

	if args.uuid then
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

	return matchedKind, apiData, fetchedEndpoints, hasApiError
end

--- Resolves the leaf module from the matched kind: the kind's resolveSubtype
--- refinement when present, else the kind itself. No match falls back to Item so
--- sibling renderers still get a usable chain; a given-but-unmatched uuid is
--- surfaced as an error.
---
--- @param matchedKind table|nil
--- @param apiData table
--- @param hasUuid boolean
--- @return table leafMod
--- @return boolean hasApiError
local function resolveLeaf(matchedKind, apiData, hasUuid)
	if matchedKind then
		if matchedKind.resolveSubtype then
			return matchedKind.resolveSubtype(apiData) or matchedKind, false
		end
		return matchedKind, false
	end
	return require('Module:Entity/Item'), hasUuid
end

--- Fetches the chain's additional API endpoints (those not already fetched
--- during kind probing), merging them into one table. Marks each fetched
--- endpoint. Returns {}, false when the chain declares no new endpoints.
---
--- @param chain table[]
--- @param uuid string
--- @param fetchedEndpoints table<string, boolean>
--- @return table extraData
--- @return boolean hasError
local function fetchChainExtras(chain, uuid, fetchedEndpoints)
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
	if #additionalConfigs == 0 then
		return {}, false
	end
	return api.fetchAllApis(additionalConfigs, uuid)
end

--- Probes the kind, resolves the leaf, builds the chain, fetches the chain's
--- extra endpoints, and runs the matched kind's enrich hook.
---
--- @param args table
--- @return table apiData Merged API response data
--- @return table[] chain Module chain (root to leaf)
--- @return boolean hasApiError True if any fetch failed
--- @return table|nil matchedKind The probed kind module (nil if none matched)
local function fetchApiData(args)
	local matchedKind, apiData, fetchedEndpoints, hasApiError = probeKind(args)

	local leafMod, leafErr = resolveLeaf(matchedKind, apiData, args.uuid ~= nil)
	hasApiError = hasApiError or leafErr

	local chain = assembly.buildChain(leafMod)

	if args.uuid then
		local extraData, extraErr = fetchChainExtras(chain, args.uuid, fetchedEndpoints)
		hasApiError = hasApiError or extraErr
		for k, v in pairs(extraData) do
			apiData[k] = v
		end
	end

	if matchedKind and matchedKind.enrich then
		apiData = matchedKind.enrich(apiData)
	end

	return apiData, chain, hasApiError, matchedKind
end

--- Primary entry point for sibling renderers. Fetches API data, resolves the
--- type chain, and packages everything a renderer needs into a single table.
---
--- @param args table Parsed wikitext args (use p.parseArgs to produce)
--- @return { args: table, kind: string, apiData: table, chain: table[], typeInfo: table|nil, displayType: string|nil, hasApiError: boolean }
function p.get(args)
	local apiData, chain, hasApiError, matchedKind = fetchApiData(args)

	-- Canonical kind name for sibling renderers — Item when nothing matched,
	-- mirroring resolveLeaf's fallback. Renderers branch on this instead of
	-- re-deriving the kind from apiData fields.
	local kind = (matchedKind and matchedKind.name) or 'Item'

	local leaf = chain[#chain]
	local typeInfo, displayType
	if leaf and leaf.getTypeInfo then
		typeInfo = leaf.getTypeInfo(apiData, args)
		displayType = typeInfo and typeInfo.name
	end
	if not typeInfo then
		typeInfo, displayType = typeResolver.resolve(args.type or apiData.type, apiData.classification)
	end

	return {
		args = args,
		kind = kind,
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
	detectFacets = detectFacets,
	resolveLeaf = resolveLeaf,
}

return p
