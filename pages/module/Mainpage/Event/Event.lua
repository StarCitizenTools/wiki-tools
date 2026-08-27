require('strict')

--- @module Mainpage/Event
--- The event card built around a banner strip: the picture runs across the top
--- of the card at the height it was drawn, the text sits under it, and the
--- clock lies flat across the bottom.
---
--- WHY THE BAND HOLDS 83px RATHER THAN SCALING. Every file in
--- [[:Category:Main page banner images]] is 1080x83 — one uniform size, not a
--- range. Scaling a 13:1 frieze to the width of a card leaves 55px of picture
--- at the full measure and 22px in the narrowest column, at which point the
--- ships in it are no longer legible as ships. Pinning the band at the file's
--- own height and letting it crop sideways instead keeps everything at the
--- scale it was drawn at, and the card simply shows less of the strip as it
--- narrows: about two thirds of it at the full measure, about a quarter at the
--- narrowest.
---
--- WHAT TO CHECK WHEN SETTING A BANNER is therefore not its height, which is
--- fixed, but whether what matters in it survives a CENTRED crop — the card
--- shows the middle 27-66% of the file depending on how wide it is. A banner
--- whose logo sits near an edge loses it on a narrow screen.
---
--- Everything else follows from the strip. The card is one column at every
--- width, so nothing here changes shape with the viewport and the page owes it
--- no responsive overrides — which Module:Mainpage/Event/Legacy, built around a
--- portrait picture column, does need. That is the trade this layout buys.

local cardLua = require('Module:CardLua')
local countdown = require('Module:Countdown')
local cfg = require('Module:Mainpage/Config')

--- The banners' own width. Requested rather than left at CardLua's 480px
--- default because the band renders the file at 1:1 — a 480px thumbnail would
--- be scaled UP by a third to fill an 83px band.
local BANNER_WIDTH = 1080

local p = {}

--- @return string|nil  nil when the settings carry no event, or no banner
function p.render()
	local event = cfg.section('event')
	if not event.name or not event.banner then
		return nil
	end

	local ends = cfg.toIso(event.ends)

	local body = cardLua.renderMediaBody({
		kicker = 'Event',
		title = event.name,
		link = event.page,
		body = event.text,
		more = 'Read more',
	})

	-- Appended to the content rather than passed as the card's footer. The
	-- banner layout is a column, so an element after the body is already a full
	-- width row across the bottom — and the footer would inset it and draw a
	-- second rule above the one the clock draws itself.
	--
	-- `t-countdown--flat` is Module:Countdown's own modifier for lying down. The
	-- card asks for it rather than restyling the clock from the page, because
	-- the clock owns its arrangement and this card wants it flat at EVERY width
	-- — it is a single column throughout, so there is no viewport question to
	-- ask, which is the one thing a class cannot express and a media query can.
	--
	-- Only rendered when the event has an end date; a clock with nothing to
	-- count towards is worse than no clock. Guarded as well as validated:
	-- Module:Countdown raises on input it cannot read, and no single card is
	-- worth the page.
	if ends then
		local ok, clock = pcall(countdown.render, {
			starts = cfg.toIso(event.starts),
			ends = ends,
			class = 't-countdown--flat',
		})
		if ok then
			body = body .. clock
		end
	end

	return cardLua.renderMediaCard({
		class = 'home-card--read home-event-banner',
		layout = 'banner',
		image = event.banner,
		imageWidth = BANNER_WIDTH,
		stretchLink = true,
		content = body,
	})
end

return p
