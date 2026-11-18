require('strict')

--- @module Entity/Infobox
--- Builds the entity infobox: assembles the chain + facet sections plus the
--- metadata and external-sites sections, then renders via InfoboxLua.
--- Owns the whole "produce the infobox HTML" responsibility so Module:Entity's
--- p.main stays orchestration-only.

local assembly = require('Module:Entity/Assembly')
local externalSites = require('Module:Entity/ExternalSites')
local format = require('Module:Entity/Format')
local infobox = require('Module:InfoboxLua')
local rarity = require('Module:Rarity')

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

--- Builds the Metadata section, including chain-contributed rows. Returns nil
--- when every row is empty (e.g. a planned/editorial-mode page with no uuid
--- and no API record) so the infobox doesn't render an empty collapsible shell.
---
--- @param chain table[]
--- @param ctx EntityHookContext
--- @return table|nil section
local function buildMetadataSection(chain, ctx)
	local apiData, args = ctx.apiData, ctx.args
	local items = {
		{ label = 'UUID', content = args.uuid },
		{ label = 'Class name', content = apiData.class_name },
		{ label = 'Classification', content = apiData.classification },
		{
			label = 'Tags',
			content = apiData.tags and #apiData.tags > 0 and table.concat(apiData.tags, ', ') or nil,
		},
		{ label = 'Entity tags', content = formatEntityTags(apiData) },
		{ label = 'Version', content = format.gameVersion(apiData) },
	}

	-- Chain-contributed metadata rows (the getMetadataItems hook), root-to-leaf,
	-- appended after the generic rows (StarSystem: the ARK starmap code).
	for _, item in ipairs(assembly.run(chain, 'getMetadataItems', ctx)) do
		table.insert(items, item)
	end

	for _, item in ipairs(items) do
		if item.content ~= nil and item.content ~= '' then
			return {
				label = 'Metadata',
				collapsible = true,
				collapsed = true,
				items = items,
			}
		end
	end
	return nil
end

--- Builds the External sites section and the site buttons that follow it
--- from every chain link's getExternalSites entries (Module:Entity/ExternalSites).
---
--- @param chain table[]
--- @param ctx EntityHookContext
--- @return table|nil section
--- @return table|nil buttons
local function buildExternalSites(chain, ctx)
	return externalSites.build(assembly.run(chain, 'getExternalSites', ctx))
end

--- Assembles all infobox sections: chain contributions, facet contributions,
--- metadata, external sites, then the external-site buttons.
---
--- @param chain table[]
--- @param facets table[]
--- @param ctx EntityHookContext
--- @return table[] sections
local function buildSections(chain, facets, ctx)
	-- Facet sections come after the chain so a new-key facet section (e.g.
	-- consumable) lands after the kind's own sections; a facet reusing a chain
	-- key merges into it via mergeSections' append-items behaviour.
	local sections = assembly.mergeSections({
		assembly.run(chain, 'getSections', ctx),
		assembly.run(facets, 'getSections', ctx),
	})

	-- Stat sections (the chain's and facets' labelled sections — the subtype
	-- stat block, Dimensions, etc.) render collapsible but expanded by default,
	-- so a reader can fold away detail without losing the headline values. A
	-- section that sets its own collapsible state keeps it (Component collapses
	-- by default; Consumable / vehicle-weapon sections opt to stay open), and
	-- the label-less general section stays plain (always shown). Runs before the
	-- Metadata / External-sites sections are appended, so their explicit
	-- collapsed state is untouched.
	for _, section in ipairs(sections) do
		if section.label and section.collapsible == nil then
			section.collapsible = true
		end
	end

	local metadata = buildMetadataSection(chain, ctx)
	if metadata then
		table.insert(sections, metadata)
	end

	local sites, buttons = buildExternalSites(chain, ctx)
	if sites then
		table.insert(sections, sites)
	end
	if buttons then
		table.insert(sections, buttons)
	end

	return sections
end

--- Builds the InfoboxLua `image` value: the page image plus an overlay strip of
--- chips (a header badge from the chain, e.g. a vehicle's production status, and
--- the rarity badge). Returns the bare image string when there are no chips.
---
--- @param apiData table
--- @param args table
--- @param headerBadge string|nil
--- @return string|table|nil
local function buildImage(apiData, args, headerBadge)
	local chips = {}
	if headerBadge and headerBadge ~= '' then
		table.insert(chips, headerBadge)
	end
	local rarityBadge = rarity.badge(apiData.rarity)
	if rarityBadge then
		table.insert(chips, rarityBadge)
	end
	if #chips == 0 then
		return args.image
	end
	local overlay = mw.html.create('div'):addClass('t-infobox-badge-overlay'):wikitext(table.concat(chips))
	return { src = args.image, overlay = tostring(overlay) }
end

--- Renders the full entity infobox (TemplateStyles + InfoboxLua HTML) from a
--- Module:Entity/Data result.
---
--- @param result table The result table from Module:Entity/Data.get
--- @param args table Parsed wikitext args
--- @return string
function p.render(result, args)
	local ctx = result.ctx
	local sections = buildSections(result.chain, result.facets, ctx)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/styles.css' },
	})

	-- Subtitle defaults to the display type; a chain link may override it
	-- (vehicles show their manufacturer in the header).
	local subtitle = assembly.run(result.chain, 'getSubtitle', ctx) or result.displayType

	-- A second name for the same subject, shown after the title instead of
	-- taking a row (bodies show their designation).
	local titleAnnotation = assembly.run(result.chain, 'getTitleAnnotation', ctx)

	-- Header badge: a chain link (vehicles) may contribute a badge for the image
	-- overlay (e.g. production status).
	local headerBadge = assembly.run(result.chain, 'getHeaderBadge', ctx)

	local html = infobox.render({
		-- The curated |name= wins over the API record name (which may carry an
		-- internal suffix, e.g. "85X Limited" for the page titled "85X"), matching
		-- the args-first name convention used for structured data and external sites
		-- everywhere else.
		title = args.name or result.apiData.name or mw.title.getCurrentTitle().text,
		annotation = titleAnnotation,
		subtitle = subtitle,
		image = buildImage(result.apiData, args, headerBadge),
		sections = sections,
	})

	return styles .. html
end

-- Test-only exports. Not part of the public API.
p._internal = {
	buildExternalSites = buildExternalSites,
	buildMetadataSection = buildMetadataSection,
	formatEntityTags = formatEntityTags,
}

return p
