require('strict')

--- @module Mbox
--- The box behind page notices, hatnotes and Entity empty states: a title, an
--- optional body that opens in place as a <details> disclosure, a type colour
--- and an optional icon. Module:Hatnote, Module:Entity/EmptyState and
--- Module:Dependencies draw through render(); the notice templates call main()
--- via #invoke.

local libraryUtil = require('libraryUtil')
local checkType = libraryUtil.checkType
local checkTypeForNamedArg = libraryUtil.checkTypeForNamedArg
local details = require('Module:Details')
local icon = require('Module:Icon')

local p = {}

local TYPES = { notice = true, warning = true, error = true }

--- Severity tokens `_mbox` callers pass in `extraclasses`.
local LEGACY_TYPES = { ['mbox-low'] = 'notice', ['mbox-med'] = 'warning', ['mbox-high'] = 'error' }

--- @class MboxProps
--- @field title string         Headline wikitext.
--- @field text? string         Body wikitext; given, the box becomes a collapsible <details>.
--- @field type? string         'notice' (default), 'warning' or 'error'; anything else is 'notice'.
--- @field icon? string         File name, without the File: prefix.
--- @field iconMask? boolean    CSS mask (default) so the icon takes the title colour; false renders a [[File:]] thumbnail.
--- @field placeholder? boolean Dashed slot standing in for an empty section; carries no role.
--- @field open? boolean        Body starts open. Defaults to false.
--- @field class? string        Extra classes on the root (metadata, plainlinks, selfref, …).

--- @param value any
--- @return boolean
local function isNonEmptyString(value)
	return type(value) == 'string' and value ~= ''
end

--- Split an old `extraclasses` string into a type and the remaining classes.
--- @param extraclasses string|nil
--- @return string|nil boxType
--- @return string|nil classes
local function splitLegacyClasses(extraclasses)
	if not isNonEmptyString(extraclasses) then
		return nil, nil
	end
	local boxType
	local rest = {}
	for token in extraclasses:gmatch('%S+') do
		if LEGACY_TYPES[token] then
			boxType = LEGACY_TYPES[token]
		else
			rest[#rest + 1] = token
		end
	end
	return boxType, (#rest > 0 and table.concat(rest, ' ') or nil)
end

--- @param props MboxProps
--- @return string
local function rootClass(props)
	-- TextExtracts drops div elements and the classes in $wgExtractsRemoveClasses but keeps
	-- <details>, so only noexcerpt (one of those classes) keeps a disclosure box's text out of
	-- the meta description and Page Previews; a static box's div root is dropped either way.
	local classes = { 't-mbox', 't-mbox--' .. props.type, 'navigation-not-searchable', 'noexcerpt' }
	if props.placeholder then
		classes[#classes + 1] = 't-mbox--placeholder'
	end
	if isNonEmptyString(props.class) then
		classes[#classes + 1] = props.class
	end
	return table.concat(classes, ' ')
end

--- Icon, title and, for a disclosure, the chevron.
--- @param props MboxProps
--- @param withIndicator boolean
--- @return string
local function headerContent(props, withIndicator)
	local parts = {}
	if isNonEmptyString(props.icon) then
		local mask = props.iconMask ~= false
		parts[#parts + 1] = icon.render({
			icon = props.icon,
			mask = mask,
			-- A [[File:]] size must be in px; the mask scales with the title.
			size = mask and '1em' or '14px',
			class = 't-mbox__icon',
		})
	end
	parts[#parts + 1] = tostring(mw.html.create('span'):addClass('t-mbox__title'):wikitext(props.title))
	if withIndicator then
		-- The Citizen collapse icon Module:CollapsibleCard uses; styles.css rotates it.
		parts[#parts + 1] =
			tostring(mw.html.create('span'):addClass('citizen-ui-icon mw-ui-icon-wikimedia-collapse t-mbox__indicator'))
	end
	return table.concat(parts)
end

--- @param props MboxProps
--- @return string
local function renderStatic(props)
	local root = mw.html.create('div'):addClass(rootClass(props))
	if not props.placeholder then
		root:attr('role', 'note')
	end
	root:tag('div'):addClass('t-mbox__header'):wikitext(headerContent(props, false))
	return tostring(root)
end

--- @param props MboxProps
--- @return string
local function renderDisclosure(props)
	-- Newlines let a body that starts with a list or table parse as block wikitext.
	local body = mw.html.create('div'):addClass('t-mbox__text'):newline():wikitext(props.text):newline()
	return details.getWikitext({
		details = { content = tostring(body), class = rootClass(props), open = props.open },
		summary = { content = headerContent(props, true), class = 't-mbox__header' },
	})
end

--- @param props MboxProps
--- @return string
function p.render(props)
	checkType('Module:Mbox.render', 1, props, 'table')
	checkTypeForNamedArg('Module:Mbox.render', 'title', props.title, 'string')

	local resolved = {
		title = props.title,
		text = isNonEmptyString(props.text) and props.text or nil,
		type = TYPES[props.type] and props.type or 'notice',
		icon = props.icon,
		iconMask = props.iconMask,
		placeholder = props.placeholder == true,
		open = props.open == true,
		class = props.class,
	}

	local frame = mw.getCurrentFrame()
	local styles = frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Mbox/styles.css' } })
	if isNonEmptyString(resolved.icon) then
		styles = styles .. frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })
	end
	local markup = resolved.text and renderDisclosure(resolved) or renderStatic(resolved)
	return styles .. markup
end

--- #invoke entry. Reads only the invocation's own arguments, so the calling
--- template's parameters (Infobox commlink's `type`, TranscriptNotice's
--- `type`) never reach the box.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame, { frameOnly = true })
	local yesno = require('Module:Yesno')
	local title = args.title or args[1]
	if not title then
		return require('Module:Error').error({ message = 'Error: no title specified.' })
	end
	return p.render({
		title = title,
		text = args.text or args[2],
		type = args.type,
		icon = args.icon,
		iconMask = yesno(args.iconmask, true),
		placeholder = yesno(args.placeholder, false),
		open = yesno(args.open, false),
		class = args.class,
	})
end

--- Alias for `{{#invoke:Mbox|mbox}}` invocations.
p.mbox = p.main

--- Lua entry kept for Module:Documentation.
--- @param title string
--- @param text string|nil
--- @param options { icon: string|nil, extraclasses: string|nil }|nil
--- @return string
function p._mbox(title, text, options)
	checkType('_mbox', 1, title, 'string')
	checkType('_mbox', 2, text, 'string', true)
	checkType('_mbox', 3, options, 'table', true)
	options = options or {}
	local boxType, classes = splitLegacyClasses(options.extraclasses)
	return p.render({ title = title, text = text, type = boxType, icon = options.icon, class = classes })
end

-- Test-only exports. Not part of the public API.
p._internal = {
	splitLegacyClasses = splitLegacyClasses,
}

return p
