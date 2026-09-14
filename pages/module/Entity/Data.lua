require('strict')

--- @module Entity/Data
--- Entity data provider. Parses wikitext args, fetches API data through the
--- type chain, resolves the type's display metadata, and returns a normalized
--- result consumable by any sibling renderer (Entity, Description, etc.).
---
--- Stateless — module locals do not persist across #invoke calls. Repeated
--- calls within a page parse rely on the Apiunto HTTP cache to stay cheap,
--- so each sibling template can call p.get independently without coordination.
---
--- Every hook a chain link may implement is applied here with one merge
--- policy: enrich root-to-leaf, getEditorialManifest merged root-to-leaf
--- (leaf wins), getCategories additive, the rest as Module:Entity and
--- Module:Entity/Infobox apply them.

local api = require('Module:Entity/Api')
local assembly = require('Module:Entity/Assembly')
local editorial = require('Module:Entity/Editorial')
local registry = require('Module:Entity/Registry')
local store = require('Module:Entity/Store')
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

--- Parses frame arguments into a simple table, merging frame.args with
--- parent frame args (template invocation). Empty strings become nil.
--- When `uuid` is absent from both, falls back to the uuid stored in Bucket
--- on a prior link update.
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
	-- No uuid in wikitext and no declared kind: fall back to the uuid this page
	-- stored in Bucket on a previous link update, so sibling renderers can omit
	-- the arg. An editorial page (|kind=) must not resurrect a stale value.
	if not args.uuid and not args.kind then
		args.uuid = store.selfUuid()
	end
	return args
end

--- Looks up a registered kind by name, case-insensitively. Returns nil when the
--- name is absent, empty, or matches no registered kind's `mod.name`. Pure
--- lookup — editorial opt-in and any other gating stay with the callers.
---
--- @param name any
--- @return table|nil
local function kindByName(name)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local wanted = mw.ustring.lower(name)
	for _, mod in ipairs(registry.kinds) do
		if type(mod.name) == 'string' and mw.ustring.lower(mod.name) == wanted then
			return mod
		end
	end
	return nil
end

--- Endpoint-by-endpoint probe: fetches each kind's identity endpoint in registry
--- order until one matches, costing up to one request per registered kind.
--- Failures on a NON-matching kind don't count toward hasApiError (the items
--- endpoint rejecting a vehicle UUID is expected) — only the matched kind's own
--- fetch error does.
---
--- A probe miss must never be cached, or a page would pin a duplicate record
--- under a foreign key: `items/<uuid>` answers a VEHICLE uuid with a redirect to
--- the vehicle record (the other typed endpoints answer a foreign uuid 404), and
--- Apiunto caches a followed redirect under the URL it requested. The
--- StarCitizenWikiAPI source therefore keeps `followRedirects` OFF, so the
--- redirect fails the fetch and the walk moves on to `vehicles/<uuid>`.
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

--- Resolves the UUID's kind. A page that declares its kind (`|kind=`) alongside
--- the uuid is trusted first: the declared kind's own primary endpoint is fetched
--- directly, skipping the probe. The declaration is trusted because it is what
--- admits records the probe can never claim — a jump point's location record
--- reports type 'Anomaly', a token wreck sites also carry — and because it is
--- gated: the declared kind must claim the fetched record via matches() — a
--- kind claims exactly the records it can render, jump points included — so a
--- wrong uuid (a vehicle uuid pasted into {{Location}}) fails the gate and
--- falls through to the probe unchanged, a fetch error included.
---
--- Otherwise probeKindByEndpoint walks the registry. Every fetch, declared or
--- probed, targets a kind's TYPED endpoint, and that is deliberate: Apiunto
--- caches by requested URL, so one record lands on one cache key however the
--- page is invoked — the infobox declares its kind through a facade
--- (Template:Vehicle, Template:Location), sibling renderers cannot and probe,
--- and both end on the same `vehicles/<uuid>` request. The API's `search/<uuid>`
--- resolver is NOT used as a shortcut: its key can never coincide with a typed
--- fetch of the same record, and upstream it is rate-limited (60/min) and
--- uncacheable, so purge sweeps fell back to the probe anyway. With no uuid,
--- nothing is fetched.
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

	local declaredKind = kindByName(args.kind)
	local declaredConfig = declaredKind and declaredKind.getApiConfigs()[1]
	if declaredConfig then
		local data, err = api.fetchApi(declaredConfig, args.uuid)
		-- Validity gate (see the docstring). matches() is nil-safe by contract, so a
		-- failed fetch (data nil) falls straight through.
		if declaredKind.matches(data) then
			return declaredKind, data, { [declaredConfig.endpoint] = true }, err ~= nil
		end
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

--- Runs every chain link's enrich hook root to leaf, each receiving the
--- previous link's apiData through ctx. A leaf attaches the secondary record
--- only it renders (StarSystem the starmap system, JumpPoint the celestial
--- object); a kind's enrich (Commodity's raw/refined merge) runs first.
--- @param chain table[]
--- @param ctx EntityHookContext
--- @return table apiData
local function enrichChain(chain, ctx)
	for _, mod in ipairs(chain) do
		if mod.enrich then
			ctx.apiData = assembly.callHook(mod, 'enrich', ctx)
		end
	end
	return ctx.apiData
