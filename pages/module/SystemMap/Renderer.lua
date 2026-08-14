require('strict')

--- @module SystemMap/Renderer
--- Turns a render-ready system-map model into mw.html. Takes no data
--- dependency and does not resolve page titles itself — everything it needs
--- is already on the model, so the same markup can be produced in a test
--- without a parser.
---
--- Markup constraints (see AGENTS.md): the MediaWiki sanitizer escapes unknown
--- HTML5 structural tags, so this uses div/ul/li/span only. Headings are
--- role="heading" rather than h1-h6 to keep the TOC clean.

local p = {}

--- Build the link for one body as wikitext, so MediaWiki resolves the target
--- and red-links it when the page is absent.
--- @param body SystemMapBody
--- @return string
local function linkFor(body)
	return string.format('[[%s|%s]]', body.page, body.label)
end

--- Render a single body node: the glyph box plus its stacked label.
--- @param body SystemMapBody
--- @return mw.html
local function bodyNode(body)
	local node = mw.html.create('span'):addClass('t-system-map__node')

	if body.current then
		-- data-current, NOT aria-current: MediaWiki's HTML sanitizer does not
		-- allowlist aria-current and silently strips it, so the CSS hook would
		-- never match. Nothing local catches this — the off-wiki runner asserts on
		-- mw.html output, which is upstream of the sanitizer, so an aria-current
		-- assertion is a false pass. Verified against the live parser: aria-label
		-- and aria-level survive, aria-current does not.
		node:attr('data-current', 'page')
	end

	-- The disc is a real element rather than a ::before, because its diameter is
	-- per-body and a pseudo-element cannot carry an inline style.
	local glyph = node:tag('span'):addClass('t-system-map__glyph')

	if body.icon then
		-- Height-constrained (x<N>px), never width. A ringed body's icon is much
		-- wider than tall — Terminus is 2.8:1 — so sizing by width would shrink
		-- the planet itself to a third of its proper size. Constraining height
		-- keeps every body's disc consistent and lets the rings extend sideways.
		glyph:addClass('t-system-map__glyph--image')
		glyph:wikitext(string.format('[[File:%s|x%dpx|link=|alt=]]', body.icon, math.floor(body.disc + 0.5)))
	else
		-- No render on the wiki: fall back to the procedural disc. Stars keep
		-- their spectral-class gradient and belts their speckled band, which are
		-- the right treatments for those tiers anyway.
		local w, h = body.disc, body.disc
		if body.band then
			w, h = body.band.width, body.band.height
		end
		glyph
			:tag('span')
			:addClass('t-system-map__disc')
			:cssText(string.format('width:%.1fpx;height:%.1fpx', w, h))
			:done()
	end

	glyph:done()

	local label = node:tag('span'):addClass('t-system-map__label')
	local name = label:tag('span'):addClass('t-system-map__name')
	name:wikitext(linkFor(body))

	-- The sighted cue is a bolder, brighter name plus a trailing dot, both drawn
	-- in CSS and so invisible to assistive technology. (No ring: styles.css says
	-- why.) With aria-current stripped by the sanitizer, a visually-hidden phrase
	-- is what actually carries "you are here" to a screen reader. Mirrors
	-- Module:Boolean's __sr pattern.
	if body.current then
		name:tag('span'):addClass('t-system-map__sr'):wikitext(' (current page)'):done()
	end
	name:done()

	-- Bodies CIG never named carry their designation as the article title too
	-- (Pyro I, Nyx III, Delamar), so printing both would repeat the same string
	-- on 7 of the 35 bodies. The designation line is for the cases where it adds
	-- something the name does not.
	--
	-- The comparison is case-INSENSITIVE, and it is defensive depth rather than
	-- the load-bearing fix it started as. The generator now sentence-cases an
	-- unnamed belt's label and page as well as its designation, so for most
	-- generated data all three agree exactly.
	--
	-- Not all of it, though: a designation whose remainder starts with a digit is
	-- stripped of its system prefix, the rule that turns "Stanton 1a" into "1a"
	-- for a moon. So "Taranis 2a Debris" ends up labelled "Taranis 2a debris"
	-- against designation "2a debris" — different strings, and the designation
	-- line correctly prints.
	--
	-- It is kept because this module takes no data dependency and has to be right
	-- for any model handed to it, not only for what today's generator emits. The
	-- overlay's `label` key is judgement and is stored verbatim — it is the
	-- documented escape hatch for a belt whose article really is titled in Title
	-- Case — so a hand-authored label differing from the sentence-cased
	-- designation only in case is reachable, and an exact compare would stack
	-- "Bacchus belt alpha" under "Bacchus Belt Alpha" on a live page. A case-only
	-- difference is never something a reader needs on a second line: both lines
	-- are the same words. So this can only hide noise, never a fact.
	if body.designation and mw.ustring.lower(body.designation) ~= mw.ustring.lower(body.label) then
		label:tag('span'):addClass('t-system-map__desig'):wikitext(body.designation):done()
	end

	-- Subtype is deliberately not printed. It still earns its keep — it is what
	-- Module:SystemMap/Data turns into the glyph kind, so a gas giant reads as a
	-- banded amber disc and an ice giant as a banded cyan one — but as a text row
	-- under every body it was noise, and it made each column three lines tall.

	return node
