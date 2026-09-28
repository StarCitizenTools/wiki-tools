require('strict')

--- @module Dependencies
--- The folded "Technical details" panel Module:Documentation shows on module and
--- template pages: which pages use the page, what it uses, and the functions a
--- module defines; and the `dependencies` Bucket row each page writes so the
--- modules and stylesheets it uses can list it. Forward lists come from the
--- page's own source; reverse lists come from the rows other pages wrote.

local parse = require('Module:Dependencies/Parse')
local mbox = require('Module:Mbox')
local icon = require('Module:Icon')
local yesno = require('Module:Yesno')

local p = {}

local BUCKET = 'dependencies'
local NS_TEMPLATE = 10
local NS_MODULE = 828
local HEADING = 'Technical details'
local ICON = 'WikimediaUI-Code.svg'
local ROW_ICONS = {
	source = 'CdxIconReference.svg',
	usedBy = 'CdxIconArrowPrevious.svg',
	uses = 'CdxIconArrowNext.svg',
	functions = 'CdxIconFunction.svg',
}

local UNUSED_TEXT = 'No template invokes it and no module requires or loads it. '
	.. 'If an article invokes it directly, call it through a template instead.'
local UNAVAILABLE_TEXT = 'Unavailable: looking up the pages that use it failed on this render. '
	.. 'Purge the page to retry.'

--- @class DependenciesContext
--- @field title string the documented page, e.g. `Module:Mbox`
--- @field prefix string its namespace with the colon, e.g. `Module:`
--- @field namespace integer
--- @field content string|nil its source
--- @field isCurrent boolean the render is the page itself, not its /doc or another page
--- @field excluded boolean a sandbox or testcases page, whose dependencies are not real usage

--- @class DependenciesGroup
--- @field label string e.g. `Required by`
--- @field items string[] wikitext, one per list item
--- @field note string|nil wikitext under the list

--- @class DependenciesReport
--- @field usedBy DependenciesGroup[]|nil nil when the reverse lookup failed
--- @field uses DependenciesGroup[]
--- @field usedByCount integer distinct pages across `usedBy`
--- @field usesCount integer entries across `uses`
--- @field unused boolean a module nothing invokes, requires or loads
--- @field functions ModuleTocFunction[]

--- @class DependenciesSource
--- @field label string plain text for the folded header, e.g. `wiki-tools`
--- @field text string wikitext, one line of the Source row

--- @class DependenciesPanelOptions
--- @field page string|nil the page to describe; default the current page, or the page a /doc documents
--- @field addCategories boolean|string|nil defaults to true except on a /doc render
--- @field sources DependenciesSource[]|nil

--- @param title table mw.title
--- @return boolean
local function isExcluded(title)
	local text = title.text:lower()
	return text:find('^sandbox/') ~= nil or text:find('/sandbox') ~= nil or text:find('/testcases') ~= nil
end

--- @param pageName string|nil
--- @return DependenciesContext|nil
local function context(pageName)
	local current = mw.title.getCurrentTitle()
	local target = pageName and mw.title.new(pageName) or current
	if target == nil then
		return nil
	end
	if target.isSubpage and target.subpageText:lower() == 'doc' then
		target = target.basePageTitle
	end
	if target.namespace ~= NS_TEMPLATE and target.namespace ~= NS_MODULE then
		return nil
	end
	return {
		title = target.prefixedText,
		prefix = target.prefixedText:match('^[^:]+:'),
		namespace = target.namespace,
		content = target:getContent(),
		isCurrent = current.prefixedText == target.prefixedText,
		excluded = isExcluded(target),
	}
end

--- What the page itself uses: a module's requires, loads and stylesheets, a
--- template's invokes and stylesheets.
--- @param ctx DependenciesContext
--- @return table
local function forward(ctx)
	if ctx.namespace == NS_MODULE then
		local found = parse.lua(ctx.content)
		found.invokes = {}
		return found
	end
	return {
		requires = {},
		loads = {},
		dynamic = {},
		strict = false,
		invokes = parse.invokes(ctx.content),
		styles = parse.styles(ctx.content),
	}
