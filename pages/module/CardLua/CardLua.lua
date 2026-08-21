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
---  * `renderMediaCard` is a built-in specialization for cards that lead with a
---    picture: art, an overline, a title, prose, and an optional readout row.
---    The art bleeds to the card's inner edge without any negative margins,
---    because `.t-card` carries no padding of its own — each section supplies
---    its own — and the shell's `overflow: clip` trims the picture to the
---    inside of the border and radius.

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
--- @field buttons ButtonProps[]  One or more Module:ButtonLua props; rendered as trailing link-out actions.
--- @field class? string

--- A static card whose body is a header row with one or more link-out buttons
--- on the right — for summaries backed by external sources rather than on-page
--- data (e.g. "Browse 830 recipes" → Wiki API; "Browse trade data" → SC Trade
--- Tools + UEX).
---
--- @param props LinkCardProps
--- @return string
function p.renderLinkCard(props)
	local rendered = {}
	for _, b in ipairs(props.buttons or {}) do
		rendered[#rendered + 1] = button.render(b)
	end
	return p.render({
		class = props.class,
		content = p.renderHeader({
			title = props.title,
			description = props.description,
			trailing = table.concat(rendered),
		}),
	})
end

--- @class MediaCardReadout
--- @field label? string  Left-hand label, e.g. "Ends in".
--- @field value? string  Right-hand value: a count, a countdown, a price…
--- @field attrs? table<string, string>  Attributes set on the value element, for
---        gadgets that animate or refresh it (e.g. a countdown target date).

--- @class MediaCardProps
--- @field title string        Card title. Required.
--- @field link? string        Page the title links to.
--- @field image? string       File name for the leading art; a "File:" prefix is optional.
--- @field imageAlt? string    Alt text. Defaults to empty, which is correct for
---        decorative art sitting next to a title that already names the subject.
--- @field imageWidth? number  Width the file is RENDERED at, in px, not the size
---        of the slot — the art is cropped to fill, so this only needs to be
---        large enough to stay sharp. Defaults to 480.
--- @field layout? string      'split' (art beside the text, the default) or
---        'banner' (art across the top). Split stays short; banner is taller for
---        the same content, which matters when the card sits above the fold.
--- @field kicker? string      Overline above the title.
--- @field body? string        Prose. A longer register than the header row's
---        one-line `description`.
--- @field stretchLink? boolean  Make the whole card clickable, not just the
---        title. Requires `link`. Off by default, because a card that swallows
---        every click also swallows text selection over its body.
--- @field readout? MediaCardReadout
--- @field footer? string      Card footer, below a divider.
--- @field class? string

--- Wikitext for the leading art. `link=` is deliberately empty: the title
--- carries the link, and a second target over the picture gives keyboard and
--- screen-reader users a duplicate stop for the same destination.
---
--- @param props MediaCardProps
--- @return string
local function mediaWikitext(props)
	local name = mw.text.trim(props.image)
	name = name:gsub('^[Ff][Ii][Ll][Ee]:', ''):gsub('^[Ii][Mm][Aa][Gg][Ee]:', '')
	return string.format('[[File:%s|%dpx|link=|alt=%s]]', name, tonumber(props.imageWidth) or 480, props.imageAlt or '')
end

--- @param props MediaCardProps
--- @return string
local function readoutHtml(props)
	local readout = props.readout
	local row = mw.html.create('div'):addClass('t-card__readout')
	row:tag('span'):addClass('t-card__readout-label'):wikitext(readout.label or '')
	local value = row:tag('span'):addClass('t-card__readout-value')
	for name, content in pairs(readout.attrs or {}) do
		value:attr(name, content)
	end
	value:wikitext(readout.value or '')
	return tostring(row)
end

--- A card that leads with a picture: art, overline, title, prose, and an
--- optional readout row pinned to the foot.
---
--- The readout is bottom-anchored on purpose. Cards laid out in a row are
--- stretched to the tallest of them, and this decides where that spare height
--- lands: as a gap above the readout, which reads as deliberate, rather than as
--- a hole below everything, which reads as a mistake.
---
--- @param props MediaCardProps
--- @return string
function p.renderMediaCard(props)
	if not props.title or props.title == '' then
		error('renderMediaCard: title is required')
	end

	local layout = props.layout == 'banner' and 'banner' or 'split'
	local root = mw.html.create('div'):addClass('t-card__media-layout'):addClass('t-card__media-layout--' .. layout)
	local linked = props.link and props.link ~= ''
	local stretch = linked and props.stretchLink == true

	if props.image and props.image ~= '' then
		root:tag('div'):addClass('t-card__media'):wikitext(mediaWikitext(props))
	end

	local body = root:tag('div'):addClass('t-card__media-body')

	if props.kicker and props.kicker ~= '' then
		body:tag('div'):addClass('t-card__kicker'):wikitext(props.kicker)
	end

	local title = linked and string.format('[[%s|%s]]', props.link, props.title) or props.title
	body:tag('div'):addClass('t-card__title'):wikitext(title)

	if props.body and props.body ~= '' then
		body:tag('div'):addClass('t-card__body'):wikitext(props.body)
	end

	if props.readout and (props.readout.label or props.readout.value) then
		body:wikitext(readoutHtml(props))
	end

	-- The stretch is a class on the card, not an extra element: the title's own
	-- anchor is grown to cover the card by CSS. A separate overlay anchor would
	-- either have no accessible name, or repeat the title and hand keyboard and
	-- screen-reader users a second stop for the same destination.
	local class = props.class
	if stretch then
		class = class and (class .. ' t-card--link') or 't-card--link'
	end

	return p.render({
		content = tostring(root),
		footer = props.footer,
		class = class,
	})
end

--- Wikitext entry point for the media card.
---
--- Readout attributes are Lua-only: they exist for gadget hooks, which belong to
--- a module that knows what it is hooking, not to a template parameter.
---
--- @param frame mw.frame
--- @return string
function p.mediaCard(frame)
	local args = require('Module:Arguments').getArgs(frame)
	local yesno = require('Module:Yesno')
	return p.renderMediaCard({
		title = args.title,
		link = args.link,
		stretchLink = yesno(args.stretchlink, false) == true,
		image = args.image,
		imageAlt = args.imagealt,
		imageWidth = args.imagewidth,
		layout = args.layout,
		kicker = args.kicker,
		body = args.body,
		readout = { label = args.readoutlabel, value = args.readout },
		footer = args.footer,
		class = args.class,
	})
end

return p
