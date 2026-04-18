require('strict')

--- @module CollapsibleCard
--- Reusable card with a "summary line + expandable detail" shape. Renders a
--- <div> wrapping a <details> body and an optional footer sibling so the
--- footer (typically attribution) stays visible when the card is
--- collapsed. Built on Module:Details so the <details>/<summary> markup
--- survives MediaWiki's HTML sanitizer.
---
--- When `content` is nil/empty, the card falls back to a static <div> with
--- no collapse affordance — same visual shell, no expandable body.

local details = require('Module:Details')

local p = {}

--- @class CollapsibleCardProps
--- @field title string        Header title (required).
--- @field description? string Secondary summary text rendered under the title.
--- @field content? string     Body content.
--- @field footer? string      Attribution / metadata line. Always visible.
--- @field open? boolean       Starts expanded when true. Defaults to false.
--- @field collapsible? boolean Render as an expandable <details>. Defaults to true. Falls back to a static card automatically when content is nil/empty.
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
--- @return mw.html
local function buildSummaryHtml(title, description)
	local root = mw.html.create()
	root:node(buildHeaderContentHtml(title, description))
	root:tag('div'):addClass('citizen-ui-icon mw-ui-icon-wikimedia-collapse t-collapsible-card__icon')
	return root
end

--- @param footer string|nil
--- @return mw.html|nil
local function buildFooterHtml(footer)
	if not footer or footer == '' then
		return nil
	end
	return mw.html.create('div'):addClass('t-collapsible-card__footer'):wikitext(tostring(footer))
end

--- @param props CollapsibleCardProps
--- @param rootClass string
--- @return string
local function renderCollapsible(props, rootClass)
	local contentHtml = mw.html.create('div'):addClass('t-collapsible-card__content'):wikitext(tostring(props.content))

	-- Module:Details renders <details>/<summary> as raw wikitext so the
	-- MediaWiki parser produces real elements rather than escaped text.
	-- Splice it back into the outer mw.html tree via :wikitext().
	local detailsWikitext = details.getWikitext({
		details = {
			content = tostring(contentHtml),
			class = 't-collapsible-card__body',
			open = props.open == true,
		},
		summary = {
			content = tostring(buildSummaryHtml(props.title, props.description)),
			class = 't-collapsible-card__header',
		},
	})

	local root = mw.html.create('div'):addClass(rootClass)
	root:wikitext(detailsWikitext)
	local footer = buildFooterHtml(props.footer)
	if footer then
		root:node(footer)
	end
	return tostring(root)
end

--- @param props CollapsibleCardProps
--- @param rootClass string
--- @return string
local function renderStatic(props, rootClass)
	local root = mw.html.create('div'):addClass(rootClass):addClass('t-collapsible-card--static')
	root:tag('div'):addClass('t-collapsible-card__header'):node(buildHeaderContentHtml(props.title, props.description))

	if props.content and tostring(props.content) ~= '' then
		root:tag('div'):addClass('t-collapsible-card__content'):wikitext(tostring(props.content))
	end

	local footer = buildFooterHtml(props.footer)
	if footer then
		root:node(footer)
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
	local isCollapsible = props.collapsible ~= false and hasContent

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
