require('strict')

--- Lua interface for building a button.
--- This module uses Codex Button directly because the styles are already loaded in Citizen.

--- @class ButtonProps
--- @field label string
--- @field link string
--- @field url string
--- @field action ButtonAction
--- @field weight ButtonWeight
--- @field size ButtonSize
--- @field disabled boolean @default false
--- @field icon string
--- @field iconOnly boolean @default false
--- @field class string @default nil

--- @alias ButtonAction 'default' | 'progressive' | 'destructive' @default 'default'
--- @alias ButtonWeight 'normal' | 'primary' @default 'normal'
--- @alias ButtonSize 'small' | 'medium' | 'large' @default 'medium'

local p = {}

--- @param props ButtonProps
local function normalizeProps(props)
	props.action = props.action or 'default'
	props.weight = props.weight or 'normal'
	props.size = props.size or 'medium'
	props.iconOnly = props.iconOnly or false
end

--- Get the icon src for the button
---
--- @param icon string
--- @return string
local function getIconSrc(icon)
	return mw.getCurrentFrame():callParserFunction('filepath', {
		icon,
		'nowiki',
	})
end

--- @param props ButtonProps
--- @return string
local function getButtonWikitext(props)
	local html = mw.html.create('span')
	local isIconOnly = props.iconOnly and props.icon

	html:addClass('t-button')
		:addClass('cdx-button')
		:addClass('cdx-button--fake-button')
		:addClass('cdx-button--fake-button' .. (props.disabled and '--disabled' or '--enabled'))
		:addClass('cdx-button--action-' .. props.action)
		:addClass('cdx-button--weight-' .. props.weight)
		:addClass('cdx-button--size-' .. props.size)
		:addClass(props.class)

	-- HACK: Since MW does not allow <img> within <a> tags,
	-- we inject the icon as a background image instead.
	if props.icon then
		-- CdxButton only supports small and medium icons, so we need to map the size
		local iconSize = props.size == 'small' and 'small' or 'medium'

		html:tag('span')
			:addClass('cdx-icon')
			:addClass('cdx-icon--' .. iconSize)
			:cssText('--t-button-icon-url: "' .. getIconSrc(props.icon) .. '";')
			:done()
	end

	if not isIconOnly then
		html:wikitext(props.label)
	else
		html:attr('aria-label', props.label)
		html:addClass('cdx-button--icon-only')
	end

	return tostring(html)
end

--- @param props ButtonProps
--- @return string
function p.render(props)
	normalizeProps(props)

	if not props.link and not props.url then
		error('No link or URL provided')
	end

	local root = mw.html.create('span')

	root:addClass('t-button'):addClass('plainlinks') -- Remove external link icon

	local buttonWikitext = getButtonWikitext(props)

	if props.link then
		root:wikitext(string.format('[[%s|%s]]', props.link, buttonWikitext))
	end

	if props.url then
		root:wikitext(string.format('[%s %s]', props.url, buttonWikitext))
	end

	return mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:ButtonLua/styles.css' },
	}) .. tostring(root)
end

--- Wikitext entry point for the module
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	return p.render(getArgs(frame))
end

return p
