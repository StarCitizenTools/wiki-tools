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

local MBOX_SRC = "require('strict')\nlocal details = require('Module:Details')\nlocal icon = require('Module:Icon')"
local OUTDATED_SRC = '{{#invoke:Mbox|main|type=warning}}{{#invoke:Maintenance|record}}'
local ICON_SRC =
	"local p = {}\nfunction p.main()\n\treturn mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })\nend\nreturn p"

function suite:testModuleWritesItsRow()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	render(mbox, {}, {}, function()
		dependencies._main()
		self:assertEquals(1, #bucketLib._puts)
		self:assertEquals('dependencies', bucketLib._puts[1].bucket)
		self:assertDeepEquals({ 'Module:Details', 'Module:Icon' }, bucketLib._puts[1].data.requires)
		self:assertEquals(nil, bucketLib._puts[1].data.loads)
	end)
end

function suite:testTemplateWritesInvokes()
	local outdated = fakeTitle('Template:Outdated', 10, OUTDATED_SRC)
	render(outdated, {}, {}, function()
		dependencies._main()
		local data = bucketLib._puts[1].data
		self:assertDeepEquals({ 'Module:Maintenance', 'Module:Mbox' }, data.invokes)
		self:assertDeepEquals({ 'Module:Maintenance|record', 'Module:Mbox|main' }, data.invoke_calls)
	end)
end

function suite:testRowCarriesStylesheets()
	render(fakeTitle('Module:Icon', 828, ICON_SRC), {}, {}, function()
		dependencies._main()
		self:assertDeepEquals({ 'Module:Icon/styles.css' }, bucketLib._puts[1].data.styles)
	end)
end

function suite:testDocRenderDoesNotWrite()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	local doc = fakeTitle('Module:Mbox/doc', 828, 'Docs.')
	doc.basePageTitle = mbox
	render(doc, {}, {}, function()
		dependencies._main()
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testSandboxAndTestcasesDoNotWrite()
	for _, name in ipairs({ 'Module:Mbox/sandbox', 'Module:Mbox/testcases', 'Module:Sandbox/User/Mbox' }) do
		render(fakeTitle(name, 828, MBOX_SRC), {}, {}, function()
			dependencies._main()
			self:assertEquals(0, #bucketLib._puts, name)
		end)
	end
end

function suite:testExplicitOtherPageDoesNotWrite()
	local current = fakeTitle('Module:A', 828, '')
	local other = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	render(current, { ['Module:Mbox'] = other }, {}, function()
		dependencies._main('Module:Mbox')
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testNoDependenciesNoRow()
	render(fakeTitle('Module:Lonely', 828, 'local p = {}\nreturn p'), {}, {}, function()
		dependencies._main()
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testGroupSplitsDependentsByKind()
	local back = dependencies._internal.group({
		{
			page_name = 'Template:Outdated',
			invokes = { 'Module:Mbox' },
			invoke_calls = { 'Module:Mbox|main', 'Module:Other|x' },
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
	self:assertDeepEquals({ { page = 'Template:Outdated', funcs = { 'main' } } }, back.invokedBy)
	self:assertDeepEquals({ 'Module:Hatnote' }, back.requiredBy)
	self:assertDeepEquals({ 'Module:Data user' }, back.loadedBy)
	self:assertDeepEquals({ 'Module:BadgeLua' }, back.styledBy)
end

function suite:testModulePageListsItsDependents()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	local rows = {
		{ page_name = 'Template:Outdated', invokes = { 'Module:Mbox' }, invoke_calls = { 'Module:Mbox|main' } },
		{ page_name = 'Module:Hatnote', requires = { 'Module:Mbox' } },
	}
	render(mbox, {}, rows, function()
		local html = dependencies._main()
		self:assertStringContains('Module:Mbox requires [[Module:Details]] and [[Module:Icon]].', html, true)
		self:assertStringContains('Module:Mbox is invoked by [[Template:Outdated]] (<code>main</code>).', html, true)
		self:assertStringContains('Module:Mbox is required by [[Module:Hatnote]].', html, true)
		self:assertNotStringContains('This module is unused.', html, true)
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

function suite:testUnusedModuleIsFlagged()
	render(fakeTitle('Module:Lonely', 828, "local x = require('Module:Icon')"), {}, {}, function()
		local html = dependencies._main()
		self:assertStringContains('This module is unused.', html, true)
		self:assertStringContains('[[Category:Unused modules]]', html, true)
	end)
end

function suite:testFailedLookupClaimsNothing()
	render(fakeTitle('Module:Mbox', 828, MBOX_SRC), {}, {}, function()
		bucketLib._failNext = true
		local html = dependencies._main()
		self:assertStringContains('Module:Mbox requires', html, true)
		self:assertNotStringContains('This module is unused.', html, true)
		self:assertNotStringContains('is required by', html, true)
	end)
end

function suite:testNonTableResultClaimsNothing()
	render(fakeTitle('Module:Lonely', 828, "local x = require('Module:Icon')"), {}, {}, function()
		bucketLib._setRows('dependencies', 'broken')
		local html = dependencies._main()
		self:assertNotStringContains('This module is unused.', html, true)
		self:assertNotStringContains('[[Category:Unused modules]]', html, true)
	end)
end

function suite:testTemplateShowsInvokesAndCategory()
	render(fakeTitle('Template:Outdated', 10, OUTDATED_SRC), {}, {}, function()
		local html = dependencies._main()
		self:assertStringContains(
			'Template:Outdated invokes <code>record</code> in [[Module:Maintenance]] and <code>main</code> in [[Module:Mbox]].',
			html,
			true
		)
		self:assertStringContains('[[Category:Lua-based templates]]', html, true)
	end)
end

function suite:testSharedStylesheetListsItsUsers()
	local rows = {
		{ page_name = 'Module:BadgeLua', styles = { 'Module:Icon/styles.css' } },
		{ page_name = 'Module:Icon', styles = { 'Module:Icon/styles.css' } },
	}
	render(fakeTitle('Module:Icon', 828, ICON_SRC), {}, rows, function()
		local html = dependencies._main()
		self:assertStringContains('Module:Icon uses styles from [[Module:Icon/styles.css]].', html, true)
		self:assertStringContains('[[Module:Icon/styles.css]] is also used by [[Module:BadgeLua]].', html, true)
		local chain = queryChain()
		self:assertDeepEquals({ 'page_name', 'requires', 'loads', 'invokes', 'invoke_calls', 'styles' }, chain.select)
		local conditions = chain.where[1]
		self:assertEquals('or', conditions.op)
		self:assertDeepEquals({ 'requires', 'Module:Icon' }, conditions[1])
		self:assertDeepEquals({ 'loads', 'Module:Icon' }, conditions[2])
		self:assertDeepEquals({ 'invokes', 'Module:Icon' }, conditions[3])
		self:assertDeepEquals({ 'styles', 'Module:Icon/styles.css' }, conditions[4])
	end)
end

function suite:testTemplateStylesheetUsers()
	local rows = { { page_name = 'Template:Infobox Item', styles = { 'Template:InfoboxOld/styles.css' } } }
	local src = '<templatestyles src="Template:InfoboxOld/styles.css" />'
	render(fakeTitle('Template:InfoboxOld', 10, src), {}, rows, function()
		local html = dependencies._main()
		self:assertStringContains(
			'Template:InfoboxOld uses styles from [[Template:InfoboxOld/styles.css]].',
			html,
			true
		)
		self:assertStringContains(
			'[[Template:InfoboxOld/styles.css]] is also used by [[Template:Infobox Item]].',
			html,
			true
		)
	end)
end

function suite:testStylesheetUsedOnlyByOthers()
	local rows = { { page_name = 'Module:Cite RSI', styles = { 'Module:Cite/styles.css' } } }
	render(fakeTitle('Module:Cite', 828, 'local p = {}\nreturn p'), {}, rows, function()
		self:assertStringContains(
			'[[Module:Cite/styles.css]] is used by [[Module:Cite RSI]].',
			dependencies._main(),
			true
		)
	end)
end

function suite:testDocRenderHasNoCategories()
	local mbox = fakeTitle('Module:Mbox', 828, MBOX_SRC)
	local doc = fakeTitle('Module:Mbox/doc', 828, 'Docs.')
	doc.basePageTitle = mbox
	render(doc, {}, {}, function()
		self:assertNotStringContains('[[Category:', dependencies._main(), true)
	end)
end

function suite:testLongListRendersAsABox()
	local rows = {}
	for i = 1, 6 do
		rows[i] = { page_name = 'Module:User' .. i, requires = { 'Module:Mbox' } }
	end
	render(fakeTitle('Module:Mbox', 828, MBOX_SRC), {}, rows, function()
		local html = dependencies._main()
		self:assertStringContains('Module:Mbox is required by 6 modules.', html, true)
		self:assertStringContains('* [[Module:User1]]', html, true)
	end)
end

function suite:testDynamicRequireIsListedNotStored()
	render(fakeTitle('Module:Kinds', 828, "local kind = require('Module:Entity/' .. name)"), {}, {}, function()
		local html = dependencies._main()
		self:assertStringContains('<code>Module:Entity/…</code>', html, true)
		self:assertEquals(0, #bucketLib._puts)
	end)
end

return suite
