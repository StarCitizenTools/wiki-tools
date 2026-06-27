require('strict')

local yesno = require('Module:Yesno')
local Icon = require('Module:Icon')

local p = {}

--- @param args table
--- @return table
local function getProps(args)
	return {
		icon = args.icon,
		link = args.link or args[1],
		text = args.text or args.link or args[1],
		size = args.size or '20px',
		mask = yesno(args.mask),
		class = args.class or '',
	}
end

--- Render the icon link: a linked icon (delegated to Module:Icon, carrying the
--- `t-icon-link__icon` slot class) followed by the linked text.
---
--- @param args table
--- @return mw.html
local function getIconLinkHtml(args)
	local root = mw.html.create('span')

	root:addClass('t-icon-link'):addClass(args.class)

	root:wikitext(Icon.render({
		icon = args.icon,
		size = args.size,
		mask = args.mask,
		link = args.link,
		class = 't-icon-link__icon',
	}))

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

	local frame = mw.getCurrentFrame()
	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:IconLink/styles.css' },
	}) .. frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Icon/styles.css' },
	})

	return styles .. tostring(getIconLinkHtml(props))
end

return p
