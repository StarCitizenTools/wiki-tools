require('strict')

local p = {}

--- @class EntityApiConfig
--- @field name string The API provider name (e.g. 'StarCitizenWikiAPI')
--- @field endpoint string The endpoint pattern with %s for UUID substitution
--- @field params table<string, string> Query parameters for the API call
--- @field responseDataPath string|nil Optional key to unwrap from the response

--- @class EntityItemData
--- @field label string|nil The label text for the item
--- @field content string|nil The display content
--- @field class string|nil CSS class on the item element (e.g. a full-width block row)

--- @class EntitySectionEntry
--- @field key string Unique section identifier used for merging across the type chain
--- @field label string|nil The display name for the section
--- @field collapsible boolean|nil Whether the section is collapsible
--- @field collapsed boolean|nil Whether the section starts collapsed
--- @field columns number|nil Number of columns for the items grid
--- @field class string|nil Additional CSS class
--- @field content string|nil Raw HTML content (alternative to items)
--- @field sections table<EntitySectionEntry>|nil Nested sub-sections
--- @field items EntityItemData[]|nil List of label/content items

--- @class EntityHookContext
--- The single argument every contributor and facet hook receives. Identity
--- hooks (matches, resolveSubtype, getApiConfigs, getEditorialManifest) run
--- before a page context exists and keep their own signatures. Built once
--- per Module:Entity/Data.get and shared by the infobox and every sibling
--- renderer (result.ctx). Fields are filled in pipeline order, so a hook that
--- runs early sees the later ones as nil.
--- @field apiData table The merged API record ({} on the editorial fork); always a table
--- @field args table Parsed template args; always a table
--- @field resolved table|nil Editorial resolved fields: nil for enrich / getTypeInfo, {} when the chain declares no manifest
--- @field typeInfo table|nil Display type info { name, category, categories }: nil for enrich / getTypeInfo / getCategories
--- @field prefix string|nil Facet adjective composed into the short description; set only for the getShortDescription call
--- @field kind string|nil Canonical kind name (Data.get().kind); nil until type resolution
--- @field family string|nil Leaf family token; nil until type resolution

--- @class EntityChainLink
--- A contributor: any link in the p.parent chain (Base → kind → subtype leaf).
--- Every hook is optional; a link implements only what it contributes.
--- Merge policy per hook is applied by Module:Entity/Data (see Contract.CONTRIBUTOR).
--- @field parent string|nil Module path of the parent link (e.g. 'Entity/Item')
--- @field family string|nil Family token a subtype leaf declares; the kind's resolveSubtype maps the same token to this leaf, and a curated |family= arg names it on record-less pages
--- @field contextHooks boolean|nil Transitional: true once this link's hooks take an EntityHookContext; Module:Entity/Assembly.callHook calls unflagged links positionally. Removed when every link is migrated.
--- @field getApiConfigs nil|fun(): EntityApiConfig[] Extra API endpoints this link needs
--- @field enrich nil|fun(ctx: EntityHookContext): table Post-fetch mutation, run root-to-leaf after the chain's endpoints are fetched (a leaf attaches the secondary record only it renders: StarSystem the starmap system, JumpPoint the celestial object)
--- @field getEditorialManifest nil|fun(): table Editorial-field manifest fragment (field -> { arg, smw?, apiPath?, transform?, default? }); fragments merge root-to-leaf, leaf keys win
--- @field getSections nil|fun(ctx: EntityHookContext): EntitySectionEntry[] Ordered section entries
--- @field getStructuredData nil|fun(ctx: EntityHookContext): table<string, any> Flat key-value data
--- @field getShortDescription nil|fun(ctx: EntityHookContext): string Page short description
--- @field getExternalSiteItems nil|fun(ctx: EntityHookContext): EntityItemData[] External-site links
--- @field getFooterButtons nil|fun(ctx: EntityHookContext): table[] Footer action-button defs ({ label, url, icon, class }), rendered between the Galactapedia and Wiki API buttons
--- @field getMetadataItems nil|fun(ctx: EntityHookContext): EntityItemData[] Extra rows appended to the Infobox's Metadata section (StarSystem: the ARK starmap code)
--- @field getTypeInfo nil|fun(ctx: EntityHookContext): table|nil Display metadata { name, category }
--- @field getSubtitle nil|fun(ctx: EntityHookContext): string|nil Header subtitle override (else the display type)
--- @field getHeaderBadge nil|fun(ctx: EntityHookContext): string|nil Header badge HTML composed into the image overlay
--- @field getCategories nil|fun(ctx: EntityHookContext): string[] Extra browse categories, collected from every link and appended after the structural + manufacturer categories
--- @field getAcquisition nil|fun(ctx: EntityHookContext): { summary: table[], cards: table[] }|nil Acquisition data for {{Entity/Availability}}; leaf-first wins. Absent on every link → no acquisition block.
--- @field getRelated nil|fun(ctx: EntityHookContext): EntityRelatedPayload|nil Payload for {{Entity/Related}}; leaf-first wins. Base supplies { items = apiData.related_items }
--- @field getBlueprints nil|fun(ctx: EntityHookContext): EntityBlueprintsPayload|nil Payload for {{Entity/Blueprints}}; leaf-first wins. Base supplies { blueprints = apiData.blueprint }
--- @field getPorts nil|fun(ctx: EntityHookContext): EntityPortsPayload|nil Payload for {{Entity/Ports}}; leaf-first wins. Base supplies { ports = apiData.ports }

