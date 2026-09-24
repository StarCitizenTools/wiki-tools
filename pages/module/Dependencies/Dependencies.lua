require('strict')

--- @module Dependencies
--- The dependency notices Module:Documentation shows on module and template
--- pages, and the `dependencies` Bucket row each page writes so the modules and
--- stylesheets it uses can list it. Forward lists come from the page's own
--- source; reverse lists come from the rows other pages wrote.

local parse = require('Module:Dependencies/Parse')
local mbox = require('Module:Mbox')
local yesno = require('Module:Yesno')

local p = {}

local BUCKET = 'dependencies'
local NS_TEMPLATE = 10
local NS_MODULE = 828
--- A list longer than this renders as a box with the list in its body.
local INLINE_LIMIT = 5
local ICON = 'WikimediaUI-Code.svg'
local ICON_UNUSED = 'WikimediaUI-Alert.svg'

--- Short form (inline list) and long form (count) of each notice.
local MESSAGES = {
	invokes = { '%s invokes %s.', '%s invokes %d functions.' },
	requires = { '%s requires %s.', '%s requires %d modules.' },
	loads = { '%s loads data from %s.', '%s loads data from %d modules.' },
	invokedBy = { '%s is invoked by %s.', '%s is invoked by %d templates.' },
	requiredBy = { '%s is required by %s.', '%s is required by %d modules.' },
	loadedBy = { '%s is loaded by %s.', '%s is loaded by %d modules.' },
	styles = { '%s uses styles from %s.', '%s uses styles from %d stylesheets.' },
	styledBy = { '%s is used by %s.', '%s is used by %d pages.' },
	styledByAlso = { '%s is also used by %s.', '%s is also used by %d pages.' },
}

local UNUSED_TEXT = 'No template invokes it and no module requires or loads it. '
	.. 'If an article invokes it directly, call it through a template instead.'

--- @class DependenciesContext
--- @field title string the documented page, e.g. `Module:Mbox`
--- @field namespace integer
--- @field content string|nil its source
--- @field isCurrent boolean the render is the page itself, not its /doc or another page
--- @field excluded boolean a sandbox or testcases page, whose dependencies are not real usage

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
				local funcs = {}
				for _, call in ipairs(type(row.invoke_calls) == 'table' and row.invoke_calls or {}) do
					if call:sub(1, #prefix) == prefix then
						funcs[#funcs + 1] = call:sub(#prefix + 1)
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
--- registered manifest on each documentation render.
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

--- @param kind string a MESSAGES key
--- @param page string
--- @param items string[]
--- @return string
local function notice(kind, page, items)
	if items[1] == nil then
		return ''
	end
	local message = MESSAGES[kind]
	if #items <= INLINE_LIMIT then
		return mbox.render({ title = string.format(message[1], page, mw.text.listToText(items)), icon = ICON })
	end
	return mbox.render({
		title = string.format(message[2], page, #items),
		text = '* ' .. table.concat(items, '\n* '),
		icon = ICON,
	})
end

--- @param page string
--- @return string
local function link(page)
	return '[[' .. page .. ']]'
end

--- @param text string
--- @return string
local function code(text)
	return '<code>' .. mw.text.nowiki(text) .. '</code>'
end

--- @param pages string[]
--- @return string[]
local function links(pages)
	local items = {}
	for i, page in ipairs(pages) do
		items[i] = link(page)
	end
	return items
end

--- The pages that load `title`'s own `/styles.css`, worded by whether `title` loads it too.
--- @param ctx DependenciesContext
--- @param found table
--- @param back table|nil
--- @return string
local function stylesheetUsers(ctx, found, back)
	if back == nil then
		return ''
	end
	local stylesheet = ctx.title .. '/styles.css'
	local kind = contains(found.styles, stylesheet) and 'styledByAlso' or 'styledBy'
	return notice(kind, link(stylesheet), links(back.styledBy))
end

--- @param ctx DependenciesContext
--- @param found table
--- @param back table|nil nil when the reverse lookup failed
--- @param options { categories: boolean }
--- @return string
local function render(ctx, found, back, options)
	local out = {}
	local function add(text)
		if text ~= '' then
			out[#out + 1] = text
		end
	end

	if ctx.namespace == NS_TEMPLATE then
		local calls = {}
		for _, call in ipairs(found.invokes) do
			calls[#calls + 1] = code(call.func) .. ' in ' .. link(call.module)
		end
		add(notice('invokes', ctx.title, calls))
		add(notice('styles', ctx.title, links(found.styles)))
		add(stylesheetUsers(ctx, found, back))
		if options.categories and calls[1] ~= nil then
			add('[[Category:Lua-based templates]]')
		end
		return table.concat(out)
	end

	local unused = back ~= nil
		and back.invokedBy[1] == nil
		and back.requiredBy[1] == nil
		and back.loadedBy[1] == nil
		and not ctx.excluded
	if unused then
		add(mbox.render({ type = 'warning', icon = ICON_UNUSED, title = 'This module is unused.', text = UNUSED_TEXT }))
	end

	local requires = {}
	for _, name in ipairs(found.requires) do
		requires[#requires + 1] = link(name)
	end
	for _, pattern in ipairs(found.dynamic) do
		requires[#requires + 1] = code(pattern)
	end
	add(notice('requires', ctx.title, requires))

	add(notice('loads', ctx.title, links(found.loads)))
	add(notice('styles', ctx.title, links(found.styles)))

	if back ~= nil then
		local invokedBy = {}
		for _, entry in ipairs(back.invokedBy) do
			local funcs = {}
			for i, func in ipairs(entry.funcs) do
				funcs[i] = code(func)
			end
			invokedBy[#invokedBy + 1] = link(entry.page)
				.. (funcs[1] and (' (' .. table.concat(funcs, ', ') .. ')') or '')
		end
		add(notice('invokedBy', ctx.title, invokedBy))
		add(notice('requiredBy', ctx.title, links(back.requiredBy)))
		add(notice('loadedBy', ctx.title, links(back.loadedBy)))
	end
	add(stylesheetUsers(ctx, found, back))

	if options.categories then
		if found.strict then
			add('[[Category:Strict mode modules]]')
		end
		if unused then
			add('[[Category:Unused modules]]')
		end
	end
	return table.concat(out)
end

--- The notices for `pageName` (default: the current page, or the page a /doc
--- documents), and that page's row when the render is the page itself.
--- @param pageName string|nil
--- @param addCategories boolean|string|nil defaults to true except on a /doc render
--- @return string
function p._main(pageName, addCategories)
	local ctx = context(pageName)
	if ctx == nil or ctx.content == nil then
		return ''
	end
	local found = forward(ctx)
	write(ctx, found)
	local back = reverse(ctx.title)
	local current = mw.title.getCurrentTitle()
	local onDoc = current.isSubpage and current.subpageText:lower() == 'doc'
	-- Yesno's `default` only covers an unrecognised string, not a nil argument
	-- (a #invoke omitting the parameter, or a Lua caller passing nothing).
	local categories = yesno(addCategories)
	if categories == nil then
		categories = not onDoc
	end
	return render(ctx, found, back, {
		categories = categories == true,
	})
end

--- `{{#invoke:Dependencies|main}}`, for MediaWiki:Scribunto-doc-page-does-not-exist.
--- @param frame table
--- @return string
function p.main(frame)
	return p._main()
end

-- Test-only exports. Not part of the public API.
p._internal = {
	group = group,
	rowFor = rowFor,
}

return p
