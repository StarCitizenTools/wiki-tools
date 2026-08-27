require('strict')

--- @module Mainpage/Hero
--- The full-bleed hero band: patch status, wiki statline, lede, search trigger
--- and the chip strip.
---
--- NOTHING here fetches the artwork. The band carries the image URL in a
--- `data-gadget-mainpage-hero-src` attribute and the `mainpage` gadget
--- ([[MediaWiki:Gadget-mainpage.js]]) loads it after `window.load`, fading it in
--- by adding `home-hero--loaded`. That is what keeps a 1920px photograph off the
--- critical path and lets the band render — legibly, over its own ground colour
--- — for a reader on Save-Data or with scripts off.
---
--- The gadget hooks are all `data-gadget-mainpage-*`, per the house convention:
--- prefixing by gadget name means `grep gadget-mainpage-` finds every emitter
--- and the one gadget that consumes them.
---
--- Everything variable here comes from [[Module:Mainpage/settings.json]].

local cfg = require('Module:Mainpage/Config')
local nav = require('Module:Mainpage/Nav')

--- Width of the thumbnail handed to the gadget. Large enough for a 2x 960px
--- band; the gadget requests it lazily so the size costs nothing up front.
local HERO_WIDTH = '1920'

local p = {}

--- The build chips, one per entry in `patches`. The live build takes the
--- filled marker and the live colour, every other channel the hollow one —
--- and WHICH entry is live is Config's answer, not one computed here, so the
--- chip and the patch card below can never disagree.
---
--- An entry with no name is skipped, and with none left the strip is not
--- emitted at all rather than rendered empty.
---
--- @param root mw.html
local function renderStatus(root)
	local status = mw.html.create('div'):addClass('home-hero__status')
	local live = cfg.livePatch()
	local any = false

	for _, patch in ipairs(cfg.list('patches')) do
		if patch.name then
			local isLive = patch == live
			local label = patch.channel and (patch.channel .. ' ' .. patch.name) or patch.name

			status:tag('span'):addClass(isLive and 'home-hero__status-live' or 'home-hero__status-ptu'):wikitext(
				(isLive and '●' or '◌')
					.. ' '
					.. (patch.page and string.format('[[%s|%s]]', patch.page, label) or label)
			)
			any = true
		end
	end

	if any then
		root:node(status)
	end
end

--- The three site figures. `mw.site.stats` rather than the magic words so the
--- numbers arrive as numbers and can be formatted once, in the content
--- language, the way {{NUMBEROFARTICLES}} would have done.
---
--- Each figure is marked `data-gadget-mainpage-stat`, which is the gadget's
--- hook for rolling the digits on load — it needs to know which figure it is
--- animating so it can count from a sensible starting point.
local STATS = {
	{ key = 'articles', label = 'Articles', icon = 'article' },
	{ key = 'edits', label = 'Edits', icon = 'edit' },
	{ key = 'users', label = 'Registered users', icon = 'userAvatar' },
}

--- @param content mw.html
local function renderStatline(content)
	local lang = mw.language.getContentLanguage()

	-- A description list, because that is the shape of the data: three labelled
	-- figures. The label is an icon plus visually-hidden text, so the meaning
	-- survives with images off or under a screen reader.
	local list = content:tag('dl'):addClass('home-hero__statline')

	for _, stat in ipairs(STATS) do
		local group = list:tag('div'):addClass('home-hero__stat')

		local label = group:tag('dt'):addClass('home-hero__stat-label')
		label
			:tag('span')
			:addClass('citizen-ui-icon')
			:addClass('mw-ui-icon-' .. stat.icon)
			:addClass('mw-ui-icon-wikimedia-' .. stat.icon)
			:attr('aria-hidden', 'true')
		label:tag('span'):addClass('home-hero__sr'):wikitext(stat.label)

		group
			:tag('dd')
			:addClass('home-hero__stat-value')
			:attr('data-gadget-mainpage-stat', stat.key)
			:wikitext(lang:formatNum(mw.site.stats[stat.key]))
	end
end

--- @param content mw.html
--- @param frame mw.frame
local function renderSearch(content, frame)
	local tails = cfg.section('hero').searchTails or {}

	-- `role="button"` and not a real <button>: the element opens Citizen's own
	-- search overlay, which the skin binds by the `citizen-search-trigger`
	-- class. A <button> here would be a second, competing control.
	local search = content
		:tag('div')
		:addClass('home-hero__search')
		:addClass('citizen-search-trigger')
		:attr('role', 'button')
		:wikitext('[[File:WikimediaUI-Search.svg|16px|link=|alt=]]')

	local label = search:tag('span'):addClass('home-hero__search-label')
	label:wikitext('Search&nbsp;')

	local tail = label:tag('span'):addClass('home-hero__search-tail')
	if tails[1] ~= nil then
		-- The tail the gadget rolls through. The FIRST value is also what is
		-- rendered here, so the server-side text is one of the real phrases
		-- rather than a placeholder that flashes and is replaced.
		tail:attr('data-gadget-mainpage-search-tails', table.concat(tails, '|'))
		tail:wikitext(tails[1])
	else
		tail:wikitext('the Star Citizen Wiki')
	end

	search:wikitext(frame:expandTemplate({ title = 'Key press', args = { '/' } }))
end

--- @param content mw.html
local function renderChips(content)
	local strip = content:tag('div'):addClass('home-hero__tabs')
	for _, chip in ipairs(nav.chips()) do
		local wikitext = nav.renderLink(chip)
		if wikitext then
			strip:wikitext(wikitext)
		end
	end
end

--- @class HeroProps
--- @field lazyArt? boolean  Emit the gadget's artwork hook. False renders the
---        band exactly as a reader with no JavaScript, or with Save-Data on,
---        receives it: no artwork is ever fetched.

--- @param props HeroProps
--- @return string
function p.render(props)
	props = props or {}
	local frame = mw.getCurrentFrame()

	local root = mw.html.create('div'):addClass('home-band'):addClass('home-hero')

	if props.lazyArt ~= false then
		local image = cfg.section('hero').image
		if image then
			root:attr('data-gadget-mainpage-hero-src', frame:callParserFunction('filepath', { image, HERO_WIDTH }))
		end
	end

	-- Both are empty and both are painted entirely in CSS: the media box is
	-- where the gadget puts the photograph, the scrim is the gradient that
	-- keeps the text legible over whatever the photograph turns out to be.
	root:tag('div'):addClass('home-hero__media')
	root:tag('div'):addClass('home-hero__scrim')

	renderStatus(root)

	-- home-band__inner is the measured column every band shares, so the hero's
	-- text lines up with the cards below it.
	local content = root:tag('div'):addClass('home-band__inner'):addClass('home-hero__content')

	renderStatline(content)

	-- The trailing space is load-bearing: the two halves are one sentence set in
	-- two tones, and mw.html concatenates its children with nothing between
	-- them, so without it the dim half would butt against the bright one.
	local hero = cfg.section('hero')
	content
		:tag('div')
		:addClass('home-hero__title')
		:wikitext((hero.lede or 'Bespoke Star Citizen and Squadron&nbsp;42 wiki.') .. ' ')
		:tag('span')
		:addClass('home-hero__title-dim')
		:wikitext(hero.ledeDetail or 'Held the line since 2016.')

	renderSearch(content, frame)
	renderChips(content)

	return tostring(root)
end

return p