end

--- Probes the kind, resolves the leaf, builds the chain, fetches the chain's
--- extra endpoints, and runs the chain's enrich hooks.
---
--- @param args table
--- @return EntityHookContext ctx apiData: merged API response data
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

	local ctx = { apiData = apiData, args = args }
	enrichChain(chain, ctx)

	return ctx, chain, hasApiError, matchedKind
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
	local mod = kindByName(args.kind)
	if mod and mod.editorialMode == true then
		return mod
	end
	return nil
end

--- The editorial fork's data path: empty apiData, leaf re-resolved from args,
--- chain rebuilt, and the chain's enrich hooks run with args — so a kind
--- can attach secondary API data (Location fetches the starmap record by name)
--- even though no identity record exists.
--- @param editorialKind table
--- @param args table
--- @return EntityHookContext ctx
--- @return table[] chain
local function runEditorialFork(editorialKind, args)
	local apiData = {}
	local leafMod = resolveLeaf(editorialKind, apiData, false, args)
	local chain = assembly.buildChain(leafMod)
	local ctx = { apiData = apiData, args = args }
	enrichChain(chain, ctx)
	return ctx, chain
end

--- Primary entry point for sibling renderers. Fetches API data, resolves the
--- type chain, and packages everything a renderer needs into a single table.
---
--- @param args table Parsed wikitext args (use p.parseArgs to produce)
--- @return { args: table, kind: string, apiData: table, chain: table[], facets: table[], typeInfo: table|nil, displayType: string|nil, hasApiError: boolean, resolved: table, editorialData: table, hasManualApiData: boolean, unresolvedReference: boolean, matchedKind: table|nil, family: string|nil, ctx: EntityHookContext }
function p.get(args)
	local ctx, chain, hasApiError, matchedKind = fetchApiData(args)

	-- Editorial mode: with no genuine in-game record (no apiData.uuid — either no
	-- record came back, or the API returned a stub the matched kind accepted), a
	-- page that declares an opted-in |kind= renders from editorial args alone.
	-- apiData is reset to {} so the render is driven entirely by the editorial
	-- `resolved` layer; sections are already data-gated, so a planned page is a
	-- clean subset. A provided-but-unresolved uuid is surfaced as a tracking
	-- category (result.unresolvedReference) rather than silently masquerading as a
	-- planned page.
	local unresolvedReference = false
	if not isGenuineRecord(ctx.apiData) then
		local editorialKind = resolveEditorialKind(args)
		if editorialKind then
			matchedKind = editorialKind
			ctx, chain = runEditorialFork(editorialKind, args)
			hasApiError = false
			if args.uuid ~= nil and args.uuid ~= '' then
				unresolvedReference = true
			end
		end
	end

	-- Canonical kind name (Item when nothing matched, mirroring resolveLeaf's
	-- fallback), exposed as result.kind and ctx.kind for consumers and hooks. The
	-- Bucket route is deliberately NOT this value: Module:Entity passes
	-- result.matchedKind's name, so a page whose kind never resolved writes only
	-- its entity-routable keys instead of routing as an Item.
	local kind = (matchedKind and matchedKind.name) or 'Item'

	local leaf = chain[#chain]
	local family = leaf and leaf.family
	local typeInfo, displayType
	if leaf and leaf.getTypeInfo then
		typeInfo = assembly.callHook(leaf, 'getTypeInfo', ctx)
		displayType = typeInfo and typeInfo.name
	end
	if not typeInfo then
		typeInfo, displayType = typeResolver.resolve(args.type or ctx.apiData.type, ctx.apiData.classification)
	end

	local resolved, editorialData, hasManualApiData = {}, {}, false
	local manifest = assembly.mergeEditorialManifests(chain)
	if manifest then
		resolved = editorial.resolve(ctx.apiData, args, manifest)
		editorialData = editorial.toStructuredData(resolved, manifest)
		hasManualApiData = editorial.hasManualApiData(resolved)
	end
	ctx.resolved = resolved

	-- Browse categories every chain link contributes (additive, root to leaf),
	-- appended to typeInfo.categories. typeInfo may be a frozen typeResolver
	-- result, so copy before appending.
	local extra = assembly.collect(chain, 'getCategories', ctx)
	if extra[1] ~= nil then
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

	ctx.typeInfo = typeInfo
	ctx.kind = kind
	ctx.family = family

	return {
		args = args,
		kind = kind,
		apiData = ctx.apiData,
		chain = chain,
		facets = detectFacets(ctx.apiData),
		typeInfo = typeInfo,
		displayType = displayType,
		hasApiError = hasApiError,
		resolved = resolved,
		editorialData = editorialData,
		hasManualApiData = hasManualApiData,
		unresolvedReference = unresolvedReference,
		matchedKind = matchedKind,
		family = family,
		ctx = ctx,
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	detectFacets = detectFacets,
	resolveLeaf = resolveLeaf,
	isGenuineRecord = isGenuineRecord,
	resolveEditorialKind = resolveEditorialKind,
	kindByName = kindByName,
	runEditorialFork = runEditorialFork,
}

return p
