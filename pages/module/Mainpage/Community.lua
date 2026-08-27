require('strict')

--- @module Mainpage/Community
--- The two asks: funding and Discord.
---
--- Two cards rather than one with a rule through it. Split, each sizes to its
--- own content instead of one stretching to fill the other's height.
---
--- Three tiers of link, and the tiers are the argument. Patreon and Ko-fi share
--- a row because they are one favour offered two ways, so neither is primary.
--- Discord takes a full-width button because it is the channel people join
--- rather than follow. The rest are follows, so they are icon-only quiet
--- buttons — which also keeps X and Threads from arriving as two
--- indistinguishable brand-black squares in a dark theme.
---
--- Brand colours are NOT set here. Each service is declared as a
--- `t-button--branded` brand in Module:ButtonLua/styles.css, so anything else
--- on the wiki linking the same service gets the same button.

local buttonLua = require('Module:ButtonLua')

local p = {}

local FUNDING = {
	{
		label = 'Patreon',
		url = 'https://www.patreon.com/starcitizentools',
		icon = 'Patreon - Simple Icons.svg',
		brand = 't-button--patreon',
	},
	{
		label = 'Ko-fi',
		url = 'https://ko-fi.com/starcitizentools',
		icon = 'Kofi - Simple Icons.svg',
		brand = 't-button--kofi',
	},
}

local FOLLOW = {
	{ label = 'Twitter', url = 'https://x.com/ToolsWiki', icon = 'Twitter - Simple Icons.svg' },
	{ label = 'Mastodon', url = 'https://mastodon.social/@ToolsWiki', icon = 'Mastodon - Simple Icons.svg' },
	{ label = 'Threads', url = 'https://www.threads.net/@sctoolswiki', icon = 'Threads - Simple Icons.svg' },
	{ label = 'Bluesky', url = 'https://bsky.app/profile/starcitizen.tools', icon = 'Bluesky - Simple Icons.svg' },
}

--- @param link table
--- @return string
local function brandButton(link)
	return buttonLua.render({
		label = link.label,
		url = link.url,
		icon = link.icon,
		size = 'large',
		class = 't-button--branded ' .. link.brand,
	})
end

--- The funding card.
--- @return string
function p.renderSupport()
	local card = mw.html.create('div'):addClass('t-card'):addClass('home-card--aside')

	local box = card:tag('div'):addClass('home-give')

	box:tag('div'):addClass('home-kicker'):wikitext('Independent &middot; Ad-free')
	box:tag('div'):addClass('home-title'):wikitext('Keep the wiki running')
	box:tag('div'):addClass('home-body'):wikitext('The wiki is entirely funded by the community.')

	local row = box:tag('div'):addClass('home-btns')
	for _, link in ipairs(FUNDING) do
		row:wikitext(brandButton(link))
	end

	return tostring(card)
end

--- The Discord and follow card.
--- @return string
function p.renderDiscussion()
	local card = mw.html.create('div'):addClass('t-card'):addClass('home-card--aside')

	local box = card:tag('div'):addClass('home-talk')

	box:tag('div'):addClass('home-title'):wikitext('Join the discussion')
	box:tag('div')
		:addClass('home-body')
		:wikitext("Most of the wiki's discussion happens on Discord. Come say hi, ask questions, or just lurk.")

	box:tag('div'):addClass('home-btn--wide'):wikitext(brandButton({
		label = 'Discord',
		url = 'https://discord.gg/XcKwqyD4sc',
		icon = 'Discord - Simple Icons.svg',
		brand = 't-button--discord',
	}))

	box:tag('div'):addClass('home-kicker'):addClass('home-kicker--inset'):wikitext('Follow')

	local icons = box:tag('div'):addClass('home-icons')
	for _, link in ipairs(FOLLOW) do
		icons:wikitext(buttonLua.render({
			label = link.label,
			url = link.url,
			icon = link.icon,
			iconOnly = true,
		}))
	end

	return tostring(card)
end

return p
