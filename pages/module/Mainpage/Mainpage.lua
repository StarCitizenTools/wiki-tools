require('strict')

--- @module Mainpage
--- Renders the main page.
---
--- Everything editors change — the featured article, the running event, the
--- build chips, the hero, and both link lists — lives in
--- [[Module:Mainpage/settings.json]]. Nothing on this page needs a module edit
--- to keep it current, and the foot links straight to it.
---
--- LAYOUT CONTRACT. Every band is `.home-band` for its full-bleed ground and
--- `.home-band__inner` for the measured column inside it, and every band of
--- cards puts `.home-grid` on that inner element. One twelve-column grid is
--- shared by all of them, so a card edge in one band lands on the same line as
--- a card edge in the next. A band that sets its own column ratios breaks that
--- alignment for every band on the page.
---
--- Card spans go on the card itself (`.home-card--read`, `--aside`, `--tall`)
--- because `grid-column` is a placement property and cannot collide with
--- Module:CardLua's own `display` on `.t-card`. A class that sets `display`
--- must never share an element with `t-card`.
---
--- Structure:
---
---   hero          full bleed, gadget-loaded artwork
---   highlights    [ event 8 ][ patch 4 ]
---   band 1        [ featured 8 ][ on this day 4 ]
---   band 2        [ editing 8, two rows ][ support 4 ]
---                                        [ discussion 4 ]
---   directory     six groups, no card
---   foot          where to edit what the page says

local community = require('Module:Mainpage/Community')
local directory = require('Module:Mainpage/Directory')
local editing = require('Module:Mainpage/Editing')
local featured = require('Module:Mainpage/Featured')
local hero = require('Module:Mainpage/Hero')
local highlights = require('Module:Mainpage/Highlights')
local onThisDay = require('Module:Mainpage/OnThisDay')

--- Loaded in this order: the card primitive first, then the grid and hero, then
--- the components that sit on the grid, then the ground behind both.
---
--- CardLua's sheet is listed EXPLICITLY rather than left to arrive with a
--- CardLua call. Five of the seven cards are built here with `.t-card` on a
--- plain div, so the card surface, border and radius would otherwise depend on
--- the highlights band happening to render — and that band is empty whenever
--- both its settings keys are blank.
local STYLESHEETS = {
	'Module:CardLua/styles.css',
	'Module:Mainpage/styles.css',
	'Module:Mainpage/cards.css',
	'Module:Mainpage/ground.css',
}

--- Where to go to change what the page says, linked at the foot.
---
--- NOT "edit this page". The page is a single transclusion, so an edit link on
--- it lands an editor in a file with nothing in it to change. This is the one
--- surface that holds content, and it covers everything an editor can change
--- without touching Lua.
local EDIT_TARGETS = {
	{ page = 'Module:Mainpage/settings.json', label = 'Settings' },
}

--- What loads [[MediaWiki:Gadget-mainpage.js]]. Emitted by the module so the
--- invocation is self-sufficient: a page that renders this and does not carry
--- the category gets no lazy artwork, no rolling digits and a clock that never
--- starts, with nothing on the page to say why.
local GADGET_CATEGORY = 'Pages using main page gadget'

local p = {}

--- @param frame mw.frame
--- @return string
local function stylesheets(frame)
	local tags = {}
	for _, src in ipairs(STYLESHEETS) do
		tags[#tags + 1] = frame:extensionTag({
			name = 'templatestyles',
			args = { src = src },
		})
	end
	return table.concat(tags)
end

--- One band of cards on the shared grid.
---
--- Varargs and not a table: a table would be walked with ipairs, which stops at
--- the first nil, so a card that declined to render would silently take every
--- card after it with it. select('#') counts the nils.
---
--- @param ... string|nil
--- @return string
local function band(...)
	local root = mw.html.create('div'):addClass('home-band'):addClass('home-wiki')

	local inner = root:tag('div'):addClass('home-band__inner'):addClass('home-grid')

	for i = 1, select('#', ...) do
		inner:wikitext((select(i, ...)))
	end

	return tostring(root)
end

--- The maintenance affordance at the foot of the page.
---
--- External-link syntax because an internal link cannot carry a query string,
--- and `plainlinks` because the destinations are on this wiki and the arrow
--- icon would say otherwise.
---
--- mw.uri.fullUrl and NOT callParserFunction: `fullurl` is a colon magic word,
--- registered under the name `fullurl:`, and callParserFunction resolves it as
--- `fullurl`, which does not exist. mw.uri is the addressable API for this.
---
--- @return string
local function footer()
	local root = mw.html.create('div'):addClass('home-band'):addClass('home-wiki')

	local inner = root:tag('div'):addClass('home-band__inner'):addClass('home-foot'):addClass('plainlinks')

	for _, target in ipairs(EDIT_TARGETS) do
		inner
			:tag('span')
			:wikitext(string.format('[%s %s]', tostring(mw.uri.fullUrl(target.page, 'action=edit')), target.label))
	end

	return tostring(root)
end

--- @return string
function p.render()
	local frame = mw.getCurrentFrame()

	local root = mw.html.create('div'):addClass('home-page')

	-- Both are empty and painted entirely in CSS: the dot lattice outside the
	-- tapes, and the tapes themselves. The tape is `position: fixed` and the
	-- dots are not, so the instrument holds still while the page scrolls past.
	root:tag('div'):addClass('home-sky')
	root:tag('div'):addClass('home-tape')

	root:wikitext(hero.render({}))
	root:wikitext(highlights.render())
	root:wikitext(band(featured.render(), onThisDay.render()))
	root:wikitext(band(editing.render(), community.renderSupport(), community.renderDiscussion()))
	root:wikitext(directory.render())
	root:wikitext(footer())

	return stylesheets(frame) .. tostring(root) .. string.format('[[Category:%s]]', GADGET_CATEGORY)
end

--- Wikitext entry point. Reached through [[Template:Mainpage]] rather than
--- invoked directly, so the page that carries it stays one transclusion.
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	return p.render()
end

--- The hero on its own, for previewing it outside the page. `noscript=yes`
--- renders it without the gadget's artwork hook, which is what a reader with
--- scripts off or Save-Data on receives.
---
--- @param frame mw.frame
--- @return string
function p.hero(frame)
	local args = require('Module:Arguments').getArgs(frame)
	local yesno = require('Module:Yesno')

	return stylesheets(frame)
		.. tostring(
			mw.html
				.create('div')
				:addClass('home-page')
				:wikitext(hero.render({ lazyArt = yesno(args.noscript, false) ~= true }))
		)
end

return p
