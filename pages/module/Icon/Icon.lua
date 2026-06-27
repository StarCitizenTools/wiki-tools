require('strict')

--- @module Icon
--- Renders a single inline icon, either as a rasterised [[File:]] thumbnail or as
--- a CSS mask filled with currentColor (so it recolours with the surrounding
--- text). Optionally linked. The shared icon primitive behind Module:IconText,
--- Module:IconLink, and Module:BadgeLua.
---
--- `render` returns markup ONLY — no <templatestyles>. Callers load
--- Module:Icon/styles.css themselves, so the style tag never ends up inside a
--- wikilink label when a caller wraps the icon in a link of its own (e.g.
--- BadgeLua's whole-pill link). The wikitext entry point `main` does emit the
--- stylesheet, since it returns a standalone value.

local yesno = require('Module:Yesno')

local p = {}

local DEFAULT_SIZE = '20px'

--- @class IconProps
--- @field icon string         File name (without the File: prefix)
--- @field size? string        CSS length; default '20px'
--- @field mask? boolean       Render as a currentColor mask instead of a thumbnail
--- @field link? string        Link target; nil/empty = unlinked
--- @field title? string       Tooltip / caption
--- @field class? string       Extra class(es) on the icon element

--- Resolve the icon's file URL for use as a CSS mask image.
--- @param icon string
--- @return string
local function getIconSrc(icon)
	return mw.getCurrentFrame():callParserFunction('filepath', { icon, 'nowiki' })
end

--- Public: resolve an icon file name to its URL (for callers that paint their own
--- mask client-side, e.g. an AG Grid badge cell). Decoded to a plain URL — the
--- `nowiki` filepath HTML-encodes `:` as `&#58;`, which a browser decodes inside an
--- HTML style attribute (the server-rendered mask) but NOT when a script assigns it
--- to a CSS custom property, so client-side callers need the real characters.
--- @param icon string
--- @return string
function p.src(icon)
	return mw.text.decode(getIconSrc(icon), true)
end

--- Space-joined class list for the icon element: the base `t-icon`, the `--mask`
--- modifier when masked, then any caller class (its existing slot class, e.g.
--- `t-icon-text__icon`, so consumer selectors keep working).
--- @param mask boolean
--- @param extra string|nil
--- @return string
local function iconClass(mask, extra)
	local classes = { 't-icon' }
	if mask then
		classes[#classes + 1] = 't-icon--mask'
	end
	if extra and extra ~= '' then
		classes[#classes + 1] = extra
	end
	return table.concat(classes, ' ')
end

--- Render as a recolourable CSS mask span, optionally wrapped in a link.
--- @param props IconProps
--- @return string
local function renderMask(props)
	local span = mw.html.create('span'):addClass(iconClass(true, props.class)):cssText(
		string.format('--t-icon-url: "%s"; width: %s; height: %s;', getIconSrc(props.icon), props.size, props.size)
	)
	if props.title then
		span:attr('title', props.title)
	end
	local markup = tostring(span)
	if props.link and props.link ~= '' then
		return string.format('[[%s|%s]]', props.link, markup)
	end
	return markup
end

--- Render as a [[File:]] thumbnail. `link=` (empty) suppresses the file link
--- unless a target is given; `metadata` keeps it out of the MultimediaViewer.
--- @param props IconProps
--- @return string
local function renderThumb(props)
	local parts = {
		'File:' .. props.icon,
		props.size,
		'link=' .. (props.link or ''),
		'class=metadata ' .. iconClass(false, props.class),
	}
	if props.title then
		parts[#parts + 1] = props.title
	end
	return '[[' .. table.concat(parts, '|') .. ']]'
end

--- Render an icon. Returns markup only (no templatestyles).
--- @param props IconProps
--- @return string
function p.render(props)
	if not props.icon or props.icon == '' then
		error('Module:Icon: no icon provided')
	end
	local resolved = {
		icon = props.icon,
		size = props.size or DEFAULT_SIZE,
		mask = props.mask and true or false,
		link = props.link,
		title = props.title,
		class = props.class,
	}
	if resolved.mask then
		return renderMask(resolved)
	end
	return renderThumb(resolved)
end

--- Wikitext entry point. Unlike `render`, this emits the stylesheet.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Icon/styles.css' },
	})
	return styles
		.. p.render({
			icon = args.icon or args[1],
			size = args.size,
			mask = yesno(args.mask),
			link = args.link,
			title = args.title or args.iconTitle,
			class = args.class,
		})
end

return p
