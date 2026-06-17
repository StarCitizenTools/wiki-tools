require('strict')

local p = {}

--- @param args table
--- @return table
local function getProps(args)
	return {
		icon = args.icon,
		iconTitle = args.iconTitle,
		text = args.text or args[1],
		size = args.size or '20px',
		class = args.class or '',
	}
end

--- @param icon string
--- @param size string
--- @param iconTitle string|nil
--- @return string
local function getIconWikitext(icon, size, iconTitle)
	if iconTitle then
		return string.format('[[File:%s|%s|link=|class=metadata|%s]]', icon, size, iconTitle)
	end

	return string.format('[[File:%s|%s|link=|class=metadata]]', icon, size)
end

--- Render the icon link
---
--- @param args table
--- @return mw.html
local function getIconTextHtml(args)
	local root = mw.html.create('span')

	root:addClass('t-icon-text'):addClass(args.class)

	root:tag('span'):addClass('t-icon-text__icon'):wikitext(getIconWikitext(args.icon, args.size, args.iconTitle))

	root:tag('span'):addClass('t-icon-text__text'):wikitext(args.text)

	return root
end

--- Wikitext entry point for the module
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	return p._main(getArgs(frame))
end

--- Render the icon text
---
--- @param args table
--- @return string
function p._main(args)
	local props = getProps(args)

	if not props.icon then
		error('No icon provided')
	end

	if not props.text then
		error('No text provided')
	end

	return mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:IconText/styles.css' },
	}) .. tostring(getIconTextHtml(props))
end

return p
