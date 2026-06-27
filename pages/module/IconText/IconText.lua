require('strict')

local yesno = require('Module:Yesno')
local Icon = require('Module:Icon')

local p = {}

--- @param args table
--- @return table
local function getProps(args)
	return {
		icon = args.icon,
		iconTitle = args.iconTitle,
		text = args.text or args[1],
		size = args.size or '20px',
		mask = yesno(args.mask),
		class = args.class or '',
	}
end

--- Render the icon text. The icon is delegated to Module:Icon, carrying the
--- `t-icon-text__icon` slot class so existing selectors (e.g. Module:UEC sizing
--- it to 1em) keep working.
---
--- @param args table
--- @return mw.html
local function getIconTextHtml(args)
	local root = mw.html.create('span')

	root:addClass('t-icon-text'):addClass(args.class)

	root:wikitext(Icon.render({
		icon = args.icon,
		size = args.size,
		mask = args.mask,
		title = args.iconTitle,
		class = 't-icon-text__icon',
	}))

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

	local frame = mw.getCurrentFrame()
	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:IconText/styles.css' },
	}) .. frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Icon/styles.css' },
	})

	return styles .. tostring(getIconTextHtml(props))
end

return p
