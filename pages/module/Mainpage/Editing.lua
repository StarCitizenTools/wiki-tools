require('strict')

--- @module Mainpage/Editing
--- The invitation to edit, backed by the ten most recent changes.
---
--- The list is the argument: the claim, the proof, and the invitation in one
--- card. Usernames are shown for editor recognition, which is what earns this
--- card the wide column rather than a narrow aside.
---
--- DPL is a parser function with no Lua interface, so its call is built as
--- wikitext and preprocessed. Two of its parameters are unforgiving:
---  * `userdateformat` is lowercased before use, so only lowercase format
---    letters survive — `c` (ISO 8601) is the one that does what is wanted here.
---  * `listseparators` needs a literal `\n` before the row markup, or the row's
---    opening `<div>` runs onto the end of the previous line.
---
--- DPL also forces a one-hour parser cache on any page that calls it. That is
--- why these rows are FIRST PAINT and the no-JS reading, and never the
--- freshness mechanism: the gadget polls the API and keeps the list live for as
--- long as the reader is on the page.

local buttonLua = require('Module:ButtonLua')

local ROW = '<div class="home-act__row">[[%PAGE%]]'
	.. '<span class="home-act__by">%USER%</span>'
	.. '<time class="home-act__when" datetime="%DATE%">%DATE%</time></div>'

local LIMIT = 10

--- The deploying account. Its syncs are not what a reader means by recent
--- activity, so both halves of this card have to drop them — and they filter by
--- different mechanisms, so the NAME is published to the gadget rather than
--- written down twice.
---
--- They cannot share a mechanism. DPL takes a username; the API takes
--- `rcshow=!bot`, which sounds equivalent and is not: a bot edit is only
--- excluded if the SAVE carried the bot flag, and 94 of this account's
--- main-namespace rows currently in the API's own pool did not. Filtering the
--- gadget by the flag alone would let a sync run walk onto the front page, one
--- row a minute, that the server-rendered list had correctly hidden.
local EXCLUDE_USER = 'Alistar Bot'

local p = {}

--- @return string
local function recentChanges()
	local args = {
		'namespace=',
		'ordermethod=lastedit',
		'order=descending',
		'notlastmodifiedby=' .. EXCLUDE_USER,
		'count=' .. LIMIT,
		'addeditdate=true',
		'adduser=true',
		'userdateformat=c',
		'mode=userformat',
		'listseparators=,\\n' .. ROW .. ',,',
	}

	return mw.getCurrentFrame():preprocess('{{#dpl:\n|' .. table.concat(args, '\n|') .. '\n}}')
end

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
		:wikitext(recentChanges())

	pad:tag('div'):addClass('home-more'):wikitext('[[Special:RecentChanges|See all changes]]')

	return tostring(card)
end

return p
