require('strict')

--- @module Mainpage/Editing
--- The invitation to edit, backed by the ten most recent changes.
---
--- The list is the argument: the claim, the proof, and the invitation in one
--- card. Usernames are shown for editor recognition, which is what earns this
--- card the wide column rather than a narrow aside.
---
--- The rows are built entirely by the mainpage gadget, from `list=recentchanges`
--- against the API. Without JS the container renders empty and the card falls
--- back to its "See all changes" link.

local buttonLua = require('Module:ButtonLua')

--- Rows to show, published to the gadget as its display cap
--- (`data-gadget-mainpage-activity-limit`). The gadget fetches from a larger
--- pool of its own (`ACTIVITY_POOL`) to survive per-page de-duplication.
local LIMIT = 10

--- The deploying account, published to the gadget rather than hardcoded a
--- second time. `rcshow=!bot` alone doesn't exclude it: that only drops a row
--- whose SAVE carried the flag, and 94 of this account's rows in the API's own
--- pool did not.
local EXCLUDE_USER = 'Alistar Bot'

local p = {}

--- @return string
function p.render()
	local card = mw.html.create('div'):addClass('t-card'):addClass('home-card--tall')

	local pad = card:tag('div'):addClass('home-pad')

	local head = pad:tag('div'):addClass('home-part__head')

	local text = head:tag('div'):addClass('home-part__text')
	text:tag('div'):addClass('home-title'):wikitext('It&rsquo;s your wiki. Write it up.')
	text:tag('div')
		:addClass('home-body')
		:wikitext('No account needed. Fix a typo, correct a stat, or start a whole page.')

	-- A div and not a span: an inline element alone on a line is swallowed into
	-- a paragraph by the parser, and the paragraph then owns the block box
	-- instead of the button.
	head:tag('div'):addClass('home-part__btn'):wikitext(buttonLua.render({
		label = 'Start editing',
		link = 'Star Citizen:Editing',
		size = 'large',
	}))

	-- The caption says what the rows below are and carries a figure beside the
	-- list it describes. `activeUsers` is MediaWiki's own count of accounts with
	-- a logged action in the last 30 days, so the wording says month rather than
	-- week: the number has to be one the software actually keeps.
	local caption = pad:tag('div'):addClass('home-act__cap')
	caption:tag('span'):addClass('home-act__caplabel'):wikitext('Recent changes')
	caption:tag('span'):addClass('home-act__stat'):wikitext(
		string.format(
			'<b>%s</b> editors this month',
			mw.language.getContentLanguage():formatNum(mw.site.stats.activeUsers)
		)
	)

	pad:tag('div')
		:addClass('home-act__list')
		:attr('data-gadget-mainpage-activity', '1')
		:attr('data-gadget-mainpage-activity-limit', tostring(LIMIT))
		:attr('data-gadget-mainpage-activity-namespace', '0')
		:attr('data-gadget-mainpage-activity-exclude', EXCLUDE_USER)

	pad:tag('div'):addClass('home-more'):wikitext('[[Special:RecentChanges|See all changes]]')

	return tostring(card)
end

return p