end

--- Render the <li> wrapper for one body.
--- @param body SystemMapBody
--- @return mw.html
local function bodyItem(body)
	local item = mw.html
		.create('li')
		:addClass('t-system-map__item')
		:addClass('t-system-map__item--' .. body.tier)
		:attr('data-kind', body.kind)

	if body.missing then
		item:addClass('t-system-map__item--missing')
	end

	item:node(bodyNode(body))

	-- Emptiness test idiom: on a table from mw.loadJsonData BOTH `#t` and
	-- `next(t)` are broken — Scribunto's dataWrapper returns a genuinely empty
	-- table carrying __index/__pairs/__ipairs, and mwInit patches the `pairs`
	-- and `ipairs` globals to honour those metamethods but does NOT patch
	-- `next`. Only `t[1] ~= nil` (and pairs/ipairs) is safe there. This table is
	-- built locally by Module:SystemMap/Data, so any of the three would work;
	-- `t[1] ~= nil` is used so the safe idiom is the one that gets copy-pasted.
	if body.moons and body.moons[1] ~= nil then
		-- The connector line down the moon column is drawn on the planet <li>,
		-- and the :has pseudo-class is not in TemplateStyles' allowlist (an
		-- unrecognised selector makes the stylesheet save fail outright), so the
		-- "this planet has moons" condition is carried as a modifier class.
		item:addClass('t-system-map__item--has-moons')

		local moons = item:tag('ul'):addClass('t-system-map__moons')
		for _, moon in ipairs(body.moons) do
			moons:node(bodyItem(moon))
		end
	end

	return item
end

--- Render the head of the rail: the system's star, or its two stars.
---
--- Three shapes, and the third is the reason this is a function rather than one
--- line in renderRail:
---
--- - One star, or a nested binary. The plain body item — a nested companion is
---   already sitting in the star's `moons` list, put there by
---   Module:SystemMap/Data, so it comes out of the same machinery every moon
---   does.
--- - A co-orbiting pair. Both stars share ONE rail slot, so the orbit line
---   (drawn on the rail's direct children) begins at the pair rather than at
---   either star. They are wrapped in an inner list so that each keeps its own
---   <li> and therefore its own `data-kind` — the palette is keyed on the item,
---   and Bacchus A is a G-type while Bacchus B is a K-type. That inner <li> is
---   also what carries `data-current`: Bacchus A and Bacchus B are separate
---   articles, and a reader on either must see themselves marked, which one
---   merged "A · B" label could not do.
--- - No star at all. Two upstream systems have none and still carry planets, so
---   the rail simply starts at the first planet.
--- @param model SystemMapModel
--- @return mw.html|nil
local function headItem(model)
	if model.companion and model.companionShape == 'paired' and model.star then
		local item = mw.html
			.create('li')
			:addClass('t-system-map__item')
			:addClass('t-system-map__item--star')
			:addClass('t-system-map__item--pair')

		local pair = item:tag('ul'):addClass('t-system-map__pair')
		pair:node(bodyItem(model.star))
		pair:node(bodyItem(model.companion))

		return item
	end

	if model.star then
		return bodyItem(model.star)
	end

	-- A companion with no primary is not a shape the generator can produce, but
	-- this module takes no data dependency and has to be right for any model
	-- handed to it. Drawing the star that is there beats drawing nothing.
	if model.companion then
		return bodyItem(model.companion)
	end

	return nil
end

--- Render the scroll container and rail: the star followed by every planet
--- (with its moons nested inside). Module:SystemMap hands this to
--- Module:CollapsibleCard as the card's body.
---
--- This element, not some ancestor, is where styles.css declares the
--- --t-system-map-track / --t-system-map-centre custom properties the geometry
--- depends on. Declaring them on a root owned by a different module is how they
--- previously ended up orphaned: every var() consumer silently fell back to its
--- initial value and the whole 32/16 alignment contract went void while the
--- tests stayed green. Emitter and consumers now live in the same subtree, so
--- no wrapper change elsewhere can break it again.
--- @param model SystemMapModel
--- @return mw.html
function p.renderRail(model)
	local scroll = mw.html.create('div'):addClass('t-system-map__scroll')
	local rail = scroll:tag('ul'):addClass('t-system-map__rail')

	local head = headItem(model)
	if head then
		rail:node(head)
	end
	for _, body in ipairs(model.bodies) do
		rail:node(bodyItem(body))
	end

	return scroll
end

-- There is deliberately no header renderer here. The header row, its title, the
-- collapse affordance and the chevron all come from Module:CollapsibleCard, so
-- the map gets the same shell as every other card on the wiki rather than a
-- hand-rolled imitation of it.

return p
