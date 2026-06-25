require('strict')

--- @module Entity/Availability
--- Renders where/how an entity can be acquired in-game, dispatched by kind:
---  * items / vehicles — UEX shop (and rental) terminals from apiData.uex_prices
---  * commodities — a Mining card (deposit locations) + a Trade card (UEX
---    terminals when priced, else a link-out to external price sources).
--- Consumes Module:Entity/Data so it shares Apiunto's cache with other Entity
--- templates on the page.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')
local cardLua = require('Module:CardLua')
local tableLua = require('Module:TableLua')
local uec = require('Module:UEC')

local p = {}

--- Zero prices render as `-` (UEX uses 0 rather than null for "not sold
--- here"). Otherwise returns the UEC component (Module:UEC): the currency
--- glyph followed by the locale-grouped amount (e.g. 123456 → "123,456").
--- TableLua strips HTML before sorting, so the column still sorts on the
--- grouped number.
---
--- @param price number|nil
--- @return string
local function formatPrice(price)
	if not price or price == 0 then
		return '-'
	end
	return uec._main(price)
end

--- Wraps the Apiunto ISO 8601 timestamp in a <time> element. The visible
--- text is truncated to YYYY-MM-DD because the HH:MM:SS adds precision
--- readers can't act on, while the datetime attribute preserves the full
--- timestamp for machine readers and assistive tech.
--- TableLua's sort strips HTML before comparing, so sorting stays correct.
---
--- @param isoDate string|nil
--- @return string
local function formatDate(isoDate)
	if type(isoDate) ~= 'string' or isoDate == '' then
		return '-'
	end
	return tostring(mw.html.create('time'):attr('datetime', isoDate):wikitext(isoDate:sub(1, 10)))
end

--- Trims the full UEX `game_version` ("4.7.2-LIVE.11674325") down to
--- just the marketing version ("4.7.2"). The `-LIVE.build` suffix is
--- internal CIG release metadata that doesn't help a player judge
--- whether the price is current — knowing it was reported in 4.7.2 is
--- enough context.
---
--- @param version string|nil
--- @return string
local function formatVersion(version)
	if type(version) ~= 'string' or version == '' then
		return '-'
	end
	return version:match('^[^-]+') or '-'
end

--- Wikilink to the parent star system, e.g. `[[Stanton system|Stanton]]`.
--- Falls back to `-` when the API didn't enrich the entry with a
--- starmap_location (older terminals haven't been mapped yet).
---
--- @param entry table
--- @return string
local function formatSystemCell(entry)
	local loc = entry.starmap_location
	if type(loc) == 'table' and type(loc.star_system_name) == 'string' and loc.star_system_name ~= '' then
		local system = loc.star_system_name
		return '[[' .. system .. ' system|' .. system .. ']]'
	end
	return '-'
end

--- Wraps the terminal name in a wikilink to its parent location (e.g.
--- "Juice Bar - Seraphim Station" → `[[Seraphim Station|Juice Bar - Seraphim Station]]`).
--- The link target is `starmap_location.name`; most of those names map
--- directly to wiki pages, and red links act as a polite invitation to
--- create them. When starmap_location is missing entirely, falls back
--- to the plain terminal name.
---
--- Gateway stations get the system appended as a disambiguator
--- ("Stanton Gateway" → "Stanton Gateway (Pyro)") because their bare
--- name collides with the destination system's name on the wiki. The
--- visible cell text stays the bare terminal name.
---
--- @param entry table
--- @return string
local function formatLocationCell(entry)
	local terminalName = entry.terminal_name or '-'
	local loc = entry.starmap_location
	if type(loc) ~= 'table' or type(loc.name) ~= 'string' or loc.name == '' then
		return terminalName
	end
	local linkTarget = loc.name
	if linkTarget:match(' Gateway$') and type(loc.star_system_name) == 'string' and loc.star_system_name ~= '' then
		linkTarget = linkTarget .. ' (' .. loc.star_system_name .. ')'
	end
	return '[[' .. linkTarget .. '|' .. terminalName .. ']]'
end

--- Renders a UEX terminal table. The columns System / Location /
--- Updated / Version are fixed (every terminal row carries those);
--- callers supply the price columns that apply to their market —
--- `{ id = 'buy', key = 'price_buy', label = 'Buy' }` for items'
--- buy side, `{ id = 'rent', key = 'price_rent', label = 'Rent' }`
--- for vehicle rentals, etc.
---
--- @param opts { prices: table[], caption: string, priceColumns: { id: string, key: string, label: string }[] }
--- @return string
local function renderTerminalTable(opts)
	local columns = {
		{ id = 'system', label = 'System', textAlign = 'start' },
		{ id = 'location', label = 'Location', textAlign = 'start' },
	}
	for _, col in ipairs(opts.priceColumns) do
		table.insert(columns, { id = col.id, label = col.label, textAlign = 'number' })
	end
	table.insert(columns, { id = 'updated', label = 'Updated', textAlign = 'end' })
	table.insert(columns, { id = 'version', label = 'Version', textAlign = 'end' })

	local rows = {}
	for _, entry in ipairs(opts.prices) do
		local row = { formatSystemCell(entry), formatLocationCell(entry) }
		for _, col in ipairs(opts.priceColumns) do
			table.insert(row, formatPrice(entry[col.key]))
		end
		table.insert(row, formatDate(entry.date_updated))
		table.insert(row, formatVersion(entry.game_version))
		table.insert(rows, row)
	end

	return tableLua.render({
		caption = opts.caption,
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = columns,
		data = rows,
		-- UEX prices are player-reported, so sort by freshness (newest first).
		-- The ISO date string sorts lexicographically the same way as a real
		-- date comparison, so no custom comparator is needed.
		sort = { updated = 'desc' },
	})
end

--- true → "Yes", false → "No", nil → "Unknown". Module:Yesno already
--- collapses input variations to this three-state logic. Rendered as
--- visually-hidden text inside the summary value cell — sighted
--- readers see the icon, assistive tech / reader modes / translators
--- read this text.
---
--- @param value boolean|nil
--- @return string
local function formatFlag(value)
	if value == true then
		return 'Yes'
	end
	if value == false then
		return 'No'
	end
	return 'Unknown'
end

--- Maps the flag value to a state slug used as the BEM modifier
--- suffix on the summary item (`…-item--yes` etc.) and as the
--- canonical `data-state` attribute. CSS uses a descendant selector
--- to set the value icon and color from the item's state, so any
--- future card-level treatment (background tint, etc.) can target the
--- item directly without reaching in.
---
--- @param value boolean|nil
--- @return string
local function flagState(value)
	if value == true then
		return 'yes'
	end
	if value == false then
		return 'no'
	end
	return 'unknown'
end

--- Renders the summary rows as a grid of label/value items. Each item
--- has a category icon + label on the left and a value `<dd>` on the
--- right styled as a 16×16 mask-image icon. The state ("yes" / "no" /
--- "unknown") lives on the item element (the dt/dd pair's wrapper)
--- rather than the value cell, so card-level treatment (background
--- tint, border accent, etc.) can target the item directly:
---  * `data-state` on the item `<div>` is the canonical
---    machine-readable target — scrapers and AI agents query
---    `[data-state]` rather than parsing class modifiers.
---  * A visually-hidden `<span>` inside the `<dd>` carries the
---    human-readable text ("Yes" / "No" / "Unknown"). Screen readers
---    announce it as the `<dd>`'s content; translation tools and reader
---    modes pick it up too (both of which can ignore `aria-label`).
--- The category icon span carries `aria-hidden="true"` so screen
--- readers don't double-announce it on top of the visible label text.
--- Always shows every row so the layout stays stable across pages.
---
--- @param rows { label: string, icon: string|nil, value: boolean|nil }[]
--- @return string
local function renderSummary(rows)
	local root = mw.html.create('dl'):addClass('t-entity-availability-summary')
	for _, row in ipairs(rows) do
		local state = flagState(row.value)
		local itemHtml = root:tag('div')
			:addClass('t-entity-availability-summary-item')
			:addClass('t-entity-availability-summary-item--' .. state)
			:attr('data-state', state)
		local labelHtml = itemHtml:tag('dt'):addClass('t-entity-availability-summary-label')
		if row.icon and row.icon ~= '' then
			labelHtml
				:tag('span')
				:addClass('t-entity-availability-summary-icon')
				:attr('aria-hidden', 'true')
				:wikitext(row.icon)
		end
		labelHtml:wikitext(row.label)
		itemHtml
			:tag('dd')
			:addClass('t-entity-availability-summary-value')
			:tag('span')
			:addClass('t-entity-availability-summary-value-text')
			:wikitext(formatFlag(row.value))
	end
	return tostring(root)
end

-- Home page, used when no terminal carries a deep `uex_link`.
local UEX_FALLBACK_URL = 'https://uexcorp.space'

--- Returns the first non-empty `uex_link` among the given price rows, or
--- nil when none carry one. UEX exposes `uex_link` per terminal (a deep
--- link into that terminal's listing), not per entity; the footer uses
--- the first as a representative entry point into UEX for this data.
---
--- @param prices table[]|nil
--- @return string|nil
local function firstUexLink(prices)
	if type(prices) ~= 'table' then
		return nil
	end
	for _, entry in ipairs(prices) do
		local link = entry.uex_link
		if type(link) == 'string' and link ~= '' then
			return link
		end
	end
	return nil
end

--- Builds the attribution footer: just the UEX logo (no leading text),
--- linking to `url`. `class=metadata` keeps PageImages from selecting
--- this attribution logo as the page image. "powered by UEX" goes in both
--- `alt` (assistive tech) and the unnamed caption, which MediaWiki maps to
--- the `title` attribute (hover tooltip) for an inline image.
---
--- @param url string
--- @return string
local function uexFooter(url)
	return '[[File:UEX logo.svg|class=metadata|link=' .. url .. '|alt=powered by UEX|x12px|powered by UEX]]'
end

--- Renders one acquisition card from a kind's getAcquisition spec. A `terminals`
--- card becomes a collapsible card wrapping renderTerminalTable + the UEX footer;
--- a `links` card is a link-out; an `html` card (e.g. the commodity mining card,
--- pre-rendered by Module:Entity/Commodity/Mining) passes through verbatim.
---
--- @param card table
--- @return string
local function renderCard(card)
	if card.type == 'html' then
		return card.html
	end
	if card.type == 'links' then
		return cardLua.renderLinkCard({ title = card.title, buttons = card.buttons })
	end
	-- 'terminals'
	local prices = card.prices
	return collapsibleCard.render({
		title = card.title,
		description = card.description,
		content = (prices and #prices > 0) and renderTerminalTable({
			prices = prices,
			caption = card.caption,
			priceColumns = card.priceColumns,
		}) or nil,
		footer = uexFooter(firstUexLink(prices) or UEX_FALLBACK_URL),
	})
end

--- Main entry point. Dispatches to `result.matchedKind.getAcquisition` and
--- renders the returned summary + cards. Returns just the styles tag when the
--- matched kind carries no getAcquisition hook (e.g. Contract).
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Availability/styles.css' },
	})

	local kind = result.matchedKind
	if not (kind and kind.getAcquisition) then
		return styles
	end
	local a = kind.getAcquisition(result.apiData, args)
	if not a then
		return styles
	end

	local cards = {}
	for _, card in ipairs(a.cards or {}) do
		cards[#cards + 1] = renderCard(card)
	end
	return styles .. renderSummary(a.summary or {}) .. table.concat(cards, '\n')
end

-- Test-only exports. Not part of the public API.
p._internal = {
	renderCard = renderCard,
}

return p
