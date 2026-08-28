require('strict')

--- @module Mainpage/OnThisDay
--- Today's date page, as a two-panel tabber: real-life events and in-lore ones.
---
--- Both panels come from the SAME page — [[August 26]] and so on — which holds
--- them as two `class="timeline"` tables. Module:Transcluder pulls them out by
--- index, so the day pages stay the single source and this card stays a view of
--- them.
---
--- The tabs are doing labelling work, not just saving space: a lore row reads
--- 2773 where a real-life row reads 1991, and nothing about the two tables
--- distinguishes them on sight.
---
--- A day with no lore yet supplies its own "No info yet" row plus an edit
--- invitation, so the empty state belongs to the day page rather than here.
---
--- The foot carries the same invitation for the days that are NOT empty, which
--- is every day the card is worth reading. It goes to the page rather than to
--- one of its two sections, because the foot sits outside the tabber and cannot
--- know which table the reader is looking at.

local transcluder = require('Module:Transcluder')

local p = {}

--- Which table on the day page feeds which tab.
local PANELS = {
	{ label = 'Real life', table = '1' },
	{ label = 'In lore', table = '2' },
}

--- Transcluder's `get` is the module-facing entry point and returns raw
--- wikitext; its template entry point is that plus a `preprocess`, which is
--- what turns the table markup into a table. It raises on a missing page, so
--- the call is guarded — a day page that does not exist yet should cost this
--- card its panel, not the whole render.
---
--- Citations take BOTH options. `references = '0'` only gsubs literal `<ref>`
--- out of the raw wikitext, so a row citing through a template — `{{Cite link}}`
--- carries no `<ref>` until the preprocess below expands one — put a reference
--- list under the main page's foot. `templates = '-^Cite'` takes the family
--- (`-` is a blacklist, the name matched as a Lua pattern), and NOT `'0'`: the
--- lore table's `{{On this day edit message}}` is this card's "No info yet" row.
---
--- Both run before the preprocess because an expanded ref is already registered
--- with the parser; stripping later would leave an orphaned list entry.
---
--- @param page string
--- @param index string
--- @return string
local function panelContent(page, index)
	local ok, text = pcall(transcluder.get, page, {
		only = 'tables',
		tables = index,
		references = '0',
		templates = '-^Cite',
	})
	if not ok or not text then
		return ''
	end
	return mw.getCurrentFrame():preprocess(text)
end

--- @return string
function p.render()
	local lang = mw.language.getContentLanguage()
	local day = lang:formatDate('F j')

	local card = mw.html.create('div'):addClass('t-card'):addClass('home-card--aside')

	-- The frame the scroll fade is painted on. Its scroller is TabberNeue's, so
	-- the selector names it rather than a class of ours.
	local pad = card:tag('div')
		:addClass('home-pad')
		:addClass('home-otd')
		:addClass('home-scrollfade')
		:attr('data-gadget-mainpage-scrollfade', '.tabber__section')

	pad:tag('div'):addClass('home-kicker'):wikitext('On this day &middot; ' .. lang:formatDate('j M'))

	-- TabberNeue takes its panels as one blob of `Label=content` separated by
	-- `|-|`; there is no structured API for it, so it is built as text.
	local panels = {}
	for _, panel in ipairs(PANELS) do
		panels[#panels + 1] = panel.label .. '=' .. panelContent(day, panel.table)
	end

	pad:wikitext(mw.getCurrentFrame():extensionTag({
		name = 'tabber',
		content = table.concat(panels, '\n|-|\n'),
	}))

	-- External-link syntax because an internal link cannot carry a query string,
	-- and `plainlinks` because the target is on this wiki and the arrow icon
	-- would say otherwise. mw.uri.fullUrl and NOT callParserFunction: `fullurl`
	-- is a colon magic word and callParserFunction cannot resolve it.
	pad:tag('div')
		:addClass('home-more')
		:addClass('plainlinks')
		:wikitext(string.format('[[%s|More from this day]]', day))
		:tag('span')
		:addClass('home-more__add')
		:wikitext(string.format('[%s Add an event]', tostring(mw.uri.fullUrl(day, 'action=edit'))))

	return tostring(card)
end

return p
