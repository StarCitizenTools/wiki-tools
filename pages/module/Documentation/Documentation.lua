require('strict')

--- @module Documentation
--- The documentation header on module and template pages and on their /doc
--- subpages, followed by the Technical details panel. Template:Documentation
--- invokes doc() at the top of each /doc page.

-- <nowiki>
local button = require('Module:ButtonLua')
local hatnote = require('Module:Hatnote')._hatnote
local icon = require('Module:Icon')

local p = {}

local NS_TEMPLATE = 10
local NS_MODULE = 828
local REPO_URL = 'https://github.com/StarCitizenTools/wiki-tools/tree/main/pages/'
local WIKIPEDIA_URL = 'https://en.wikipedia.org/wiki/'
local ICONS = {
	page = 'CdxIconBook.svg',
	edit = 'CdxIconEdit.svg',
	history = 'CdxIconHistory.svg',
	purge = 'CdxIconReload.svg',
	back = 'CdxIconArrowPrevious.svg',
}

--- The visible text of a wikitext link, for the panel's plain-text facts.
--- @param wikitext string
--- @return string
local function linkText(wikitext)
	return wikitext:match('^%s*%[%[[^|%]]*|(.-)%]%]%s*$')
		or wikitext:match('^%s*%[%[(.-)%]%]%s*$')
		or wikitext:match('^%s*%[%S+%s+(.-)%]%s*$')
		or wikitext
end

--- Where the page was imported from, as a wikitext link: `importedFrom=`, or
--- its `fromWikipedia=` shorthand for the same title on the English Wikipedia.
--- @param args table the {{Documentation}} arguments
--- @param page string the documented page
--- @return string|nil
local function importOrigin(args, page)
	if args.importedFrom and args.importedFrom ~= '' then
		return args.importedFrom
	end
	if args.fromWikipedia then
		return '[' .. WIKIPEDIA_URL .. mw.uri.encode(page, 'WIKI') .. ' Wikipedia]'
	end
	return nil
end

