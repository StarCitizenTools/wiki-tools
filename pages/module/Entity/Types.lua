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

--- @class EntityTypeModule
--- @field parent string|nil Module path of the parent type (e.g. 'Entity/Item')
--- @field getApiConfigs fun(): EntityApiConfig[]|nil Returns additional API configs
--- @field getSections fun(apiData: table, args: table): EntitySectionEntry[] Returns ordered section entries
--- @field getStructuredData fun(apiData: table, args: table): table<string, any> Returns flat key-value data

return p
