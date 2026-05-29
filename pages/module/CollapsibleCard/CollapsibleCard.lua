require('strict')

--- @module CollapsibleCard
--- A card with a "summary line + expandable detail" shape: composes the
--- Module:CardLua shell + shared header, and adds the collapse mechanics — a
--- <details> body (via Module:Details so the markup survives the sanitizer)
--- with a chevron trailing the header. The footer is a CardLua footer sibling
--- so it stays visible when collapsed.
---
--- When `content` is nil/empty, falls back to a plain static CardLua card (no
--- collapse affordance) — same visual shell, no expandable body.

local details = require('Module:Details')
local card = require('Module:CardLua')

local p = {}

--- @class CollapsibleCardProps
--- @field title string        Header title (required).
--- @field description? string Secondary summary text rendered under the title.
--- @field content? string     Body content.
--- @field footer? string      Attribution / metadata line. Always visible.
--- @field open? boolean       Starts expanded when true. Defaults to false.
--- @field collapsible? boolean Render as an expandable <details>. Defaults to true. Falls back to a static card automatically when content is nil/empty.
--- @field class? string       Extra class appended to the card root.

--- The chevron shown at the right of a collapsible header. `t-card__trailing`
--- right-aligns it; `t-collapsible-card__icon` owns the rotate-on-open
--- transition (see styles.css).
---
--- @return string
local function chevronHtml()
	return tostring(
		mw.html
			.create('div')
			:addClass('citizen-ui-icon mw-ui-icon-wikimedia-collapse t-card__trailing t-collapsible-card__icon')
	)
end

--- @param props CollapsibleCardProps
--- @param rootClass string
--- @return string
local function renderCollapsible(props, rootClass)
	local body = mw.html.create('div'):addClass('t-card__content'):wikitext(tostring(props.content))

	-- Module:Details renders <details>/<summary> as raw wikitext so the
	-- MediaWiki parser produces real elements rather than escaped text.
	local detailsWikitext = details.getWikitext({
		details = {
			content = tostring(body),
			class = 't-collapsible-card__body',
			open = props.open == true,
		},
		summary = {
			content = card.renderHeaderContent(props.title, props.description) .. chevronHtml(),
			class = 't-card__header t-collapsible-card__header',
		},
	})

	return card.render({ content = detailsWikitext, footer = props.footer, class = rootClass })
end

--- @param props CollapsibleCardProps
--- @param rootClass string
--- @return string
local function renderStatic(props, rootClass)
	local content = card.renderHeader({ title = props.title, description = props.description })
	if props.content and tostring(props.content) ~= '' then
		content = content
			.. tostring(mw.html.create('div'):addClass('t-card__content'):wikitext(tostring(props.content)))
	end
	return card.render({ content = content, footer = props.footer, class = rootClass })
end

--- @param props CollapsibleCardProps
--- @return string
function p.render(props)
	local rootClass = 't-collapsible-card'
	if props.class and props.class ~= '' then
		rootClass = rootClass .. ' ' .. props.class
	end

	local hasContent = props.content ~= nil and tostring(props.content) ~= ''
	local isCollapsible = props.collapsible ~= false and hasContent

	-- CardLua.render injects the shell styles; this component must also inject
	-- its own collapse-specific styles (interactive header hover, chevron size +
	-- rotate-on-open), which CardLua doesn't know about.
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:CollapsibleCard/styles.css' },
	})

	if isCollapsible then
		return styles .. renderCollapsible(props, rootClass)
	end
	return styles .. renderStatic(props, rootClass)
end

return p
