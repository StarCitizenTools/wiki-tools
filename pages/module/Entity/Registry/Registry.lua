require('strict')

--- @module Entity/Registry
--- The single declarative home for the Entity components that exist. Adding a
--- kind or facet is one entry here (plus the module file and a passing
--- conformance test — see Module:Entity/Contract and Module:Entity/doc).
---
--- Each entry loads its module through a closure, so a page loads only the
--- kinds and facets it uses. Every loaded module is recorded as a dependency of
--- the page, and an edit to it re-parses every page that loaded it. Keep the
--- `require` argument a literal string: Module:Dependencies finds requires by
--- reading source text and records nothing for a computed name.
---
--- Subtypes are intentionally NOT here: subtype dispatch is a kind-internal
--- concern owned by each kind's resolveSubtype. Both Item (via its
--- itemSubtypeMapping) and Vehicle (Ship/GroundVehicle/Gravlev) dispatch this
--- way, which is why their leaves aren't registered alongside the kinds below.

local p = {}

--- Ordered by probe precedence: Module:Entity/Data fetches each kind's primary
--- endpoint in this order until one matches, so Item goes first because it
--- dominates the page mix and short-circuits on the first fetch (kinds with a
--- facade — Vehicle, Location — declare themselves and skip the probe). Order
--- is a cost optimisation only, never a correctness guarantee: the declared-kind
--- gate offers a record of any kind to a single matches(), so each must stand on
--- its own.
---
--- `api` repeats the kind's own getApiConfigs()[1] (a test keeps the two equal)
--- so the probe can fetch before loading: a kind whose endpoint answers nothing
--- is never loaded.
--- @type EntityKindEntry[]
p.kinds = {
	{
		name = 'Item',
		api = {
			name = 'StarCitizenWikiAPI',
			endpoint = 'items/%s',
			params = { locale = 'en_EN', include = 'related_items,blueprints,vehicles,ports' },
			responseDataPath = 'data',
		},
		load = function()
			return require('Module:Entity/Item')
		end,
	},
	{
		name = 'Vehicle',
		api = {
			name = 'StarCitizenWikiAPI',
			endpoint = 'vehicles/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
		load = function()
			return require('Module:Entity/Vehicle')
		end,
	},
	{
		name = 'Commodity',
		api = {
			name = 'StarCitizenWikiAPI',
			endpoint = 'commodities/%s',
			params = { locale = 'en_EN', include = 'items' },
			responseDataPath = 'data',
		},
		load = function()
			return require('Module:Entity/Commodity')
		end,
	},
	{
		name = 'Mission',
		api = {
			name = 'StarCitizenWikiAPI',
			endpoint = 'missions/%s',
			responseDataPath = 'data',
		},
		load = function()
			return require('Module:Entity/Mission')
		end,
	},
	{
		name = 'Location',
		api = {
			name = 'StarCitizenWikiAPI',
			endpoint = 'locations/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
		load = function()
			return require('Module:Entity/Location')
		end,
	},
}

--- Every facet whose matches() is true contributes additively, regardless of
--- the primary kind. `keys` are the top-level record fields matches() reads:
--- Data loads the facet only when one of them is present, and
--- Module:Entity/Registry/testcases checks that no match survives without them.
--- @type EntityFacetEntry[]
p.facets = {
	{
		keys = { 'food' },
		load = function()
			return require('Module:Entity/Facet/Consumable')
		end,
	},
	{
		keys = { 'seat' },
		load = function()
			return require('Module:Entity/Facet/Seat')
		end,
	},
	{
		keys = { 'knife', 'melee_weapon' },
		load = function()
			return require('Module:Entity/Facet/Knife')
		end,
	},
	{
		keys = { 'grenade' },
		load = function()
			return require('Module:Entity/Facet/Grenade')
		end,
	},
	{
		keys = { 'sub_type' },
		load = function()
			return require('Module:Entity/Facet/Gadget')
		end,
	},
	{
		keys = { 'vehicle_weapon', 'personal_weapon' },
		load = function()
			return require('Module:Entity/Facet/Salvage')
		end,
	},
	{
		keys = { 'personal_weapon', 'vehicle_weapon' },
		load = function()
			return require('Module:Entity/Facet/Heal')
		end,
	},
	{
		keys = { 'medical' },
		load = function()
			return require('Module:Entity/Facet/Medical')
		end,
	},
	{
		keys = { 'hacking_chip' },
		load = function()
			return require('Module:Entity/Facet/Hacking')
		end,
	},
	{
		keys = { 'weapon_modifier' },
		load = function()
			return require('Module:Entity/Facet/WeaponModifier')
		end,
	},
	{
		keys = { 'iron_sight' },
		load = function()
			return require('Module:Entity/Facet/IronSight')
		end,
	},
	{
		keys = { 'magazine' },
		load = function()
			return require('Module:Entity/Facet/Magazine')
		end,
	},
	{
		keys = { 'laser_pointer' },
		load = function()
			return require('Module:Entity/Facet/LaserPointer')
		end,
	},
	{
		keys = { 'flashlight' },
		load = function()
			return require('Module:Entity/Facet/Flashlight')
		end,
	},
	{
		keys = { 'mining_modifier' },
		load = function()
			return require('Module:Entity/Facet/Mining')
		end,
	},
	{
		keys = { 'tractor_beam' },
		load = function()
			return require('Module:Entity/Facet/Beam')
		end,
	},
	{
		keys = { 'suit_armor' },
		load = function()
			return require('Module:Entity/Facet/Armor')
		end,
	},
	{
		keys = { 'temperature_resistance' },
		load = function()
			return require('Module:Entity/Facet/Environment')
		end,
	},
	{
		keys = { 'personal_weapon', 'vehicle_weapon' },
		load = function()
			return require('Module:Entity/Facet/DamageFalloff')
		end,
	},
	{
		keys = { 'inventory' },
		load = function()
			return require('Module:Entity/Facet/Inventory')
		end,
	},
	{
		keys = { 'durability' },
		load = function()
			return require('Module:Entity/Facet/Component')
		end,
	},
	{
		keys = { 'dimension' },
		load = function()
			return require('Module:Entity/Facet/Dimensions')
		end,
	},
}

return p
