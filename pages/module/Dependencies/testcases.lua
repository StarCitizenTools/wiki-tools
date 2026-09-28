require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local dependencies = require('Module:Dependencies')
local bucketLib = require('mw.ext.bucket')

local suite = ScribuntoUnit:new()

--- A title shaped like mw.title's, for the fields Module:Dependencies reads.
local function fakeTitle(prefixed, namespace, content)
	local text = (prefixed:gsub('^[^:]+:', ''))
	local sub = text:match('/([^/]+)$')
	local title = {
		prefixedText = prefixed,
		namespace = namespace,
		text = text,
		isSubpage = sub ~= nil,
		subpageText = sub or text,
	}
	function title.getContent()
		return content
	end
	return title
end

--- Runs fn with `current` as the page being rendered, `pages` resolving
--- mw.title.new, and the index holding `rows` (raw Bucket rows keyed by field).
local function render(current, pages, rows, fn)
	local realCurrent, realNew = mw.title.getCurrentTitle, mw.title.new
	mw.title.getCurrentTitle = function()
		return current
	end
	mw.title.new = function(name)
		return pages[name]
	end
	bucketLib._reset()
	bucketLib._setRows('dependencies', rows or {})
	local ok, err = pcall(fn)
	mw.title.getCurrentTitle, mw.title.new = realCurrent, realNew
	if not ok then
		error(err, 0)
	end
end

--- The recorded read: put() records a chain too, and runs first.
local function queryChain()
	for _, chain in ipairs(bucketLib._chains) do
		if chain.select[1] ~= nil then
			return chain
		end
	end
end

--- The context report() reads, for a page with no source of its own.
local function ctxFor(title, namespace, overrides)
	local ctx = {
		title = title,
		prefix = title:match('^[^:]+:'),
		namespace = namespace,
		content = '',
		isCurrent = true,
		excluded = false,
	}
	for key, value in pairs(overrides or {}) do
		ctx[key] = value
	end
	return ctx
end

--- forward()'s shape for a module, with only the lists given.
local function moduleFound(lists)
	local found = { requires = {}, loads = {}, dynamic = {}, styles = {}, invokes = {}, strict = false }
	for key, value in pairs(lists or {}) do
		found[key] = value
	end
	return found
end

--- reverse()'s shape, with only the lists given.
local function back(lists)
	local result = { invokedBy = {}, requiredBy = {}, loadedBy = {}, styledBy = {} }
	for key, value in pairs(lists or {}) do
		result[key] = value
	end
	return result
end

--- The folded header's markup: the text inside <summary>.
local function summaryOf(html)
	return html:match('<summary[^>]*>(.-)</summary>') or ''
end

local MBOX_SRC = "require('strict')\nlocal details = require('Module:Details')\nlocal icon = require('Module:Icon')"
local OUTDATED_SRC = '{{#invoke:Mbox|main|type=warning}}{{#invoke:Maintenance|record}}'
local ICON_SRC =
	"local p = {}\nfunction p.main()\n\treturn mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })\nend\nreturn p"

-- The Bucket row

