require('strict')

local data = require('Module:Entity/Data')
local assembly = require('Module:Entity/Assembly')
local structuredData = require('Module:Entity/StructuredData')
local entityInfobox = require('Module:Entity/Infobox')
local categories = require('Module:Entity/Categories')

local CATEGORY_ENTITY_ERROR = '[[Category:Pages with Entity errors]]'

local p = {}

--- Collects structured data from the chain and facets and persists it via the backend.
---
--- @param chain table[]
--- @param facets table[]
--- @param ctx EntityHookContext
--- @param editorialData table|nil Pre-projected key-value pairs from the editorial layer
--- @param kind string|nil Kind name, selects the Bucket tables the page may write; nil when no kind
---   matched (e.g. no uuid), in which case only the entity-routable keys are written
--- @return boolean success True if the backend accepted the data
--- @return string[]|nil unregistered Emitter keys not registered in properties.json, or nil
local function storeStructuredData(chain, facets, ctx, editorialData, kind)
	local dataList = {}
	for _, mod in ipairs(chain) do
		if mod.getStructuredData then
			table.insert(dataList, assembly.callHook(mod, 'getStructuredData', ctx))
		end
	end
	for _, facet in ipairs(facets) do
		if facet.getStructuredData then
			table.insert(dataList, assembly.callHook(facet, 'getStructuredData', ctx))
		end
	end
	local merged = assembly.mergeStructuredData(dataList)
	for k, v in pairs(editorialData or {}) do
		merged[k] = v
	end
	-- `subject_type` is the page's most-specific structural type (fine-grained:
	-- "Gun", "Cooler", …), deliberately distinct from the coarse `result.kind`
	-- (Item / Vehicle / …). It is the same value that drives the structural
	-- category, persisted as a queryable property. An emitter key maps to the
	-- manifest key with underscores as spaces, so `subject_type` is "Subject type".
	if ctx.typeInfo and ctx.typeInfo.name then
		merged.subject_type = ctx.typeInfo.name
	end
	local success, _err, unregistered = structuredData.store(merged, kind)
	return success, unregistered
end

--- Sets the page's short description via the SHORTDESC parser function.
--- Uses the most specific getShortDescription implementation in the chain
--- (leaf-first walk), composing in the first non-nil facet adjective. Single
--- facet today, so first-non-nil-wins is sufficient. Falls back to the type
--- display name.
---
--- @param frame table
--- @param chain table[]
--- @param facets table[]
--- @param ctx EntityHookContext
local function setShortDescription(frame, chain, facets, ctx)
	if not ctx.typeInfo then
		return
	end

	local prefix = nil
	for _, facet in ipairs(facets) do
		if facet.getShortDescriptionPrefix then
			prefix = assembly.callHook(facet, 'getShortDescriptionPrefix', ctx)
			if prefix then
				break
			end
		end
	end

	-- prefix exists only for this call: set here and cleared after the resolve.
	ctx.prefix = prefix
	local desc = assembly.resolveMostSpecific(chain, 'getShortDescription', nil, ctx)
	ctx.prefix = nil
	if desc == nil then
		desc = ctx.typeInfo.name
	end
	-- #shortdesc rejects an absent value with a Lua error that takes the whole
	-- render down with it, and a page with nothing to describe is better off
	-- with no short description than with the infobox replaced by an error.
	if desc == nil or desc == '' then
		return
	end

	frame:callParserFunction('SHORTDESC', desc)
end

--- Can this invocation identify the entity it is describing? Three ways: a
--- `uuid`, a name (curated or from the API record), or a **kind that claimed the
--- page**. The last is the kind-declared case: the `{{Location}}` facade injects
--- `|kind=Location` and a lore system deliberately carries no uuid and often no
--- `|name=`, deriving its identity from the page title — `Infobox.render` titles
--- from `mw.title.getCurrentTitle().text` and `Location.resolveLookupName` looks
--- the starmap record up by the same title, so such a page renders correctly.
---
--- The test is `result.matchedKind` (set by Data's editorial fork when `|kind=`
--- names an opted-in kind), not the raw `args.kind`: a misspelled kind resolves
--- to nothing and must still hit the error rather than silently render a
--- title-only shell.
---
--- @param args table Parsed wikitext args
--- @param result table The Module:Entity/Data.get result
--- @return boolean
local function isIdentifiable(args, result)
	return args.uuid ~= nil or args.name ~= nil or result.apiData.name ~= nil or result.matchedKind ~= nil
end

--- Main entry point for the Entity module. Renders the infobox and owns
--- page-metadata responsibilities (structured-data storage, SHORTDESC,
--- tracking categories). Sibling renderers on the same page should consume
--- Module:Entity/Data directly and leave page metadata to this template.
---
--- @param frame table The MediaWiki frame object
--- @return string HTML output with optional tracking categories
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if not isIdentifiable(args, result) then
		return '<span class="error">Entity module error: no uuid, name, or kind provided</span>'
			.. CATEGORY_ENTITY_ERROR
	end

	local html = entityInfobox.render(result, args)
	-- The Bucket route is the kind that actually matched, never result.kind's
	-- 'Item' fallback: a page whose kind never resolved writes its entity-routable
	-- keys only, rather than another kind's columns.
	local storeSuccess, unregistered = storeStructuredData(
		result.chain,
		result.facets,
		result.ctx,
		result.editorialData,
		result.matchedKind and result.matchedKind.name or nil
	)

	setShortDescription(frame, result.chain, result.facets, result.ctx)

	return html
		.. categories.build(
			result.typeInfo,
			result.chainCategories,
			result.apiData,
			args,
			result.hasApiError,
			not storeSuccess,
			result.hasManualApiData,
			result.unresolvedReference,
			unregistered and #unregistered > 0 or false
		)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	isIdentifiable = isIdentifiable,
	setShortDescription = setShortDescription,
}

return p
