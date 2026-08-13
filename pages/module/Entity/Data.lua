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
local editorial = require('Module:Entity/Editorial')
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
	-- Fall back to the page's stored SMW uuid only when the editor hasn't declared an
	-- explicit kind. An editorial page (|kind=…) states its identity in wikitext; it
	-- must not resurrect a stale/placeholder SMW uuid (e.g. an all-zeros or legacy
	-- dev-stub value) — that would defeat editorial mode and re-store the bad uuid.
	if not args.uuid and not args.kind then
		args.uuid = readSmwUuid(frame)
	end
	return args
end

--- Builds the resolver API config. The API's `search/<uuid>` endpoint answers with
--- a redirect to the canonical typed record, so one fetch resolves a UUID of any
--- kind (Apiunto follows it only because the source sets `followRedirects`).
---
--- Query params survive the redirect, so the config carries the union of every
--- kind's primary params: an endpoint ignores includes it doesn't recognise, and
--- only the items endpoint honours any of them, so the union is free on the wire.
--- It is derived from the registry rather than hardcoded so a kind changing its
--- includes cannot leave the resolver behind.
---
--- @return EntityApiConfig
local function buildResolverConfig()
	local includes, seen, locale = {}, {}, nil
	for _, mod in ipairs(registry.kinds) do
		local params = (mod.getApiConfigs()[1] or {}).params or {}
		locale = locale or params.locale
		for token in string.gmatch(params.include or '', '[^,]+') do
			if not seen[token] then
				seen[token] = true
				includes[#includes + 1] = token
			end
		end
	end
	return {
		name = 'StarCitizenWikiAPI',
		endpoint = 'search/%s',
		params = { locale = locale, include = table.concat(includes, ',') },
		-- Every single-record endpoint the resolver can land on wraps its payload
		-- in `data`.
		responseDataPath = 'data',
	}
end

--- Asks each registered kind to identify a payload. Returns nil when no kind
--- claims it — the resolver also resolves blueprints and starmap locations, which
--- Entity does not model. Every matches() must therefore be positive and
--- order-independent, since all of them see the same single payload.
---
--- @param apiData table|nil
--- @return table|nil
local function identifyKind(apiData)
	if apiData == nil then
		return nil
	end
	for _, mod in ipairs(registry.kinds) do
		if mod.matches(apiData) then
			return mod
		end
	end
	return nil
end

--- Endpoint-by-endpoint fallback: fetches each kind's identity endpoint until one
--- matches, costing up to one request per registered kind. Failures on a
--- NON-matching kind don't count toward hasApiError (the items endpoint rejecting
--- a vehicle UUID is expected) — only the matched kind's own fetch error does.
---
--- @param uuid string
--- @return table|nil matchedKind
--- @return table apiData
--- @return table<string, boolean> fetchedEndpoints
--- @return boolean hasApiError
local function probeKindByEndpoint(uuid)
	local fetchedEndpoints = {}
	for _, mod in ipairs(registry.kinds) do
		local primaryConfig = mod.getApiConfigs()[1]
		local data, err = api.fetchApi(primaryConfig, uuid)
		fetchedEndpoints[primaryConfig.endpoint] = true
		if mod.matches(data) then
			return mod, data, fetchedEndpoints, err ~= nil
		end
	end
	return nil, {}, fetchedEndpoints, false
end

--- Resolves the UUID's kind. The resolver answers in a single request whatever the
--- kind; the per-endpoint probe runs only when it can't — an unknown UUID, a kind
--- Entity doesn't model, or a transient failure such as a rate-limit rejection on
--- the throttled search endpoint. That fallback is what keeps pages rendering when
--- search is unavailable, at the old cost. With no uuid, nothing is fetched.
---
--- @param args table
--- @return table|nil matchedKind
--- @return table apiData  ({} when nothing matched)
--- @return table<string, boolean> fetchedEndpoints  endpoints already fetched
--- @return boolean hasApiError
local function probeKind(args)
	if not args.uuid then
		return nil, {}, {}, false
	end

	local resolverConfig = buildResolverConfig()
	local data = api.fetchApi(resolverConfig, args.uuid)
	local matchedKind = identifyKind(data)

	if matchedKind then
		-- The resolver landed on the matched kind's own endpoint, so its payload is
		-- already in hand. Mark that endpoint fetched too, or fetchChainExtras would
		-- request it again: it dedupes on the endpoint pattern, and `search/%s` is
		-- not `items/%s`.
		local fetchedEndpoints = { [resolverConfig.endpoint] = true }
		local primaryConfig = matchedKind.getApiConfigs()[1]
		if primaryConfig then
			fetchedEndpoints[primaryConfig.endpoint] = true
		end
		return matchedKind, data, fetchedEndpoints, false
	end

	return probeKindByEndpoint(args.uuid)
end

--- Resolves the leaf module from the matched kind: the kind's resolveSubtype
--- refinement when present, else the kind itself. No match falls back to Item so
--- sibling renderers still get a usable chain; a given-but-unmatched uuid is
--- surfaced as an error.
---
--- @param matchedKind table|nil
--- @param apiData table
--- @param hasUuid boolean
--- @param args table|nil
--- @return table leafMod
--- @return boolean hasApiError
local function resolveLeaf(matchedKind, apiData, hasUuid, args)
	if matchedKind then
		if matchedKind.resolveSubtype then
			return matchedKind.resolveSubtype(apiData, args) or matchedKind, false
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

	local leafMod, leafErr = resolveLeaf(matchedKind, apiData, args.uuid ~= nil, args)
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

