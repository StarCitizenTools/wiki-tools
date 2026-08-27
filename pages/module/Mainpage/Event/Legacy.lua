require('strict')

--- @module Mainpage/Event/Legacy
--- The event card built around an ordinary photograph: the picture stands in a
--- column beside the text on a wide card, and the clock stands beside that.
---
--- Kept as the alternative to Module:Mainpage/Event, which is built around the
--- 1080x83 strips in [[:Category:Main page banner images]] instead. Which one
--- the page uses follows from which key the settings file carries, so switching
--- back is a settings edit and not a module edit.
---
--- Its cost, and the reason it is no longer the default: a portrait column is
--- the one shape a wide banner cannot be cropped to, and the card changes shape
--- twice on the way down to a phone, so both the picture column and the clock
--- need viewport overrides from the page in Module:Mainpage/styles.css.

local cardLua = require('Module:CardLua')
local countdown = require('Module:Countdown')
local cfg = require('Module:Mainpage/Config')

local p = {}

--- @return string|nil  nil when the settings carry no event
function p.render()
	local event = cfg.section('event')
	if not event.name then
		return nil
	end

	local ends = cfg.toIso(event.ends)

	-- The clock is appended to the card's CONTENT, not passed as its footer:
	-- the media card lays its content out as flex children of one row, so an
	-- element after the body becomes a second column beside it. A footer would
	-- put it across the bottom of the card instead.
	local body = cardLua.renderMediaBody({
		kicker = 'Event',
		title = event.name,
		link = event.page,
		body = event.text,
		more = 'Read more',
	})

	-- Only rendered when the event has an end date; a clock with nothing to
	-- count towards is worse than no clock. Guarded as well as validated:
	-- Module:Countdown raises on input it cannot read, and no single card is
	-- worth the page.
	if ends then
		local ok, clock = pcall(countdown.render, {
			starts = cfg.toIso(event.starts),
			ends = ends,
		})
		if ok then
			body = body .. clock
		end
	end

	return cardLua.renderMediaCard({
		class = 'home-card--read home-event-split',
		image = event.image,
		stretchLink = true,
		content = body,
	})
end

return p
