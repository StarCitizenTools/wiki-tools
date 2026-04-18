require('strict')

--- @module CollapsibleCard
--- Reusable card with a "summary line + expandable detail" shape. Renders a
--- <details> block where the summary row holds a title and optional
--- description, and the body holds arbitrary content. Built on Module:Details
--- so the <details>/<summary> markup survives MediaWiki's HTML sanitizer.
---
--- When `content` is nil/empty, the card falls back to a static <div> with
--- no collapse affordance — useful for "no data" states that still want the
--- same visual shell and attribution footer.

local details = require('Module:Details')

local p = {}

--- @class CollapsibleCardProps
--- @field title string        Header title (required).
--- @field description? string Secondary summary text rendered under the title.
--- @field content? string     Body content. Omit/empty to render a static card.
--- @field footer? string      Attribution / metadata line at the bottom.
--- @field open? boolean       Starts expanded when true. Defaults to false.
--- @field class? string       Extra class appended to the card root.

--- @param title string
--- @param description string|nil
--- @return mw.html
local function buildHeaderContentHtml(title, description)
	local root = mw.html.create('div'):addClass('t-collapsible-card__header-content')
	root:tag('div'):addClass('t-collapsible-card__title'):wikitext(title)
	if description and description ~= '' then
		root:tag('div'):addClass('t-collapsible-card__description'):wikitext(description)
	end
	return root
end

--- @param title string
--- @param description string|nil
--- @return string
local function buildSummaryHtml(title, description)
	local root = mw.html.create()
	root:node(buildHeaderContentHtml(title, description))
	root:tag('div'):addClass('citizen-ui-icon mw-ui-icon-wikimedia-collapse t-collapsible-card__icon')
	return tostring(root)
end

--- @param props CollapsibleCardProps
--- @return string
local function renderCollapsible(props, rootClass)
	local bodyHtml = '<div class="t-collapsible-card__content">' .. tostring(props.content) .. '</div>'
	if props.footer and props.footer ~= '' then
		bodyHtml = bodyHtml .. '<div class="t-collapsible-card__footer">' .. tostring(props.footer) .. '</div>'
	end

	return details.getWikitext({
		details = {
			content = bodyHtml,
			class = rootClass,
			open = props.open == true,
		},
		summary = {
			content = buildSummaryHtml(props.title, props.description),
			class = 't-collapsible-card__header',
		},
	})
end

--- @param props CollapsibleCardProps
--- @return string
local function renderStatic(props, rootClass)
	local root = mw.html.create('div'):addClass(rootClass):addClass('t-collapsible-card--static')
	local header = root:tag('div'):addClass('t-collapsible-card__header')
	header:node(buildHeaderContentHtml(props.title, props.description))

	if props.footer and props.footer ~= '' then
		root:tag('div'):addClass('t-collapsible-card__footer'):wikitext(tostring(props.footer))
	end

	return tostring(root)
end

--- @param props CollapsibleCardProps
--- @return string
function p.render(props)
	local rootClass = 't-collapsible-card'
	if props.class and props.class ~= '' then
		rootClass = rootClass .. ' ' .. props.class
	end

	local hasContent = props.content ~= nil and tostring(props.content) ~= ''

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:CollapsibleCard/styles.css' },
	})

	if hasContent then
		return styles .. renderCollapsible(props, rootClass)
	end
	return styles .. renderStatic(props, rootClass)
end

return p
