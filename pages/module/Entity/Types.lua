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

--- @class EntityChainLink
--- A p.parent-linked contributor (Base → Item → subtype). Every hook optional;
--- a link implements only what it contributes.
--- @field parent string|nil Module path of the parent link (e.g. 'Entity/Item')
--- @field getApiConfigs nil|fun(): EntityApiConfig[] Extra API endpoints this link needs
--- @field getSections nil|fun(apiData: table, args: table, resolved: table|nil): EntitySectionEntry[] Ordered section entries
--- @field getStructuredData nil|fun(apiData: table, args: table, resolved: table|nil): table<string, any> Flat key-value data
--- @field getShortDescription nil|fun(apiData: table, args: table, typeInfo: table, prefix: string|nil, resolved: table|nil): string Page short description
--- @field getExternalSiteItems nil|fun(apiData: table, args: table): EntityItemData[] External-site links
--- @field getTypeInfo nil|fun(apiData: table, args: table): table|nil Display metadata { name, category }
--- @field getSubtitle nil|fun(apiData: table, args: table): string|nil Header subtitle override (else the display type)
--- @field getHeaderBadge nil|fun(apiData: table, args: table, resolved: table|nil): string|nil Header badge HTML composed into the image overlay

--- @class EntityKind : EntityChainLink
--- A top-level entity with its own API endpoint and a mutually-exclusive
--- identity (Item / Vehicle / Commodity). Registered in Module:Entity/Registry.
--- @field name string REQUIRED. Canonical kind name, exposed as Data.get().result.kind (enforced by the Registry conformance test)
--- @field matches fun(apiData: table|nil): boolean REQUIRED. Strict, nil-safe identity predicate
--- @field getApiConfigs fun(): EntityApiConfig[] REQUIRED. [1] is the identity probe endpoint
--- @field resolveSubtype nil|fun(apiData: table|nil): table|nil Refine to a subtype leaf module, or nil
--- @field enrich nil|fun(apiData: table): table Post-fetch mutation hook (returns apiData)
--- @field getEditorialManifest nil|fun(): table A per-kind editorial-field manifest (field -> { arg, smw, apiPath?, transform?, default? }); presence opts the kind into the editorial layer

--- @class EntityFacet
--- A cross-cutting additive aspect matched on a data field, independent of kind.
--- Registered in Module:Entity/Registry.
--- @field matches fun(apiData: table|nil): boolean REQUIRED. Strict, nil-safe data-presence predicate
--- @field getSections fun(apiData: table, args: table, resolved: table|nil): EntitySectionEntry[] REQUIRED. Ordered section entries
--- @field getStructuredData nil|fun(apiData: table, args: table, resolved: table|nil): table<string, any> Flat key-value data
--- @field getShortDescriptionPrefix nil|fun(apiData: table, args: table): string|nil Adjective composed into the kind's short description

return p