function suite:testModuleWritesItsRow()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	render(mbox, {}, {}, function()
		dependencies.panel()
		self:assertEquals(1, #bucketLib._puts)
		self:assertEquals('dependencies', bucketLib._puts[1].bucket)
		self:assertDeepEquals({ 'Module:Details', 'Module:Icon' }, bucketLib._puts[1].data.requires)
		self:assertEquals(nil, bucketLib._puts[1].data.loads)
	end)
end

function suite:testTemplateWritesInvokes()
	local outdated = fakeTitle('Template:Outdated', 10, OUTDATED_SRC)
	render(outdated, {}, {}, function()
		dependencies.panel()
		local data = bucketLib._puts[1].data
		self:assertDeepEquals({ 'Module:Maintenance', 'Module:Mbox' }, data.invokes)
		self:assertDeepEquals({ 'Module:Maintenance|record', 'Module:Mbox|main' }, data.invoke_calls)
	end)
end

function suite:testRowCarriesStylesheets()
	render(fakeTitle('Module:Icon', 828, ICON_SRC), {}, {}, function()
		dependencies.panel()
		self:assertDeepEquals({ 'Module:Icon/styles.css' }, bucketLib._puts[1].data.styles)
	end)
end

function suite:testDocRenderDoesNotWrite()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	local doc = fakeTitle('Module:Mbox/doc', 828, 'Docs.')
	doc.basePageTitle = mbox
	render(doc, {}, {}, function()
		dependencies.panel()
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testSandboxAndTestcasesDoNotWrite()
	for _, name in ipairs({ 'Module:Mbox/sandbox', 'Module:Mbox/testcases', 'Module:Sandbox/User/Mbox' }) do
		render(fakeTitle(name, 828, MBOX_SRC), {}, {}, function()
			dependencies.panel()
			self:assertEquals(0, #bucketLib._puts, name)
		end)
	end
end

function suite:testExplicitOtherPageDoesNotWrite()
	local current = fakeTitle('Module:A', 828, '')
	local other = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	render(current, { ['Module:Mbox'] = other }, {}, function()
		dependencies.panel({ page = 'Module:Mbox' })
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testNoDependenciesNoRow()
	render(fakeTitle('Module:Lonely', 828, 'local p = {}\nreturn p'), {}, {}, function()
		dependencies.panel()
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testGroupSplitsDependentsByKind()
	local result = dependencies._internal.group({
		{
			page_name = 'Template:Outdated',
			invokes = { 'Module:Mbox' },
			invoke_calls = { 'Module:Mbox|main', 'Module:Other|x', 'Module:Mbox|main' },
		},
		{ page_name = 'Module:Hatnote', requires = { 'Module:Mbox', 'Module:Icon' } },
		{ page_name = 'Module:Data user', loads = { 'Module:Mbox' } },
		{ page_name = 'Module:BadgeLua', styles = { 'Module:Mbox/styles.css' } },
		{
			page_name = 'Module:Mbox',
			requires = { 'Module:Mbox' },
			styles = { 'Module:Mbox/styles.css' },
		},
	}, 'Module:Mbox')
	self:assertDeepEquals({ { page = 'Template:Outdated', funcs = { 'main' } } }, result.invokedBy)
	self:assertDeepEquals({ 'Module:Hatnote' }, result.requiredBy)
	self:assertDeepEquals({ 'Module:Data user' }, result.loadedBy)
	self:assertDeepEquals({ 'Module:BadgeLua' }, result.styledBy)
end

-- The report

function suite:testReportShortensNames()
	local result = dependencies._internal.report(
		ctxFor('Module:InfoboxLua', 828),
		moduleFound({
			requires = { 'Module:Icon', 'Module:InfoboxLua/ImageResolver' },
			loads = { 'Module:InfoboxLua/testData.json' },
			styles = { 'Module:InfoboxLua/styles.css', 'Template:Foo/styles.css' },
		}),
		back()
	)
	self:assertDeepEquals({
		{
			label = 'Requires',
			items = { '[[Module:Icon|Icon]]', '[[Module:InfoboxLua/ImageResolver|/ImageResolver]]' },
		},
		{ label = 'Loads', items = { '[[Module:InfoboxLua/testData.json|/testData.json]]' } },
		{ label = 'Styles', items = { '[[Module:InfoboxLua/styles.css|/styles.css]]', '[[Template:Foo/styles.css]]' } },
	}, result.uses)
	self:assertEquals(5, result.usesCount)
end

function suite:testReportNamesASharedFunctionOnce()
	local result = dependencies._internal.report(
		ctxFor('Module:Mbox', 828),
		moduleFound(),
		back({
			invokedBy = {
				{ page = 'Template:Removed', funcs = { 'main' } },
				{ page = 'Template:Stub', funcs = { 'main' } },
			},
		})
	)
	self:assertDeepEquals({
		label = 'Invoked by',
		items = { '[[Template:Removed|Removed]]', '[[Template:Stub|Stub]]' },
		note = 'All via <code>main</code>',
	}, result.usedBy[1])
end

function suite:testReportNamesEachInvokersFunctions()
	local result = dependencies._internal.report(
		ctxFor('Module:Mbox', 828),
		moduleFound(),
		back({
			invokedBy = {
				{ page = 'Template:Outdated', funcs = { 'main' } },
				{ page = 'Template:Review', funcs = { 'record', 'main' } },
			},
		})
	)
	self:assertDeepEquals({
		label = 'Invoked by',
		items = {
			'[[Template:Outdated|Outdated]] (<code>main</code>)',
			'[[Template:Review|Review]] (<code>record</code>, <code>main</code>)',
		},
	}, result.usedBy[1])
end

function suite:testReportCountsDistinctPages()
	local result = dependencies._internal.report(
		ctxFor('Module:Icon', 828),
		moduleFound(),
		back({ requiredBy = { 'Module:BadgeLua' }, styledBy = { 'Module:BadgeLua', 'Module:Boolean' } })
	)
	self:assertEquals(2, result.usedByCount)
	self:assertEquals('Styles used by', result.usedBy[2].label)
end

function suite:testReportUnused()
	local report = dependencies._internal.report
	self:assertTrue(report(ctxFor('Module:Lonely', 828), moduleFound(), back()).unused)
	self:assertFalse(report(ctxFor('Module:Lonely', 828, { excluded = true }), moduleFound(), back()).unused)
	-- A page loading its stylesheet does not use the module's code.
	self:assertTrue(report(ctxFor('Module:Lonely', 828), moduleFound(), back({ styledBy = { 'Module:Other' } })).unused)
	local failed = report(ctxFor('Module:Lonely', 828), moduleFound(), nil)
	self:assertFalse(failed.unused)
	self:assertEquals(nil, failed.usedBy)
end

function suite:testReportTemplateInvokes()
	local found = moduleFound({ invokes = { { module = 'Module:BadgeLua', func = 'main' } } })
	local result = dependencies._internal.report(ctxFor('Template:Badge', 10), found, back())
	self:assertDeepEquals(
		{ { label = 'Invokes', items = { '<code>main</code> in [[Module:BadgeLua]]' } } },
		result.uses
	)
	self:assertEquals(1, result.usesCount)
	self:assertFalse(result.unused)
	self:assertDeepEquals({}, result.functions)
end

function suite:testReportListsModuleFunctions()
	local ctx = ctxFor('Module:X', 828, { content = 'local p = {}\nfunction p.main(frame)\nend\nreturn p\n' })
	local result = dependencies._internal.report(ctx, moduleFound(), back())
	self:assertDeepEquals({ { name = 'p.main', line = 2 } }, result.functions)
end

-- The panel

function suite:testModulePanel()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	local rows = {
		{ page_name = 'Template:Outdated', invokes = { 'Module:Mbox' }, invoke_calls = { 'Module:Mbox|main' } },
		{ page_name = 'Module:Hatnote', requires = { 'Module:Mbox' } },
	}
	render(mbox, {}, rows, function()
		local html = dependencies.panel()
		local summary = summaryOf(html)
		self:assertStringContains('Technical details', summary, true)
		self:assertStringContains('used by 2 · uses 2', summary, true)
		self:assertNotStringContains('Unused', summary, true)
		self:assertStringContains('[[Template:Outdated|Outdated]]', html, true)
		self:assertStringContains('Via <code>main</code>', html, true)
		self:assertStringContains('[[Module:Hatnote|Hatnote]]', html, true)
		self:assertStringContains('[[Module:Details|Details]]', html, true)
		self:assertStringContains('[[Category:Strict mode modules]]', html, true)
		local chain = queryChain()
		self:assertEquals('dependencies', chain.bucket)
		self:assertDeepEquals({ 'page_name', 'requires', 'loads', 'invokes', 'invoke_calls', 'styles' }, chain.select)
		local conditions = chain.where[1]
		self:assertEquals('or', conditions.op)
		self:assertDeepEquals({ 'requires', 'Module:Mbox' }, conditions[1])
		self:assertDeepEquals({ 'loads', 'Module:Mbox' }, conditions[2])
		self:assertDeepEquals({ 'invokes', 'Module:Mbox' }, conditions[3])
		self:assertDeepEquals({ 'styles', 'Module:Mbox/styles.css' }, conditions[4])
	end)
end

-- <summary> is the disclosure's click target: a link inside it follows the link
-- instead of opening the panel.
function suite:testSummaryHoldsNoLink()
	local rows = { { page_name = 'Module:Hatnote', requires = { 'Module:Mbox' } } }
	render(fakeTitle('Module:Mbox', 828, MBOX_SRC), {}, rows, function()
		local html = dependencies.panel({ sources = { { label = 'wiki-tools', text = 'Synced' } } })
		local summary = summaryOf(html)
		self:assertStringContains('wiki-tools · used by 1', summary, true)
		self:assertNotStringContains('[[', summary, true)
		self:assertNotStringContains('<a ', summary, true)
	end)
end

function suite:testUnusedModulePanel()
	render(fakeTitle('Module:Lonely', 828, "local x = require('Module:Icon')"), {}, {}, function()
		local html = dependencies.panel()
		self:assertStringContains('Unused', summaryOf(html), true)
		self:assertStringContains('No template invokes it', html, true)
		self:assertStringContains('[[Category:Unused modules]]', html, true)
	end)
end

function suite:testFailedLookupClaimsNothing()
	render(fakeTitle('Module:Mbox', 828, MBOX_SRC), {}, {}, function()
		bucketLib._failNext = true
		local html = dependencies.panel()
		self:assertStringContains('Unavailable', html, true)
		self:assertStringContains('uses 2', summaryOf(html), true)
		self:assertNotStringContains('used by', summaryOf(html), true)
		self:assertNotStringContains('Unused', html, true)
		self:assertNotStringContains('[[Category:Unused modules]]', html, true)
	end)
end

function suite:testNonTableResultClaimsNothing()
	render(fakeTitle('Module:Lonely', 828, "local x = require('Module:Icon')"), {}, {}, function()
		bucketLib._setRows('dependencies', 'broken')
		local html = dependencies.panel()
		self:assertNotStringContains('Unused', html, true)
		self:assertNotStringContains('[[Category:Unused modules]]', html, true)
	end)
end

function suite:testTemplatePanel()
	render(fakeTitle('Template:Outdated', 10, OUTDATED_SRC), {}, {}, function()
		local html = dependencies.panel()
		self:assertStringContains('<code>record</code> in [[Module:Maintenance]]', html, true)
		self:assertStringContains('<code>main</code> in [[Module:Mbox]]', html, true)
		self:assertStringContains('uses 2', summaryOf(html), true)
		self:assertNotStringContains('Used by', html, true)
		self:assertNotStringContains('Functions', html, true)
		self:assertStringContains('[[Category:Lua-based templates]]', html, true)
	end)
end

function suite:testStylesheetUsers()
	local rows = {
		{ page_name = 'Module:BadgeLua', styles = { 'Module:Icon/styles.css' } },
		{ page_name = 'Module:Icon', styles = { 'Module:Icon/styles.css' } },
	}
	render(fakeTitle('Module:Icon', 828, ICON_SRC), {}, rows, function()
		local html = dependencies.panel()
		self:assertStringContains('No template invokes it', html, true)
		self:assertStringContains('Styles used by', html, true)
		self:assertStringContains('[[Module:BadgeLua|BadgeLua]]', html, true)
		self:assertStringContains('[[Module:Icon/styles.css|/styles.css]]', html, true)
	end)
end

function suite:testTemplateStylesheetUsers()
	local rows = { { page_name = 'Template:Infobox Item', styles = { 'Template:InfoboxOld/styles.css' } } }
	local src = '<templatestyles src="Template:InfoboxOld/styles.css" />'
	render(fakeTitle('Template:InfoboxOld', 10, src), {}, rows, function()
		local html = dependencies.panel()
		self:assertStringContains('[[Template:InfoboxOld/styles.css|/styles.css]]', html, true)
		self:assertStringContains('[[Template:Infobox Item|Infobox Item]]', html, true)
		self:assertStringContains('used by 1 · uses 1', summaryOf(html), true)
	end)
end

function suite:testFunctionsRow()
	render(fakeTitle('Module:Icon', 828, ICON_SRC), {}, {}, function()
		self:assertStringContains('[[Module:Icon#L-2|p.main]]', dependencies.panel(), true)
	end)
end

function suite:testSourceRowAlone()
	render(fakeTitle('Template:Plain', 10, 'Hello'), {}, {}, function()
		local html = dependencies.panel({ sources = { { label = 'wiki-tools', text = 'Synced' } } })
		self:assertStringContains('<div>Synced</div>', html, true)
		self:assertStringContains('wiki-tools', summaryOf(html), true)
	end)
end

function suite:testSourcesShareOneRow()
	render(fakeTitle('Template:Plain', 10, 'Hello'), {}, {}, function()
		local html = dependencies.panel({
			sources = {
				{ label = 'wiki-tools', text = 'Synced' },
				{ label = 'from Wikipedia', text = 'Imported' },
			},
		})
		self:assertStringContains('<div>Synced</div><div>Imported</div>', html, true)
		self:assertStringContains('wiki-tools · from Wikipedia', summaryOf(html), true)
		local _, rowCount = html:gsub('t%-dependencies__row"', '')
		self:assertEquals(1, rowCount)
	end)
end

function suite:testNothingToShowRendersNothing()
	render(fakeTitle('Template:Plain', 10, 'Hello'), {}, {}, function()
		self:assertEquals('', dependencies.panel())
	end)
end

function suite:testDocRenderHasNoCategories()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	local doc = fakeTitle('Module:Mbox/doc', 828, 'Docs.')
	doc.basePageTitle = mbox
	render(doc, {}, {}, function()
		self:assertNotStringContains('[[Category:', dependencies.panel(), true)
	end)
end

function suite:testDynamicRequireIsListedNotStored()
	render(fakeTitle('Module:Kinds', 828, "local kind = require('Module:Entity/' .. name)"), {}, {}, function()
		local html = dependencies.panel()
		self:assertStringContains('<code>Module:Entity/…</code>', html, true)
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testRowOrder()
	local rows = { { page_name = 'Module:BadgeLua', requires = { 'Module:Icon' } } }
	render(fakeTitle('Module:Icon', 828, ICON_SRC), {}, rows, function()
		local html = dependencies.panel({ sources = { { label = 'wiki-tools', text = 'Synced' } } })
		local last = 0
		for _, label in ipairs({ 'Source</div>', 'Used by</div>', 'Uses</div>', 'Functions</div>' }) do
			local at = html:find(label, 1, true)
			self:assertTrue(at ~= nil and at > last, label .. ' out of order')
			last = at
		end
	end)
end

function suite:testCategoriesCanBeTurnedOff()
	render(fakeTitle('Module:Lonely', 828, "require('strict')"), {}, {}, function()
		self:assertNotStringContains('[[Category:', dependencies.panel({ addCategories = 'no' }), true)
	end)
end

function suite:testSourcesOutsideModuleAndTemplate()
	render(fakeTitle('Help:Editing', 12, 'Text'), {}, {}, function()
		local html = dependencies.panel({ sources = { { label = 'wiki-tools', text = 'Synced' } } })
		self:assertStringContains('<div>Synced</div>', html, true)
		self:assertNotStringContains('Used by', html, true)
		self:assertEquals(0, #bucketLib._puts)
	end)
end

--- The Bucket fields `title`'s manifest declares, as a set.
--- @param title string
--- @return table<string, boolean>
local function manifestFields(title)
	local fields = {}
	for _, def in pairs(mw.loadJsonData(title)) do
		if type(def) == 'table' and def.field then
			fields[def.field] = true
		end
	end
	return fields
end

-- The row's keys are written by hand, not read from the manifest, and write() puts
-- it inside pcall: a key the manifest (and so the generated Bucket schema) lacks
-- would fail without any error on the page.
function suite:testRowKeysAreManifestFields()
	local fields = manifestFields('Module:Dependencies/properties.json')
	local row = dependencies._internal.rowFor({
		requires = { 'Module:A' },
		loads = { 'Module:A/data.json' },
		invokes = { { module = 'Module:B', func = 'main' } },
		styles = { 'Module:B/styles.css' },
	})
	local keys = 0
	for key in pairs(row) do
		keys = keys + 1
		self:assertTrue(
			fields[key] == true,
			"row key '" .. key .. "' is not a field of Module:Dependencies/properties.json"
		)
	end
	self:assertTrue(keys > 0)
end

return suite