--- A genuine in-game record: the API returned a record carrying a reliable
--- identity key (uuid). NOT "the fetch returned non-nil" — the API can return a
--- stub/partial for some in-concept entities, so presence-of-record alone is not
--- enough to treat a page as in-game.
--- @param apiData table|nil
--- @return boolean
local function isGenuineRecord(apiData)
	return type(apiData) == 'table' and apiData.uuid ~= nil and apiData.uuid ~= ''
end

--- Looks up a registered kind by `args.kind` that opts into editorial mode
--- (mod.editorialMode == true). Case-insensitive on the kind name. Returns nil when
--- args.kind is absent, unknown, or names a kind that has not opted in. Consulted
--- only when there is no genuine record, so it is a planned-page declaration that
--- is harmless on a page that later gets a uuid.
--- @param args table
--- @return table|nil
local function resolveEditorialKind(args)
	local kindName = args.kind
	if type(kindName) ~= 'string' or kindName == '' then
		return nil
	end
	local wanted = mw.ustring.lower(kindName)
	for _, mod in ipairs(registry.kinds) do
		if mod.editorialMode == true and type(mod.name) == 'string' and mw.ustring.lower(mod.name) == wanted then
			return mod
		end
	end
	return nil
end

--- Primary entry point for sibling renderers. Fetches API data, resolves the
--- type chain, and packages everything a renderer needs into a single table.
---
--- @param args table Parsed wikitext args (use p.parseArgs to produce)
--- @return { args: table, kind: string, apiData: table, chain: table[], facets: table[], typeInfo: table|nil, displayType: string|nil, hasApiError: boolean, resolved: table, editorialData: table, hasManualApiData: boolean, unresolvedReference: boolean, matchedKind: table|nil, family: string|nil }
function p.get(args)
	local apiData, chain, hasApiError, matchedKind = fetchApiData(args)

	-- Editorial mode: with no genuine in-game record (no apiData.uuid — either no
	-- record came back, or the API returned a stub the matched kind accepted), a
	-- page that declares an opted-in |kind= renders from editorial args alone.
	-- apiData is reset to {} so the render is driven entirely by the editorial
	-- `resolved` layer; sections are already data-gated, so a planned page is a
	-- clean subset. A provided-but-unresolved uuid is surfaced as a tracking
	-- category (result.unresolvedReference) rather than silently masquerading as a
	-- planned page.
	local unresolvedReference = false
	if not isGenuineRecord(apiData) then
		local editorialKind = resolveEditorialKind(args)
		if editorialKind then
			matchedKind = editorialKind
			apiData = {}
			local leafMod = resolveLeaf(editorialKind, apiData, false, args)
			chain = assembly.buildChain(leafMod)
			hasApiError = false
			if args.uuid ~= nil and args.uuid ~= '' then
				unresolvedReference = true
			end
		end
	end

	-- Canonical kind name for sibling renderers — Item when nothing matched,
	-- mirroring resolveLeaf's fallback. Renderers branch on this instead of
	-- re-deriving the kind from apiData fields.
	local kind = (matchedKind and matchedKind.name) or 'Item'

	local leaf = chain[#chain]
	local family = leaf and leaf.family
	local typeInfo, displayType
	if leaf and leaf.getTypeInfo then
		typeInfo = leaf.getTypeInfo(apiData, args)
		displayType = typeInfo and typeInfo.name
	end
	if not typeInfo then
		typeInfo, displayType = typeResolver.resolve(args.type or apiData.type, apiData.classification)
	end

	local resolved, editorialData, hasManualApiData = {}, {}, false
	if matchedKind and matchedKind.getEditorialManifest then
		local manifest = matchedKind.getEditorialManifest()
		resolved = editorial.resolve(apiData, args, manifest)
		editorialData = editorial.toStructuredData(resolved, manifest)
		hasManualApiData = editorial.hasManualApiData(resolved)
	end

	-- Kind-contributed browse categories that need editorial (resolved) data.
	-- typeInfo may be a frozen typeResolver result, so copy before appending.
	if matchedKind and matchedKind.getCategories then
		local extra = matchedKind.getCategories(apiData, args, resolved, family)
		if type(extra) == 'table' and extra[1] ~= nil then
			local copy = {}
			for k, v in pairs(typeInfo or {}) do
				copy[k] = v
			end
			local cats = {}
			for _, c in ipairs(copy.categories or {}) do
				cats[#cats + 1] = c
			end
			for _, c in ipairs(extra) do
				cats[#cats + 1] = c
			end
			copy.categories = cats
			typeInfo = copy
			displayType = displayType or copy.name
		end
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
		resolved = resolved,
		editorialData = editorialData,
		hasManualApiData = hasManualApiData,
		unresolvedReference = unresolvedReference,
		matchedKind = matchedKind,
		family = family,
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	detectFacets = detectFacets,
	resolveLeaf = resolveLeaf,
	isGenuineRecord = isGenuineRecord,
	resolveEditorialKind = resolveEditorialKind,
	buildResolverConfig = buildResolverConfig,
	identifyKind = identifyKind,
}

return p
