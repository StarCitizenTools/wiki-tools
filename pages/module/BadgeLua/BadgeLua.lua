require('strict')

--- Lua interface for building a badge.

local Icon = require('Module:Icon')

--- @class BadgeProps
--- @field text string
--- @field variant 'error'|'success'|'warning'
--- @field color string
--- @field backgroundColor string
--- @field icon string
--- @field mask boolean             Render the icon as a currentColor mask (matches the badge colour)
--- @field link string             Wrap the whole badge in a link to this page
--- @field class string

local VARIANTS = {
	error = true,
	success = true,
	warning = true,
}

local p = {}

--- @param props BadgeProps
--- @return string
function p.render(props)
	local root = mw.html.create('span'):addClass('t-badge')

	if type(props.variant) == 'string' and VARIANTS[props.variant] then
		root:addClass('t-badge--' .. props.variant)
	end

	if type(props.class) == 'string' then
		root:addClass(props.class)
	end

	if type(props.color) == 'string' then
		root:css('color', props.color)
	end

	if type(props.backgroundColor) == 'string' then
		root:css('background-color', props.backgroundColor)
	end

	if type(props.icon) == 'string' then
		root:wikitext(Icon.render({
			icon = props.icon,
			size = '16px',
			mask = props.mask,
			class = 't-badge__icon',
		}))
	end

	root:tag('span'):addClass('t-badge__text'):wikitext(props.text)

	local frame = mw.getCurrentFrame()
	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:BadgeLua/styles.css' },
	})
	-- Icon ships its own stylesheet; only needed when the badge has an icon.
	if type(props.icon) == 'string' then
		styles = styles
			.. frame:extensionTag({
				name = 'templatestyles',
				args = { src = 'Module:Icon/styles.css' },
			})
	end

	local badge = tostring(root)
	-- Wrap the whole pill in one anchor so the entire badge is the link, not just
	-- its text. The templatestyles tags stay outside the link label.
	if type(props.link) == 'string' and props.link ~= '' then
		badge = string.format('[[%s|%s]]', props.link, badge)
	end

	return styles .. badge
end

--- Wikitext entry point for the module
---
--- Accepts shorthand argument names for the most common props:
--- - first positional argument is the badge text
--- - `bg` is an alias for `backgroundColor`
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)

	if args.text == nil then
		args.text = args[1]
	end

	if args.backgroundColor == nil then
		args.backgroundColor = args.bg
	end

	if args.mask ~= nil then
		args.mask = require('Module:Yesno')(args.mask)
	end

	return p.render(args)
end

return p
