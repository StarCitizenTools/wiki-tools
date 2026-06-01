require('strict')

--- @module Entity/Categories
--- Derives an entity's content categories and builds the trailing category
--- wikitext. Pure derivation (deriveCategories) is unit-tested; build() adds
--- namespace gating and the error-tracking categories.

local base = require('Module:Entity/Base')

local CATEGORY_API_ERROR = '[[Category:Pages with API errors]]'
local CATEGORY_STRUCTURED_DATA_ERROR = '[[Category:Pages with structured data errors]]'

local p = {}

--- Derives the content category names for an entity — pure (no namespace logic,
--- no [[Category:]] markup) so the rules are unit-testable in isolation. Emits,
--- when available:
---  * the structural category, from the resolved `typeInfo.category` — for items
---    this is the most-specific classification bucket (e.g. PDCs, Rocket pods,
---    Coolers), resolved in Module:Entity/Data; for other kinds it's the type-map
---    category. Damage type / firing class / size / grade / class are facets
---    (structured data), NOT categories.
---  * optional extra categories from `typeInfo.categories` (e.g. a commodity also
---    lands in Category:Commodities), appended after the structural category.
---  * the manufacturer category (cross-cutting; a brand's catalogue is a useful
---    standalone browse). Generic across kinds.
---
--- @param typeInfo table|nil
--- @param apiData table
--- @param args table
--- @return string[] Ordered list of category names
function p.deriveCategories(typeInfo, apiData, args)
	local names = {}

	if typeInfo then
		table.insert(names, typeInfo.category or typeInfo.name)
		-- Optional extra categories a kind wants to join beyond its primary
		-- structural bucket (e.g. a commodity also lands in Category:Commodities
		-- so the index Data table can query every commodity in one category).
		for _, extra in ipairs(typeInfo.categories or {}) do
			table.insert(names, extra)
		end
	end

	local manufacturer = base.resolveManufacturer(apiData, args)
	if manufacturer and manufacturer.page then
		table.insert(names, manufacturer.page)
	end

	return names
end

--- Builds the trailing category wikitext. Content categories (from the pure
--- deriveCategories) apply only on article (mainspace) pages so test and User:
--- pages don't pollute the canonical category tree — verify category behavior by
--- parsing wikitext with a mainspace title. Tracking categories apply in every
--- namespace so errors surface wherever the module runs.
---
--- @param typeInfo table|nil
--- @param apiData table
--- @param args table
--- @param hasApiError boolean
--- @param hasStructuredDataError boolean
--- @return string
function p.build(typeInfo, apiData, args, hasApiError, hasStructuredDataError)
	local categories = ''

	if mw.title.getCurrentTitle():inNamespace(0) then
		for _, name in ipairs(p.deriveCategories(typeInfo, apiData, args)) do
			categories = categories .. '[[Category:' .. name .. ']]'
		end
	end

	if hasApiError then
		categories = categories .. CATEGORY_API_ERROR
	end
	if hasStructuredDataError then
		categories = categories .. CATEGORY_STRUCTURED_DATA_ERROR
	end
	return categories
end

return p
