require('strict')

--- @module Entity/Registry
--- The single declarative home for the Entity components that exist. Adding a
--- kind or facet is a one-line edit here (plus the module file and a passing
--- conformance test — see Module:Entity/Contract and Module:Entity/doc).
---
--- Item subtypes are intentionally NOT here: subtype dispatch is a kind-internal
--- concern owned by the kind's resolveSubtype (see Module:Entity/Item's
--- itemSubtypeMapping). Only Item has subtypes.

local p = {}

--- Ordered by probe precedence. Item first — it dominates the page mix, so it
--- matches on the first fetch and short-circuits before other endpoints.
--- @type EntityKind[]
p.kinds = {
	require('Module:Entity/Item'),
	require('Module:Entity/Vehicle'),
	require('Module:Entity/Commodity'),
	require('Module:Entity/Mission'),
}

--- Every facet whose matches() is true contributes additively, regardless of
--- the primary kind.
--- @type EntityFacet[]
p.facets = {
	require('Module:Entity/Facet/Consumable'),
	require('Module:Entity/Facet/Component'),
	require('Module:Entity/Facet/Dimensions'),
}

return p
