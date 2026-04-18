require('strict')

--- @module CollapsibleCard
--- Reusable card with a "summary line + expandable detail" shape. Renders a
--- <details> block where the summary row holds a title and optional
--- description, and the body holds arbitrary content. Built on Module:Details
--- so the <details>/<summary> markup survives MediaWiki's HTML sanitizer.

local details = require('Module:Details')

local p = {}

--- @class CollapsibleCardProps
--- @field title string        Header title (required).
--- @field description? string Secondary summary text rendered under the title.
--- @field content string      Body content (HTML/wikitext string, required).
--- @field open? boolean       Starts expanded when true. Defaults to false.
--- @field class? string       Extra class appended to the <details> root.

--- @param title string
--- @param description string|nil
--- @return string
local function buildSummaryHtml(title, description)
	local root = mw.html.create()

	local headerContent = root:tag('div'):addClass('t-collapsible-card__header-content')
	headerContent:tag('div'):addClass('t-collapsible-card__title'):wikitext(title)
	if description and description ~= '' then
		headerContent:tag('div'):addClass('t-collapsible-card__description'):wikitext(description)
	end

	root:tag('div'):addClass('citizen-ui-icon mw-ui-icon-wikimedia-collapse t-collapsible-card__icon')

	return tostring(root)
end

--- @param props CollapsibleCardProps
--- @return string
function p.render(props)
	local rootClass = 't-collapsible-card'
	if props.class and props.class ~= '' then
		rootClass = rootClass .. ' ' .. props.class
	end

	local wikitext = details.getWikitext({
		details = {
			content = '<div class="t-collapsible-card__content">' .. tostring(props.content) .. '</div>',
			class = rootClass,
			open = props.open == true,
		},
		summary = {
			content = buildSummaryHtml(props.title, props.description),
			class = 't-collapsible-card__header',
		},
	})

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:CollapsibleCard/styles.css' },
	})

	return styles .. wikitext
end

return p
