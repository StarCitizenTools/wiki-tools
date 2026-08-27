require('strict')

--- @module Mainpage/Directory
--- The grouped text directory at the foot of the page.
---
--- Text links and not tiles: image pills at this size cost about two screens on
--- a phone before any content appears, so anything that reintroduces artwork
--- here undoes the decision that retired them.
---
--- The band carries no card of its own, so its columns land on the same grid
--- lines as the cards above it. How many columns there are is not decided here
--- or anywhere else in Lua: `.home-dir` is `repeat(auto-fit, minmax(125px, 1fr))`,
--- so the groups reflow on their own and the module just emits all of them.

local nav = require('Module:Mainpage/Nav')

local p = {}

--- @return string
function p.render()
	local root = mw.html.create('div'):addClass('home-band'):addClass('home-wiki')

	local inner = root:tag('div'):addClass('home-band__inner'):addClass('home-dir')

	for _, group in ipairs(nav.directory()) do
		local links = group.links or {}

		local box = inner:tag('div'):addClass('home-dir__group')
		-- plainlinks only where it has something to suppress; see Nav.hasExternal.
		if nav.hasExternal(links) then
			box:addClass('plainlinks')
		end

		-- A div with role="heading", never an <h3>: a heading element here would
		-- join the article's outline and put six entries in the table of
		-- contents for what is a navigation block.
		box:tag('div')
			:addClass('home-dir__label')
			:attr('role', 'heading')
			:attr('aria-level', '2')
			:wikitext(group.label or '')

		-- A real list, because that is what a directory is: it gives a screen
		-- reader the count before the links and lets it be skipped in one move.
		-- The marker and indent are removed in CSS, not by flattening the list.
		local list = box:tag('ul')
		for _, link in ipairs(links) do
			local wikitext = nav.renderLink(link)
			if wikitext then
				list:tag('li'):wikitext(wikitext)
			end
		end
	end

	return tostring(root)
end

return p
