require('strict')

--- @module Entity/Registry
--- The single declarative home for the Entity components that exist. Adding a
--- kind or facet is a one-line edit here (plus the module file and a passing
--- conformance test — see Module:Entity/Contract and Module:Entity/doc).
---
--- Subtypes are intentionally NOT here: subtype dispatch is a kind-internal
--- concern owned by each kind's resolveSubtype. Both Item (via its
--- itemSubtypeMapping) and Vehicle (Ship/GroundVehicle/Gravlev) dispatch this
--- way, which is why their leaves aren't registered alongside the kinds below.

local p = {}

--- Ordered by probe precedence, which now only governs the per-endpoint fallback
--- in Module:Entity/Data: Item first, because it dominates the page mix and so
--- short-circuits on the first fetch. The normal path resolves a UUID in one
--- request and offers that single payload to every kind, so identification does
--- NOT depend on this order — each matches() must stand on its own.
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
	require('Module:Entity/Facet/Seat'),
	require('Module:Entity/Facet/Knife'),
	require('Module:Entity/Facet/Grenade'),
	require('Module:Entity/Facet/Gadget'),
	require('Module:Entity/Facet/Salvage'),
	require('Module:Entity/Facet/Heal'),
	require('Module:Entity/Facet/Medical'),
	require('Module:Entity/Facet/Hacking'),
	require('Module:Entity/Facet/WeaponModifier'),
	require('Module:Entity/Facet/IronSight'),
	require('Module:Entity/Facet/Magazine'),
	require('Module:Entity/Facet/LaserPointer'),
	require('Module:Entity/Facet/Flashlight'),
	require('Module:Entity/Facet/Mining'),
	require('Module:Entity/Facet/Beam'),
	require('Module:Entity/Facet/Armor'),
	require('Module:Entity/Facet/Environment'),
	require('Module:Entity/Facet/DamageFalloff'),
	require('Module:Entity/Facet/Inventory'),
	require('Module:Entity/Facet/Component'),
	require('Module:Entity/Facet/Dimensions'),
}

return p
