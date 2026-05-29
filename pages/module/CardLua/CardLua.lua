require('strict')

--- @module CardLua
--- A reusable card primitive: a bordered, surface-coloured, rounded container
--- with a shared header row (title + description on the left, an optional
--- trailing element on the right) and an optional always-visible footer.
---
--- Specialized cards compose this:
---  * Module:CollapsibleCard wraps a <details> body as the card `content` and
---    supplies a chevron as the header trailing element.
---  * `renderLinkCard` is a built-in specialization: a static card whose
---    trailing element is a Module:ButtonLua button (e.g. "view on external
---    source") — for summaries that link out rather than expand in place.

local button = require('Module:ButtonLua')

local p = {}

--- Builds the inner title/description block (no wrapper header row). Exposed so
--- interactive consumers (CollapsibleCard's <summary>) can place it inside their
--- own header element alongside a trailing control.
---
--- @param title string
--- @param description string|nil
--- @return string
function p.renderHeaderContent(title, description)
	local root = mw.html.create('div'):addClass('t-card__header-content')
	root:tag('div'):addClass('t-card__title'):wikitext(title)
	if description and description ~= '' then
		root:tag('div'):addClass('t-card__description'):wikitext(description)
	end
	return tostring(root)
end

--- @class CardHeaderProps
--- @field title string
--- @field description? string
--- @field trailing? string  HTML rendered on the right of the header (button, icon, …)

--- Builds a full static header row: title + description on the left, optional
--- `trailing` element on the right.
---
--- @param props CardHeaderProps
--- @return string
function p.renderHeader(props)
	local root = mw.html.create('div'):addClass('t-card__header')
	root:wikitext(p.renderHeaderContent(props.title, props.description))
	if props.trailing and props.trailing ~= '' then
		root:tag('div'):addClass('t-card__trailing'):wikitext(tostring(props.trailing))
	end
	return tostring(root)
end

--- @class CardProps
--- @field content string|mw.html  Card body.
--- @field footer? string          Always-visible footer (attribution, etc.).
--- @field class? string           Extra class(es) appended to the card root.

--- Wraps `content` (and optional `footer`) in the card shell.
---
--- @param props CardProps
--- @return string
function p.render(props)
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:CardLua/styles.css' },
	})
	local root = mw.html.create('div'):addClass('t-card')
	if props.class and props.class ~= '' then
		root:addClass(props.class)
	end
	root:wikitext(tostring(props.content))
	if props.footer and props.footer ~= '' then
		root:tag('div'):addClass('t-card__footer'):wikitext(tostring(props.footer))
	end
	return styles .. tostring(root)
end

--- @class LinkCardProps
--- @field title string
--- @field description? string
--- @field button ButtonProps  Module:ButtonLua props for the trailing action.
--- @field class? string

--- A static card whose only body is a header row with a link-out button on the
--- right — for summaries backed by an external source rather than on-page data
--- (e.g. "Used in 830 recipes" → browse, "Trade" → SC Trade Tools).
---
--- @param props LinkCardProps
--- @return string
function p.renderLinkCard(props)
	return p.render({
		class = props.class,
		content = p.renderHeader({
			title = props.title,
			description = props.description,
			trailing = button.render(props.button),
		}),
	})
end

return p