end

--- The page's `dependencies` row, or nil when it uses nothing.
--- @param found table
--- @return table|nil
local function rowFor(found)
	local invokes, calls, seen = {}, {}, {}
	for _, call in ipairs(found.invokes) do
		if not seen[call.module] then
			seen[call.module] = true
			invokes[#invokes + 1] = call.module
		end
		calls[#calls + 1] = call.module .. '|' .. call.func
	end
	local row = {}
	local function set(field, list)
		if list[1] ~= nil then
			row[field] = list
		end
	end
	set('requires', found.requires)
	set('loads', found.loads)
	set('invokes', invokes)
	set('invoke_calls', calls)
	set('styles', found.styles)
	if next(row) == nil then
		return nil
	end
	return row
end

--- @param ctx DependenciesContext
--- @param found table
local function write(ctx, found)
	if not ctx.isCurrent or ctx.excluded then
		return
	end
	local row = rowFor(found)
	if row == nil then
		return
	end
	pcall(function()
		mw.ext.bucket(BUCKET).put(row)
	end)
end

--- @param list any
--- @param value string
--- @return boolean
local function contains(list, value)
	for _, item in ipairs(type(list) == 'table' and list or {}) do
		if item == value then
			return true
		end
	end
	return false
end

--- Splits the rows naming `title` into the pages that invoke, require and load
--- it, and the pages that load its `/styles.css`.
--- @param rows table[] raw Bucket rows keyed by field name (page_name, requires, loads, invokes, invoke_calls, styles)
--- @param title string
--- @return { invokedBy: { page: string, funcs: string[] }[], requiredBy: string[], loadedBy: string[], styledBy: string[] }
local function group(rows, title)
	local back = { invokedBy = {}, requiredBy = {}, loadedBy = {}, styledBy = {} }
	local prefix = title .. '|'
	local stylesheet = title .. '/styles.css'
	for _, row in ipairs(rows) do
		local page = row.page_name
		if page and page ~= title then
			if contains(row.invokes, title) then
				local funcs, seen = {}, {}
				for _, call in ipairs(type(row.invoke_calls) == 'table' and row.invoke_calls or {}) do
					local func = call:sub(1, #prefix) == prefix and call:sub(#prefix + 1) or nil
					if func and not seen[func] then
						seen[func] = true
						funcs[#funcs + 1] = func
					end
				end
				back.invokedBy[#back.invokedBy + 1] = { page = page, funcs = funcs }
			end
			if contains(row.requires, title) then
				back.requiredBy[#back.requiredBy + 1] = page
			end
			if contains(row.loads, title) then
				back.loadedBy[#back.loadedBy + 1] = page
			end
			if contains(row.styles, stylesheet) then
				back.styledBy[#back.styledBy + 1] = page
			end
		end
	end
	table.sort(back.invokedBy, function(a, b)
		return a.page < b.page
	end)
	table.sort(back.requiredBy)
	table.sort(back.loadedBy)
	table.sort(back.styledBy)
	return back
end

--- The pages that use `title`, or nil when the lookup failed.
--- Queries Bucket directly: Module:BucketQuery would load and link every
--- manifest registered ahead of this one on each documentation render.
--- @param title string
--- @return table|nil
local function reverse(title)
	local ok, rows = pcall(function()
		local bucket = mw.ext.bucket
		return bucket(BUCKET)
			.select('page_name', 'requires', 'loads', 'invokes', 'invoke_calls', 'styles')
			.where(
				bucket.Or(
					{ 'requires', title },
					{ 'loads', title },
					{ 'invokes', title },
					{ 'styles', title .. '/styles.css' }
				)
			)
			.limit(5000)
			.run()
	end)
	if not ok or type(rows) ~= 'table' then
		return nil
	end
	return group(rows, title)
end

--- @param text string
--- @return string
local function code(text)
	return '<code>' .. mw.text.nowiki(text) .. '</code>'
end

--- A link to `name` as a row shows it: one of the documented page's own subpages
--- relative (`/styles.css`), otherwise without `prefix`, the namespace the row
--- already implies.
--- @param name string
--- @param ctx DependenciesContext
--- @param prefix string
--- @return string
local function link(name, ctx, prefix)
	local own = ctx.title .. '/'
	local text = name
	if name:sub(1, #own) == own then
		text = name:sub(#own)
	elseif name:sub(1, #prefix) == prefix then
		text = name:sub(#prefix + 1)
	end
	if text == name then
		return '[[' .. name .. ']]'
	end
	return '[[' .. name .. '|' .. text .. ']]'
end

--- @param names string[]
--- @param ctx DependenciesContext
--- @param prefix string
--- @return string[]
local function links(names, ctx, prefix)
	local items = {}
	for i, name in ipairs(names) do
		items[i] = link(name, ctx, prefix)
	end
	return items
end

--- The templates that invoke the page, each with the functions it calls. When
--- every one calls the same single function, the note names it once instead.
--- @param entries { page: string, funcs: string[] }[]
--- @param ctx DependenciesContext
--- @return string[] items
--- @return string|nil note
local function invokers(entries, ctx)
	local shared = entries[1] and entries[1].funcs[1]
	for _, entry in ipairs(entries) do
		if #entry.funcs ~= 1 or entry.funcs[1] ~= shared then
			shared = nil
			break
		end
	end
	local items = {}
	for i, entry in ipairs(entries) do
		items[i] = link(entry.page, ctx, 'Template:')
		if shared == nil and entry.funcs[1] ~= nil then
			local funcs = {}
			for j, func in ipairs(entry.funcs) do
				funcs[j] = code(func)
			end
			items[i] = items[i] .. ' (' .. table.concat(funcs, ', ') .. ')'
		end
	end
	if shared == nil then
		return items, nil
	end
	return items, (#entries > 1 and 'All via ' or 'Via ') .. code(shared)
end

--- @param into DependenciesGroup[]
--- @param label string
--- @param items string[]
--- @param note string|nil
local function addGroup(into, label, items, note)
	if items[1] ~= nil then
		into[#into + 1] = { label = label, items = items, note = note }
	end
end

--- @param back table
--- @return integer
local function countPages(back)
	local seen, count = {}, 0
	local function add(page)
		if not seen[page] then
			seen[page] = true
			count = count + 1
		end
	end
	for _, entry in ipairs(back.invokedBy) do
		add(entry.page)
	end
	for _, key in ipairs({ 'requiredBy', 'loadedBy', 'styledBy' }) do
		for _, page in ipairs(back[key]) do
			add(page)
		end
	end
	return count
end

--- What the panel shows for the page, before any markup.
--- @param ctx DependenciesContext
--- @param found table forward()'s result
--- @param back table|nil reverse()'s result; nil when the lookup failed
--- @return DependenciesReport
local function report(ctx, found, back)
	local uses, usesCount = {}, 0
	if ctx.namespace == NS_TEMPLATE then
		local calls = {}
		for i, call in ipairs(found.invokes) do
			calls[i] = code(call.func) .. ' in [[' .. call.module .. ']]'
		end
		addGroup(uses, 'Invokes', calls)
		usesCount = #calls
	else
		local requires = links(found.requires, ctx, 'Module:')
		for _, pattern in ipairs(found.dynamic) do
			requires[#requires + 1] = code(pattern)
		end
		addGroup(uses, 'Requires', requires)
		addGroup(uses, 'Loads', links(found.loads, ctx, 'Module:'))
		usesCount = #requires + #found.loads
	end
	addGroup(uses, 'Styles', links(found.styles, ctx, ctx.prefix))
	usesCount = usesCount + #found.styles

	local result = {
		uses = uses,
		usesCount = usesCount,
		usedByCount = 0,
		unused = false,
		functions = {},
	}
	if back ~= nil then
		local usedBy = {}
		local items, note = invokers(back.invokedBy, ctx)
		addGroup(usedBy, 'Invoked by', items, note)
		addGroup(usedBy, 'Required by', links(back.requiredBy, ctx, 'Module:'))
		addGroup(usedBy, 'Loaded by', links(back.loadedBy, ctx, 'Module:'))
		addGroup(usedBy, 'Styles used by', links(back.styledBy, ctx, ctx.prefix))
		result.usedBy = usedBy
		result.usedByCount = countPages(back)
		result.unused = ctx.namespace == NS_MODULE
			and not ctx.excluded
			and back.invokedBy[1] == nil
			and back.requiredBy[1] == nil
			and back.loadedBy[1] == nil
	end
	if ctx.namespace == NS_MODULE then
		-- Required here, not at the top: every page records the modules it loads
		-- and re-parses when one changes, and template pages never need this one.
		result.functions = require('Module:Module toc').functions(ctx.content)
	end
	return result
end

--- @param ctx DependenciesContext
--- @param found table
--- @param result DependenciesReport
--- @return string
local function categories(ctx, found, result)
	local out = {}
	if ctx.namespace == NS_TEMPLATE and found.invokes[1] ~= nil then
		out[#out + 1] = '[[Category:Lua-based templates]]'
	end
	if ctx.namespace == NS_MODULE and found.strict then
		out[#out + 1] = '[[Category:Strict mode modules]]'
	end
	if result.unused then
		out[#out + 1] = '[[Category:Unused modules]]'
	end
	return table.concat(out)
end

--- @param addCategories boolean|string|nil
--- @return boolean
local function categoriesEnabled(addCategories)
	-- Yesno's `default` only covers an unrecognised string, not a nil argument
	-- (a #invoke omitting the parameter, or a Lua caller passing nothing).
	local enabled = yesno(addCategories)
	if enabled == nil then
		local current = mw.title.getCurrentTitle()
		return not (current.isSubpage and current.subpageText:lower() == 'doc')
	end
	return enabled == true
end

--- @param items string[]
--- @param modifier string|nil
--- @return table mw.html
local function list(items, modifier)
	local root = mw.html.create('ul'):addClass('t-dependencies__list')
	if modifier then
		root:addClass('t-dependencies__list--' .. modifier)
	end
	for _, item in ipairs(items) do
		root:tag('li'):wikitext(item)
	end
	return root
end

--- @param groups DependenciesGroup[]
--- @return string
local function groupsHtml(groups)
	local root = mw.html.create('div'):addClass('t-dependencies__groups')
	for _, entry in ipairs(groups) do
		root:tag('div')
			:addClass('t-dependencies__sublabel')
			:wikitext(entry.label)
			:tag('span')
			:addClass('t-dependencies__count')
			:wikitext(#entry.items)
		local body = root:tag('div'):addClass('t-dependencies__items'):node(list(entry.items))
		if entry.note then
			body:tag('div'):addClass('t-dependencies__note'):wikitext(entry.note)
		end
	end
	return tostring(root)
end

--- @param title string
--- @param functions ModuleTocFunction[]
--- @return string
local function functionsHtml(title, functions)
	local items = {}
	for i, func in ipairs(functions) do
		items[i] = string.format(
			'[[%s#L-%d|%s]]<span class="t-dependencies__line">L%d</span>',
			title,
			func.line,
			mw.text.nowiki(func.name),
			func.line
		)
	end
	return tostring(list(items, 'code'))
end

--- @param label string
--- @param file string
--- @param content string wikitext
--- @param modifier string|nil
--- @return string
local function row(label, file, content, modifier)
	local root = mw.html.create('div'):addClass('t-dependencies__row')
	if modifier then
		root:addClass('t-dependencies__row--' .. modifier)
	end
	root:tag('div')
		:addClass('t-dependencies__label')
		:wikitext(icon.render({ icon = file, mask = true, size = '1em', class = 't-dependencies__icon' }))
		:wikitext(label)
	root:tag('div'):addClass('t-dependencies__content'):wikitext(content)
	return tostring(root)
end

--- The folded header: the heading, then plain-text facts. It sits inside
--- <summary>, so it must hold no link.
--- @param facts string[]
--- @param unused boolean
--- @return string
local function summary(facts, unused)
	local root = mw.html.create('span'):addClass('t-dependencies__summary')
	root:tag('span'):addClass('t-dependencies__heading'):wikitext(HEADING)
	if unused or facts[1] ~= nil then
		local meta = root:tag('span'):addClass('t-dependencies__meta')
		if unused then
			meta:tag('span'):addClass('t-dependencies__chip'):wikitext('Unused')
		end
		if facts[1] ~= nil then
			meta:tag('span'):wikitext(table.concat(facts, ' · '))
		end
	end
	return tostring(root)
end

--- The panel for `options.page`, followed by its categories. Writes the page's
--- row when the render is the page itself.
--- @param options DependenciesPanelOptions|nil
--- @return string
function p.panel(options)
	options = options or {}
	local rows, facts, unused, cats = {}, {}, false, ''
	local lines = {}
	for _, source in ipairs(options.sources or {}) do
		lines[#lines + 1] = '<div>' .. source.text .. '</div>'
		facts[#facts + 1] = source.label
	end
	if lines[1] ~= nil then
		rows[#rows + 1] = row('Source', ROW_ICONS.source, table.concat(lines))
	end

	local ctx = context(options.page)
	if ctx ~= nil and ctx.content ~= nil then
		local found = forward(ctx)
		write(ctx, found)
		local back = reverse(ctx.title)
		local result = report(ctx, found, back)
		unused = result.unused
		if unused then
			local content = '<div>' .. UNUSED_TEXT .. '</div>'
			if result.usedBy[1] ~= nil then
				content = content .. groupsHtml(result.usedBy)
			end
			rows[#rows + 1] = row('Used by', ROW_ICONS.usedBy, content, 'warning')
		elseif back == nil then
			if ctx.namespace == NS_MODULE then
				rows[#rows + 1] = row('Used by', ROW_ICONS.usedBy, UNAVAILABLE_TEXT, 'muted')
			end
		elseif result.usedBy[1] ~= nil then
			rows[#rows + 1] = row('Used by', ROW_ICONS.usedBy, groupsHtml(result.usedBy))
			facts[#facts + 1] = 'used by ' .. result.usedByCount
		end
		if result.uses[1] ~= nil then
			rows[#rows + 1] = row('Uses', ROW_ICONS.uses, groupsHtml(result.uses))
			facts[#facts + 1] = 'uses ' .. result.usesCount
		end
		if result.functions[1] ~= nil then
			rows[#rows + 1] = row('Functions', ROW_ICONS.functions, functionsHtml(ctx.title, result.functions))
		end
		if categoriesEnabled(options.addCategories) then
			cats = categories(ctx, found, result)
		end
	end

	if rows[1] == nil then
		return cats
	end
	local frame = mw.getCurrentFrame()
	-- Module:Icon leaves its stylesheet to the caller; the row icons need it.
	local styles = frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })
		.. frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Dependencies/styles.css' } })
	return styles
		.. mbox.render({
			title = summary(facts, unused),
			text = table.concat(rows),
			icon = ICON,
			class = 't-dependencies',
		})
		.. cats
end

--- `{{#invoke:Dependencies|main}}`, for MediaWiki:Scribunto-doc-page-does-not-exist.
--- @param frame table
--- @return string
function p.main(frame)
	return p.panel()
end

-- Test-only exports. Not part of the public API.
p._internal = {
	group = group,
	report = report,
	rowFor = rowFor,
}

return p
