require('strict')

--- @module Entity/Infobox
--- Builds the entity infobox: assembles the chain + facet sections plus the
--- metadata / external-sites / footer sections, then renders via InfoboxLua.
--- Owns the whole "produce the infobox HTML" responsibility so Module:Entity's
--- p.main stays orchestration-only.

local button = require('Module:ButtonLua')
local assembly = require('Module:Entity/Assembly')
local infobox = require('Module:InfoboxLua')
local rarity = require('Module:Rarity')

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

--- Builds the Metadata section. Returns nil when every row is empty (e.g. a
--- planned/editorial-mode page with no uuid and no API record) so the infobox
--- doesn't render an empty collapsible shell.
---
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildMetadataSection(apiData, args)
	local items = {
		{ label = 'UUID', content = args.uuid },
		{ label = 'Class name', content = apiData.class_name },
		{ label = 'Classification', content = apiData.classification },
		{
			label = 'Tags',
			content = apiData.tags and #apiData.tags > 0 and table.concat(apiData.tags, ', ') or nil,
		},
		{ label = 'Entity tags', content = formatEntityTags(apiData) },
		{ label = 'Version', content = apiData.version },
	}
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

--- Builds the External sites section by aggregating getExternalSiteItems from
--- every module in the chain. Returns nil when no items are available.
---
--- @param chain table[]
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildExternalSitesSection(chain, apiData, args)
	local items = {}
	local byLabel = {}
	for _, mod in ipairs(chain) do
		if mod.getExternalSiteItems then
			for _, item in ipairs(mod.getExternalSiteItems(apiData, args)) do
				local existing = byLabel[item.label]
				if existing and type(existing.content) == 'string' and type(item.content) == 'string' then
					existing.content = existing.content .. ' \194\183 ' .. item.content
				elseif existing == nil then
					byLabel[item.label] = item
					table.insert(items, item)
				end
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
--- button (when the page supplies a galactapediaurl) comes first, then any
--- chain-contributed buttons (the getFooterButtons hook, e.g. the star-system
--- Starmap button), then the Wiki API button, which links to the entity on the
--- Star Citizen Wiki API (api.star-citizen.wiki) — its /search/<uuid> path
--- resolves any entity by UUID regardless of type. They sit side by side and
--- wrap to stacked rows on narrow infoboxes (see Module:Entity/styles.css).
--- Each button is independent, and the whole section collapses out when none
--- is present.
---
--- @param chain table[]
--- @param apiData table
--- @param args table
--- @return table|nil section
local function buildFooterSection(chain, apiData, args)
	local buttons = {}

	-- Canonical arg is `galactapediaurl` (the consistent <name>url form, also used by
	-- Vehicle's external-sites row); `galactapedia_url` is kept as a back-compat alias.
	local galactapediaUrl = args.galactapediaurl or args.galactapedia_url
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

	-- Chain-contributed buttons, root-to-leaf: each link may return a list of
	-- ButtonLua-shaped defs ({ label, url, icon, class }); weight defaults to
	-- the footer's normal.
	for _, mod in ipairs(chain) do
		if mod.getFooterButtons then
			for _, def in ipairs(mod.getFooterButtons(apiData, args) or {}) do
				def.weight = def.weight or 'normal'
				table.insert(buttons, button.render(def))
			end
		end
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
--- @param resolved table|nil Editorial resolved fields (optional; {} when no manifest)
--- @return table[] sections
local function buildSections(chain, facets, apiData, args, resolved)
	local sectionsList = {}
	for _, mod in ipairs(chain) do
		if mod.getSections then
			table.insert(sectionsList, mod.getSections(apiData, args, resolved))
		end
	end
	-- Facet sections come after the chain so a new-key facet section (e.g.
	-- consumable) lands after the kind's own sections; a facet reusing a chain
	-- key merges into it via mergeSections' append-items behaviour.
	for _, facet in ipairs(facets) do
		if facet.getSections then
			table.insert(sectionsList, facet.getSections(apiData, args, resolved))
		end
	end
	local sections = assembly.mergeSections(sectionsList)

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

	local metadata = buildMetadataSection(apiData, args)
	if metadata then
		table.insert(sections, metadata)
	end

	local externalSites = buildExternalSitesSection(chain, apiData, args)
	if externalSites then
		table.insert(sections, externalSites)
	end

	local footer = buildFooterSection(chain, apiData, args)
	if footer then
		table.insert(sections, footer)
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
	local sections = buildSections(result.chain, result.facets, result.apiData, args, result.resolved)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/styles.css' },
	})

	-- Subtitle defaults to the display type; a chain link may override it
	-- (vehicles show their manufacturer in the header). Leaf-first wins.
	local subtitle = assembly.resolveMostSpecific(
		result.chain,
		'getSubtitle',
		assembly.acceptNonEmpty,
		result.apiData,
		args
	) or result.displayType

	-- Header badge: a chain link (vehicles) may contribute a badge for the image
	-- overlay (e.g. production status). Leaf-first wins.
	local headerBadge = assembly.resolveMostSpecific(
		result.chain,
		'getHeaderBadge',
		assembly.acceptNonEmpty,
		result.apiData,
		args,
		result.resolved
	)

	local html = infobox.render({
		-- The curated |name= wins over the API record name (which may carry an
		-- internal suffix, e.g. "85X Limited" for the page titled "85X"), matching
		-- the args-first name convention used for SMW/external-sites everywhere else.
		title = args.name or result.apiData.name or mw.title.getCurrentTitle().text,
		subtitle = subtitle,
		image = buildImage(result.apiData, args, headerBadge),
		sections = sections,
	})

	return styles .. html
end

return p