--- Sibling-renderer payloads. Each renderer draws exactly one payload shape
--- and never reads apiData itself; a link that means something else by
--- "related" / "blueprints" / "ports" returns the alternative field.

--- @class EntityRelatedPayload
--- @field items table|nil The API `related_items` block (set_items / base_item / variant_items), rendered as tile grids
--- @field cargo { scu: number, mass_kg: number }[]|nil Cargo-box packaging variants ascending by SCU, rendered as a table instead of tiles (Commodity)

--- @class EntityBlueprintsPayload
--- @field blueprints table[]|nil The API `blueprint` list (craftable + dismantle entries)
--- @field ingredient { name: string|nil }|nil Present when the entity is a crafting INPUT, never an output: renders the "used in crafting" count card instead of the blueprint list (Commodity)

--- @class EntityPortsPayload
--- @field ports table[]|nil The API `ports` tree
--- @field narrowChildren boolean|nil Apply each category's expandIntoTypes allowlist to child ports (Vehicle: drops cockpit panels and displays from the L-tree)

--- @class EntityKind : EntityChainLink
--- A top-level entity with its own API endpoint and a mutually-exclusive
--- identity (Item / Vehicle / Commodity / Mission / Location). Registered in
--- Module:Entity/Registry. Identity hooks only; everything it renders it
--- contributes as a chain link like any other.
--- @field name string REQUIRED. Canonical kind name, exposed as Data.get().result.kind (enforced by the Registry conformance test)
--- @field matches fun(apiData: table|nil): boolean REQUIRED. Strict, nil-safe identity predicate: true exactly for the records this kind can render (its own leaf resolves, or the kind itself is the leaf)
--- @field getApiConfigs fun(): EntityApiConfig[] REQUIRED. [1] is the identity endpoint
--- @field resolveSubtype nil|fun(apiData: table|nil, args: table|nil): table|nil Refine to a subtype leaf module, or nil. Family token from the record, else the curated |family= arg (Module:Entity/SubtypeResolver.familyArg), else the kind's default leaf on kind-declared record-less pages
--- @field defaultFamily string|nil Family token of the leaf a kind-declared page with no record resolves to (Location: 'starsystem'); nil means the kind stays the leaf
--- @field editorialMode boolean|nil Opt-in: when true the kind renders from editorial args alone (apiData = {}) for planned / not-yet-in-game pages with no genuine API record. See Module:Entity/Data.

--- @class EntityFacet
--- A cross-cutting additive aspect matched on a data field, independent of kind.
--- Registered in Module:Entity/Registry.
--- @field matches fun(apiData: table|nil): boolean REQUIRED. Strict, nil-safe data-presence predicate
--- @field contextHooks boolean|nil Transitional: true once this facet's hooks take an EntityHookContext; Module:Entity/Assembly.callHook calls unflagged facets positionally. Removed when every link is migrated.
--- @field getSections fun(ctx: EntityHookContext): EntitySectionEntry[] REQUIRED. Ordered section entries
--- @field getStructuredData nil|fun(ctx: EntityHookContext): table<string, any> Flat key-value data
--- @field getShortDescriptionPrefix nil|fun(ctx: EntityHookContext): string|nil Adjective composed into the kind's short description

return p
