require('strict')

--- Lua interface for building a badge.

--- @class BadgeProps
--- @field text string
--- @field variant 'error'|'success'|'warning'
--- @field color string
--- @field backgroundColor string
--- @field icon string
--- @field class string

local VARIANTS = {
	error = true,
	success = true,
	warning = true,
}

local p = {}

--- @param file string
--- @param size string
--- @return string
local function getFileWikitext(file, size)
	-- `metadata` class is needed to be excluded from MultimediaViewer.
	-- `link=` is needed make sure the image is not clickable.
	return string.format('[[File:%s|%s|class=metadata|link=]]', file, size)
end

--- @param root mw.html
--- @param icon string
local function renderIcon(root, icon)
	local html = mw.html.create('span')

	html:addClass('t-badge__icon'):wikitext(getFileWikitext(icon, '16px'))

	root:node(html)
end

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
		renderIcon(root, props.icon)
	end

	root:tag('span'):addClass('t-badge__text'):wikitext(props.text)

	return mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:BadgeLua/styles.css' },
	}) .. tostring(root)
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

	return p.render(args)
end

return p
