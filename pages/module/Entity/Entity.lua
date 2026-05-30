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
--- @param apiData table
--- @param args table
--- @return boolean success True if the backend accepted the data
local function storeStructuredData(chain, facets, apiData, args)
	local dataList = {}
	for _, mod in ipairs(chain) do
		if mod.getStructuredData then
			table.insert(dataList, mod.getStructuredData(apiData, args))
		end
	end
	for _, facet in ipairs(facets) do
		if facet.getStructuredData then
			table.insert(dataList, facet.getStructuredData(apiData, args))
		end
	end
	return structuredData.store(assembly.mergeStructuredData(dataList))
end

--- Sets the page's short description via the SHORTDESC parser function.
--- Uses the most specific getShortDescription implementation in the chain
--- (leaf-first walk), composing in the first non-nil facet adjective. Single
--- facet today, so first-non-nil-wins is sufficient. Falls back to the type
--- display name.
---
--- @param frame table
--- @param typeInfo table|nil
--- @param chain table[]
--- @param facets table[]
--- @param apiData table
--- @param args table
local function setShortDescription(frame, typeInfo, chain, facets, apiData, args)
	if not typeInfo then
		return
	end

	local prefix = nil
	for _, facet in ipairs(facets) do
		if facet.getShortDescriptionPrefix then
			prefix = facet.getShortDescriptionPrefix(apiData, args)
			if prefix then
				break
			end
		end
	end

	local desc = typeInfo.name
	for i = #chain, 1, -1 do
		if chain[i].getShortDescription then
			desc = chain[i].getShortDescription(apiData, args, typeInfo, prefix)
			break
		end
	end

	frame:callParserFunction('SHORTDESC', desc)
end

--- Main entry point for the Entity module. Renders the infobox and owns
--- page-metadata responsibilities (SMW storage, SHORTDESC, tracking
--- categories). Sibling renderers on the same page should consume
--- Module:Entity/Data directly and leave page metadata to this template.
---
--- @param frame table The MediaWiki frame object
--- @return string HTML output with optional tracking categories
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if not args.uuid and not (args.name or result.apiData.name) then
		return '<span class="error">Entity module error: no uuid or name provided</span>' .. CATEGORY_ENTITY_ERROR
	end

	local html = entityInfobox.render(result, args)
	local storeSuccess = storeStructuredData(result.chain, result.facets, result.apiData, args)

	setShortDescription(frame, result.typeInfo, result.chain, result.facets, result.apiData, args)

	return html .. categories.build(result.typeInfo, result.apiData, args, result.hasApiError, not storeSuccess)
end

return p
