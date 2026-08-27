require('strict')

--- @module Mainpage/Featured
--- The featured card: a whole-card link over the featured page's own artwork.
---
--- The picture comes from the page's `Page Image` semantic property rather than
--- from a setting, so promoting a different article is a one-word edit to
--- `featured.page` in [[Module:Mainpage/settings.json]] and nothing else. A
--- page with no Page Image falls back to the placeholder.
---
--- The card is NOT built on Module:CardLua. CardLua's media card puts its
--- picture in a slot beside or above a body; this one puts the body *over* the
--- picture, under a scrim, and slides both off on hover. That is a different
--- component, not a variant of that one.

local badge = require('Module:BadgeLua')
local cfg = require('Module:Mainpage/Config')

-- NOT the main page itself: on the main page that would render as a self-link
-- (<strong class="selflink">, not an <a>), and the whole-card link selector
-- would match nothing, leaving a card that looks clickable and is not.
local DEFAULT_PAGE = 'Star Citizen'
local PLACEHOLDER = 'File:Placeholderv2.png'

--- Wide enough for the plate at the full 1080 measure on a 2x display.
local IMAGE_WIDTH = '960px'

local p = {}

--- @return string
function p.render()
	local frame = mw.getCurrentFrame()
	local featured = cfg.section('featured')
	local page = featured.page or DEFAULT_PAGE
	local tagline = featured.text

	-- `#show` with `#-` returns the raw file title rather than a rendered link,
	-- which is what can then be fed back into a file link with a size.
	local image = frame:callParserFunction('#show', {
		page,
		'?Page Image#-',
		'default=' .. PLACEHOLDER,
	})
	if not image or mw.text.trim(image) == '' then
		image = PLACEHOLDER
	end

	local card = mw.html.create('div'):addClass('t-card'):addClass('home-card--read'):addClass('home-feat-card')

	local feat = card:tag('div'):addClass('home-feat')

	feat:tag('div'):addClass('home-feat__media'):wikitext(string.format('[[%s|%s|link=|alt=]]', image, IMAGE_WIDTH))

	-- `link=` and `alt=` are both empty on purpose: the whole card is already
	-- one link with an accessible name, so the picture must add neither a
	-- second tab stop nor a second description of the same destination.
	feat:tag('div'):addClass('home-feat__scrim')

	local body = feat:tag('div'):addClass('home-feat__body')

	-- Wrapped so the badge stays inline: a flex item is blockified, and the
	-- badge's own inline-flex would otherwise resolve to flex and stretch it
	-- across the card.
	body:tag('div')
		:addClass('home-feat__badge-row')
		:wikitext(badge.render({ text = 'Featured', class = 'home-feat__badge' }))

	local foot = body:tag('div'):addClass('home-feat__foot')
	foot:tag('div'):addClass('home-feat__title'):wikitext(page)
	if tagline then
		foot:tag('div'):addClass('home-feat__tag'):wikitext(tagline)
	end

	-- The card's single link, as a sibling of the body rather than a stretch
	-- pseudo-element on the title: the body transforms on hover, and a
	-- transform makes an element the containing block for its absolutely
	-- positioned descendants, which would shrink the click target to the body.
	--
	-- The visible title is deliberately not a link, so this anchor is the only
	-- stop for the destination; its name comes from the visually-hidden span.
	feat:tag('div')
		:addClass('home-feat__link')
		:wikitext(string.format('[[%s|<span class="home-feat__sr">%s</span>]]', page, page))

	return tostring(card)
end

return p
