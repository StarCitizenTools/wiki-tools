require('strict')

--- @module Entity/ExternalSites
--- The infobox's links to other sites. Chain links contribute EntityExternalSite
--- entries (getExternalSites); this module turns a kind's link definitions into
--- entries and renders the collected entries, one row per link.
---
--- sites.json is the registry: a site's name, tagline, logo, whether RSI runs
--- it, and whether it renders as a button. Its order is the display order
--- inside a group.

local Button = require('Module:ButtonLua')
local Icon = require('Module:Icon')

local p = {}

local SITES_PATH = 'Module:Entity/ExternalSites/sites.json'

local LOGO_SIZE = '24px'

--- @param value any
--- @return boolean
local function isNonEmptyString(value)
	return type(value) == 'string' and value ~= ''
end

--- Resolves a kind's link definitions against its lookup values. A definition
--- is { site, arg } (the lookup value is the URL, or a list of URLs) or
--- { site, format, data } (the lookup value is query-encoded into the format's
--- %s). A definition whose value is absent or empty yields nothing.
---
--- @param defs table[]
--- @param lookup table<string, string|string[]|nil>
--- @return EntityExternalSite[]
function p.fromDefs(defs, lookup)
	local entries = {}

	local function add(def, url)
		if isNonEmptyString(url) then
			entries[#entries + 1] = { site = def.site, url = url }
		end
	end

	for _, def in ipairs(defs) do
		if def.arg then
			local value = lookup[def.arg]
			if type(value) == 'table' then
				for _, url in ipairs(value) do
					add(def, url)
				end
			else
				add(def, value)
			end
		elseif def.format and def.data then
			local value = lookup[def.data]
			if isNonEmptyString(value) then
				add(def, string.format(def.format, mw.uri.encode(value, 'QUERY')))
			end
		end
	end

	return entries
end

--- @param a table
--- @param b table
--- @return boolean
local function bySiteThenPosition(a, b)
	if a.order ~= b.order then
		return a.order < b.order
	end
	return a.position < b.position
end

--- A space ends the URL in external-link syntax, so editor-supplied URLs
--- carry theirs encoded.
--- @param url string
--- @return string
local function linkTarget(url)
	return (url:gsub(' ', '%%20'))
end

--- The logo tile. A site without a logo keeps an empty tile, which the
--- stylesheet leaves transparent, so its name still lines up with the others.
--- @param site table A sites.json entry
--- @return mw.html
local function renderLogo(site)
	local tile = mw.html.create('span'):addClass('t-infobox-sites__logo'):attr('aria-hidden', 'true')
	if isNonEmptyString(site.icon) then
		tile:wikitext(
			Icon.render({ icon = site.icon, size = site.iconSize or LOGO_SIZE, mask = site.iconMask == true })
		)
	end
	return tile
end

--- @param item table { site, url, name }
--- @return mw.html
local function renderItem(item)
	local html = mw.html.create('li'):addClass('t-infobox-sites__item'):node(renderLogo(item.site))
	local text = html:tag('span'):addClass('t-infobox-sites__text')
	text:tag('span')
		:addClass('t-infobox-sites__name')
		:wikitext(string.format('[%s %s]', linkTarget(item.url), item.name))
	if isNonEmptyString(item.site.tagline) then
		text:tag('span'):addClass('t-infobox-sites__tagline'):wikitext(item.site.tagline)
	end
	return html
end

--- @param items table[]
--- @return mw.html
local function renderList(items)
	local list = mw.html.create('ul'):addClass('t-infobox-sites__list')
	for _, item in ipairs(items) do
		list:node(renderItem(item))
	end
	return list
end

--- @param items table[]
--- @param label string
--- @return mw.html|nil
local function renderGroup(items, label)
	if #items == 0 then
		return nil
	end
	return mw.html
		.create('div')
		:addClass('t-infobox-sites__group')
		:tag('div')
		:addClass('t-infobox-sites__group-label')
		:wikitext(label)
		:done()
		:node(renderList(items))
end

--- A full-width branded button. `site.button` names the brand block
--- (`t-button--<brand>`) in Module:ButtonLua/styles.css.
--- @param item table { site, url, name }
--- @return string
local function renderButton(item)
	return Button.render({
		label = item.name,
		url = linkTarget(item.url),
		icon = item.site.icon,
		weight = 'normal',
		class = 't-button--branded t-button--' .. item.site.button,
	})
end

--- @return string
local function iconStyles()
	return mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Icon/styles.css' },
	})
end

--- Builds the infobox's External sites section and the buttons that follow it.
--- Official sites come first, then community ones, each in registry order. A
--- button site (the Star Citizen Wiki API) leaves the collapsible section for a
--- button below it, so it shows while the section is collapsed. An entry naming
--- an unknown site is dropped, and a URL is listed once.
---
--- @param entries EntityExternalSite[]
--- @return table|nil section The collapsed External sites section
--- @return table|nil buttons The label-less section holding the buttons
function p.build(entries)
	local sites = {}
	for order, def in ipairs(mw.loadJsonData(SITES_PATH)) do
		sites[def.id] = { def = def, order = order }
	end

	local items, perSite, seenUrls = {}, {}, {}
	for position, entry in ipairs(entries or {}) do
		local site = sites[entry.site]
		if site and isNonEmptyString(entry.url) and not seenUrls[entry.url] then
			seenUrls[entry.url] = true
			perSite[entry.site] = (perSite[entry.site] or 0) + 1
			items[#items + 1] = { site = site.def, order = site.order, url = entry.url, position = position }
		end
	end
	table.sort(items, bySiteThenPosition)

	local official, community, buttons = {}, {}, {}
	local seen = {}
	for _, item in ipairs(items) do
		local site = item.site
		item.name = site.name
		-- A site linked more than once (a vehicle with two presentations)
		-- numbers its rows.
		if perSite[site.id] > 1 then
			seen[site.id] = (seen[site.id] or 0) + 1
			item.name = site.name .. ' ' .. seen[site.id]
		end
		local group = (isNonEmptyString(site.button) and buttons) or (site.official and official) or community
		group[#group + 1] = item
	end

	local section
	if #official + #community > 0 then
		local root = mw.html.create('div'):addClass('t-infobox-sites'):addClass('plainlinks')
		root:node(renderGroup(official, 'Official'))
		root:node(renderGroup(community, 'Community'))
		section = {
			label = 'External sites',
			collapsible = true,
			collapsed = true,
			content = iconStyles() .. tostring(root),
		}
	end

	local buttonSection
	if #buttons > 0 then
		local root = mw.html.create('div'):addClass('t-infobox-sites__buttons')
		for _, item in ipairs(buttons) do
			root:wikitext(renderButton(item))
		end
		buttonSection = {
			content = tostring(root),
			class = 't-infobox-section--sites-buttons',
		}
	end

	return section, buttonSection
end

return p
