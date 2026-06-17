require('strict')

local p = {}

--- @param args table
--- @return table
local function getProps(args)
	return {
		icon = args.icon,
		link = args.link or args[1],
		text = args.text or args.link or args[1],
		size = args.size or '20px',
		class = args.class or '',
	}
end

--- @param icon string
--- @param link string
--- @param size string
--- @return string
local function getIconWikitext(icon, link, size)
	return string.format('[[File:%s|%s|link=%s|class=metadata]]', icon, size, link)
end

--- Render the icon link
---
--- @param args table
--- @return mw.html
local function getIconLinkHtml(args)
	local root = mw.html.create('span')

	root:addClass('t-icon-link'):addClass(args.class)

	root:tag('span'):addClass('t-icon-link__icon'):wikitext(getIconWikitext(args.icon, args.link, args.size))

	root:tag('span'):addClass('t-icon-link__text'):wikitext(string.format('[[%s|%s]]', args.link, args.text))

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

--- Render the icon link
---
--- @param args table
--- @return string
function p._main(args)
	local props = getProps(args)

	if not props.icon then
		error('No icon provided')
	end

	if not props.link or not props.text then
		error('No link or text provided')
	end

	return mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:IconLink/styles.css' },
	}) .. tostring(getIconLinkHtml(props))
end

return p
