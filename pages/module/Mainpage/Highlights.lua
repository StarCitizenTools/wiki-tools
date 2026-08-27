require('strict')

--- @module Mainpage/Highlights
--- The band directly under the hero: what is happening now (an event, with its
--- clock) and what shipped last (the current patch).
---
--- The event card has two designs and this module owns neither. Which one runs
--- follows from the picture the settings file carries, because the picture is
--- the thing that actually differs: a `banner` is one of the 1080x83 strips in
--- [[:Category:Main page banner images]], which only the banner layout can
--- show without smearing, and an `image` is an ordinary photograph, which only
--- the split layout crops sensibly. Naming the asset therefore names the
--- layout, and no editor can pair a design with a picture it cannot show.
---
--- The patch card stays here: it carries no picture, so it has no such choice
--- to make.

local cardLua = require('Module:CardLua')
local cfg = require('Module:Mainpage/Config')
local eventBanner = require('Module:Mainpage/Event')
local eventSplit = require('Module:Mainpage/Event/Legacy')

local p = {}

--- The event card, in whichever design the configured picture calls for.
---
--- Both modules return nil when the settings do not carry what they need, so
--- the fallthrough is the same as it ever was: no event, no card, and the band
--- falls back to the patch card alone.
---
--- @return string|nil
function p.renderEvent()
	return eventBanner.render() or eventSplit.render()
end

--- The current-patch card, for whichever build Config resolves as live.
---
--- @return string|nil
function p.renderPatch()
	local patch = cfg.livePatch()
	if not patch then
		return nil
	end

	-- The highlights belong to the patch rather than to the page, so they sit
	-- on its own entry: writing next month's notes is one object, not a key
	-- somewhere else that has to be remembered.
	local bullets = {}
	for _, item in ipairs(patch.highlights or {}) do
		bullets[#bullets + 1] = '* ' .. item
	end

	return cardLua.renderMediaCard({
		class = 'home-card--aside',
		stretchLink = true,
		content = cardLua.renderMediaBody({
			kicker = 'This patch',
			title = 'New in ' .. patch.name,
			link = patch.page,
			body = bullets[1] and table.concat(bullets, '\n') or nil,
			more = 'Read more',
		}),
	})
end

--- @return string
function p.render()
	local event, patch = p.renderEvent(), p.renderPatch()

	-- No band at all rather than an empty one: the band carries the negative
	-- margin that rides it up over the hero, so an empty one would pull the
	-- rest of the page into the artwork.
	if not event and not patch then
		return ''
	end

	local root = mw.html.create('div'):addClass('home-band'):addClass('home-cards')

	local inner = root:tag('div'):addClass('home-band__inner'):addClass('home-grid')

	inner:wikitext(event)
	inner:wikitext(patch)

	return tostring(root)
end

return p