--- The Source row lines of the Technical details panel: where the page is
--- maintained (`git=`) and where it came from.
--- @param args table the {{Documentation}} arguments
--- @param kind string 'module' or 'template'
--- @param rootText string
--- @param page string the documented page
--- @return table[] DependenciesSource[]
local function sources(args, kind, rootText, page)
	local list = {}
	if args.git then
		local url = REPO_URL .. kind .. '/' .. mw.uri.encode(rootText, 'PATH')
		list[#list + 1] = { label = 'wiki-tools', text = 'Synced with [' .. url .. ' wiki-tools] on GitHub' }
	end
	local origin = importOrigin(args, page)
	if origin then
		list[#list + 1] = { label = 'from ' .. linkText(origin), text = 'Imported from ' .. origin }
	end
	return list
end

--- @param kind string 'module' or 'template'
--- @param onDoc boolean the render is the /doc subpage itself
--- @param baseText string the /doc page's base page name, its sort key
--- @param imported boolean
--- @return string
local function categories(kind, onDoc, baseText, imported)
	local plural = kind == 'module' and 'Modules' or 'Templates'
	if onDoc then
		return '[[Category:' .. plural .. ' documentation|' .. baseText .. ']]'
	end
	local out = {}
	if kind == 'module' then
		out[#out + 1] = '[[Category:Modules]]'
	end
	if imported then
		out[#out + 1] = '[[Category:Imported ' .. plural:lower() .. ']]'
	end
	return table.concat(out)
end

--- A quiet icon-only header button. ButtonLua puts the label in aria-label,
--- which no browser shows, so the wrapper's title gives mouse users a tooltip.
--- @param props table ButtonProps: label, icon, and link or url
--- @return string
local function action(props)
	props.weight = 'quiet'
	props.iconOnly = true
	return tostring(
		mw.html
			.create('span')
			:addClass('t-documentation__action')
			:attr('title', props.label)
			:wikitext(button.render(props))
	)
end

--- @param title string
--- @param subtitle string wikitext
--- @param actions string[]
--- @return string
local function header(title, subtitle, actions)
	local root = mw.html.create('div'):addClass('t-documentation__header')
	root:tag('span')
		:addClass('t-documentation__icon')
		:wikitext(icon.render({ icon = ICONS.page, mask = true, size = '1.125rem' }))
	local heading = root:tag('div'):addClass('t-documentation__heading')
	heading
		:tag('div')
		:addClass('t-documentation__title')
		:attr('role', 'heading')
		:attr('aria-level', '2')
		:wikitext(title)
	heading:tag('div'):addClass('t-documentation__subtitle'):wikitext(subtitle)
	root:tag('div'):addClass('t-documentation__actions'):wikitext(table.concat(actions))
	return tostring(root)
end

--- A failure in Module:Dependencies, or a module it requires, must not break
--- every documentation page: require and render it inside a pcall.
--- @param options table DependenciesPanelOptions
--- @return string
local function technicalDetails(options)
	local ok, result = pcall(function()
		return require('Module:Dependencies').panel(options)
	end)
	if ok then
		return result
	end
	return '<strong class="error">' .. mw.text.nowiki(tostring(result)) .. '</strong>'
end

--- `{{#invoke:Documentation|doc}}`, from Template:Documentation.
--- @param frame table
--- @return string
function p.doc(frame)
	local title = mw.title.getCurrentTitle()
	local args = frame:getParent().args
	local page = args[1] or (title.fullText:gsub('/[Dd]o[ck]u?$', ''))
	local kind = title.namespace == NS_MODULE and 'module' or 'template'
	local onDoc = title.subpageText == 'doc'

	-- Left open on purpose: {{Documentation}} sits at the top of the /doc page,
	-- and the wrapper holds the rest of it until the parser closes it at the end.
	local out = { '<div class="t-documentation' .. (args.git and ' t-documentation--git' or '') .. '">' }
	out[#out + 1] = frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })
	out[#out + 1] = frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Documentation/styles.css' } })

	if onDoc then
		out[#out + 1] = header('Documentation subpage', 'Shown on [[' .. page .. ']]', {
			action({ label = 'Back to the ' .. kind, icon = ICONS.back, link = page }),
		})
	else
		local doc = page .. '/doc'
		out[#out + 1] =
			header(kind == 'module' and 'Module documentation' or 'Template documentation', 'From [[' .. doc .. ']]', {
				action({ label = 'Edit', icon = ICONS.edit, url = tostring(mw.uri.fullUrl(doc, { action = 'edit' })) }),
				action({
					label = 'History',
					icon = ICONS.history,
					url = tostring(mw.uri.fullUrl(doc, { action = 'history' })),
				}),
				action({
					label = 'Purge',
					icon = ICONS.purge,
					url = tostring(mw.uri.fullUrl(title.fullText, { action = 'purge' })),
				}),
			})
	end

	local notices = mw.html.create('div'):addClass('t-documentation__notices')
	if not onDoc and title.namespace == NS_MODULE and title.subpageText == 'testcases' then
		notices:wikitext(
			hatnote(
				'This is the test cases page for the module [[Module:' .. title.baseText .. ']].',
				{ icon = 'WikimediaUI-LabFlask.svg' }
			)
		)
	end
	notices:wikitext(technicalDetails({
		addCategories = (not onDoc) and args.category or nil,
		sources = sources(args, kind, title.rootText, page),
	}))
	out[#out + 1] = tostring(notices)

	if title.namespace == NS_TEMPLATE or title.namespace == NS_MODULE then
		out[#out + 1] = categories(kind, onDoc, title.baseText, importOrigin(args, page) ~= nil)
	end

	if not onDoc and title.namespace == NS_MODULE then
		local testcases = title.text .. '/testcases'
		if mw.title.new(testcases, 'Module').exists then
			out[#out + 1] = frame:preprocess('{{#invoke:' .. testcases .. '|run}}')
		end
	end

	return table.concat(out)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	categories = categories,
	linkText = linkText,
	sources = sources,
}

return p
-- </nowiki>
