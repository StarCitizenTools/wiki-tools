require('strict')

--- @module Entity/Infobox
--- Builds the entity infobox: assembles the chain + facet sections plus the
--- metadata / external-sites / footer sections, then renders via InfoboxLua.
--- Owns the whole "produce the infobox HTML" responsibility so Module:Entity's
--- p.main stays orchestration-only.

local button = require('Module:ButtonLua')
local assembly = require('Module:Entity/Assembly')
local infobox = require('Module:InfoboxLua')

local WIKI_API_SEARCH_URL = 'https://api.star-citizen.wiki/search/'

local p = {}

--- Renders apiData.entity_tag_map as a comma-separated list of <data>
--- elements, so the visible text is the display name while the value
--- attribute carries the tag UUID for scrapers / future JS hooks.
--- Returns nil when no tags are present so the row collapses out of the
--- infobox entirely.
---
--- @param apiData table
--- @return string|nil
local function formatEntityTags(apiData)
	local tags = apiData.entity_tag_map
	if type(tags) ~= 'table' or #tags == 0 then
		return nil
	end
	local parts = {}
	for _, tag in ipairs(tags) do
		table.insert(parts, tostring(mw.html.create('data'):attr('value', tag.uuid):wikitext(tag.name)))
	end
	return table.concat(parts, ', ')
end

--- Builds the Metadata section.
---
--- @param apiData table
--- @param args table
--- @return table section
local function buildMetadataSection(apiData, args)
	return {
		label = 'Metadata',
		collapsible = true,
		collapsed = true,
		items = {
			{ label = 'UUID', content = args.uuid },
			{ label = 'Class name', content = apiData.class_name },
			{ label = 'Classification', content = apiData.classification },
			{
				label = 'Tags',
				content = apiData.tags and #apiData.tags > 0 and table.concat(apiData.tags, ', ') or nil,
			},
			{ label = 'Entity tags', content = formatEntityTags(apiData) },
			{ label = 'Version', content = apiData.version },
		},
	}
end

--- Builds the External sites section by aggregating getExternalSiteItems from
--- every module in the chain. Returns nil when no items are available.
---
--- @param chain table[]
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildExternalSitesSection(chain, apiData, args)
	local items = {}
	for _, mod in ipairs(chain) do
		if mod.getExternalSiteItems then
			for _, item in ipairs(mod.getExternalSiteItems(apiData, args)) do
				table.insert(items, item)
			end
		end
	end
	if #items == 0 then
		return nil
	end
	return {
		label = 'External sites',
		collapsible = true,
		collapsed = true,
		items = items,
	}
end

--- Builds the footer section: a flex row of action buttons. The Galactapedia
--- button (when the page supplies a galactapedia_url) comes first; the Wiki API
--- button links to the entity on the Star Citizen Wiki API
--- (api.star-citizen.wiki) — its /search/<uuid> path resolves any entity by
--- UUID regardless of type. They sit side by side and wrap to stacked rows on
--- narrow infoboxes (see Module:Entity/styles.css). Each button is independent:
--- a page with only one of (galactapedia_url, uuid) shows just that button, and
--- the whole section collapses out when neither is present.
---
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildFooterSection(apiData, args)
	local buttons = {}

	local galactapediaUrl = args.galactapedia_url
	if galactapediaUrl and galactapediaUrl ~= '' then
		table.insert(
			buttons,
			button.render({
				label = 'Galactapedia',
				url = galactapediaUrl,
				icon = 'Sc-icon-galactapedia.svg',
				weight = 'normal',
				class = 't-button--galactapedia',
			})
		)
	end

	local uuid = args.uuid or apiData.uuid
	if uuid and uuid ~= '' then
		table.insert(
			buttons,
			button.render({
				label = 'Wiki API',
				url = WIKI_API_SEARCH_URL .. uuid,
				icon = 'Star Citizen Wiki API - Logo.svg',
				weight = 'normal',
				class = 't-button--wiki-api',
			})
		)
	end

	if #buttons == 0 then
		return nil
	end

	-- Wrap the buttons in a flex row (Module:Entity/styles.css) so they sit
	-- side by side, each growing to fill its share, and wrap to stacked rows
	-- when the infobox is too narrow to hold them.
	local actions = mw.html.create('div'):addClass('t-infobox-footer-actions'):wikitext(table.concat(buttons))

	return {
		content = tostring(actions),
		class = 't-infobox-section--footer',
	}
end

--- Assembles all infobox sections: chain contributions, facet contributions,
--- metadata, external sites, footer.
---
--- @param chain table[]
--- @param facets table[]
--- @param apiData table
--- @param args table
--- @return table[] sections
local function buildSections(chain, facets, apiData, args)
	local sectionsList = {}
	for _, mod in ipairs(chain) do
		if mod.getSections then
			table.insert(sectionsList, mod.getSections(apiData, args))
		end
	end
	-- Facet sections come after the chain so a new-key facet section (e.g.
	-- consumable) lands after the kind's own sections; a facet reusing a chain
	-- key merges into it via mergeSections' append-items behaviour.
	for _, facet in ipairs(facets) do
		if facet.getSections then
			table.insert(sectionsList, facet.getSections(apiData, args))
		end
	end
	local sections = assembly.mergeSections(sectionsList)

	table.insert(sections, buildMetadataSection(apiData, args))

	local externalSites = buildExternalSitesSection(chain, apiData, args)
	if externalSites then
		table.insert(sections, externalSites)
	end

	local footer = buildFooterSection(apiData, args)
	if footer then
		table.insert(sections, footer)
	end

	return sections
end

--- Renders the full entity infobox (TemplateStyles + InfoboxLua HTML) from a
--- Module:Entity/Data result.
---
--- @param result table The result table from Module:Entity/Data.get
--- @param args table Parsed wikitext args
--- @return string
function p.render(result, args)
	local sections = buildSections(result.chain, result.facets, result.apiData, args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/styles.css' },
	})

	local html = infobox.render({
		title = result.apiData.name or args.name or mw.title.getCurrentTitle().text,
		subtitle = result.displayType,
		image = args.image,
		sections = sections,
	})

	return styles .. html
end

return p
