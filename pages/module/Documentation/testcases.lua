require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local documentation = require('Module:Documentation')

local suite = ScribuntoUnit:new()

local internal = documentation._internal

--- A title shaped like mw.title's, for the fields Documentation and Dependencies read.
local function fakeTitle(prefixed, namespace)
	local text = (prefixed:gsub('^[^:]+:', ''))
	local title = {
		prefixedText = prefixed,
		fullText = prefixed,
		namespace = namespace,
		text = text,
		rootText = text:match('^[^/]+'),
		baseText = text:match('^(.*)/[^/]+$') or text,
		subpageText = text:match('/([^/]+)$') or text,
		isSubpage = text:find('/', 1, true) ~= nil,
	}
	function title.getContent()
		return nil
	end
	return title
end

--- doc() rendered for `current`, with `args` as the {{Documentation}} arguments.
local function doc(current, args)
	local realCurrent, realNew = mw.title.getCurrentTitle, mw.title.new
	mw.title.getCurrentTitle = function()
		return current
	end
	mw.title.new = function()
		return { exists = false }
	end
	local frame = {
		getParent = function()
			return { args = args or {} }
		end,
		extensionTag = function()
			return ''
		end,
		preprocess = function()
			return ''
		end,
	}
	local ok, out = pcall(documentation.doc, frame)
	mw.title.getCurrentTitle, mw.title.new = realCurrent, realNew
	if not ok then
		error(out, 0)
	end
	return out
end

function suite:testLinkText()
	self:assertEquals(
		'RuneScape Wiki',
		internal.linkText('[https://runescape.wiki/w/Module:Module_toc RuneScape Wiki]')
	)
	self:assertEquals('Hatnote', internal.linkText('[[Module:Hatnote|Hatnote]]'))
	self:assertEquals('Module:Hatnote', internal.linkText('[[Module:Hatnote]]'))
	self:assertEquals('elsewhere', internal.linkText('elsewhere'))
end

function suite:testGitSourceLinksTheRootDirectory()
	self:assertDeepEquals({
		{
			label = 'wiki-tools',
			text = 'Synced with [https://github.com/StarCitizenTools/wiki-tools/tree/main/pages/module/Module%20toc wiki-tools] on GitHub',
		},
	}, internal.sources({ git = 'true' }, 'module', 'Module toc', 'Module:Module toc'))
end

function suite:testImportedFrom()
	local link = '[https://runescape.wiki/w/Module:Module_toc RuneScape Wiki]'
	self:assertDeepEquals(
		{ { label = 'from RuneScape Wiki', text = 'Imported from ' .. link } },
		internal.sources({ importedFrom = link }, 'module', 'Module toc', 'Module:Module toc')
	)
end

function suite:testFromWikipediaIsShorthandForTheSameTitle()
	self:assertDeepEquals({
		{
			label = 'wiki-tools',
			text = 'Synced with [https://github.com/StarCitizenTools/wiki-tools/tree/main/pages/template/Hello%20world wiki-tools] on GitHub',
		},
		{
			label = 'from Wikipedia',
			text = 'Imported from [https://en.wikipedia.org/wiki/Template:Hello_world Wikipedia]',
		},
	}, internal.sources({ git = 'true', fromWikipedia = 'true' }, 'template', 'Hello world', 'Template:Hello world'))
end

function suite:testImportedFromWinsAndBlankIsIgnored()
	local link = '[https://example.org/x Example]'
	self:assertEquals(
		'Imported from ' .. link,
		internal.sources({ importedFrom = link, fromWikipedia = 'true' }, 'module', 'X', 'Module:X')[1].text
	)
	self:assertDeepEquals({}, internal.sources({ importedFrom = '' }, 'module', 'X', 'Module:X'))
end

function suite:testCategories()
	self:assertEquals('[[Category:Modules]]', internal.categories('module', false, 'Mbox', false))
	self:assertEquals(
		'[[Category:Modules]][[Category:Imported modules]]',
		internal.categories('module', false, 'Hatnote', true)
	)
	self:assertEquals('[[Category:Imported templates]]', internal.categories('template', false, 'About', true))
	self:assertEquals('', internal.categories('template', false, 'Badge', false))
	self:assertEquals('[[Category:Modules documentation|Mbox]]', internal.categories('module', true, 'Mbox', false))
	self:assertEquals(
		'[[Category:Templates documentation|Badge]]',
		internal.categories('template', true, 'Badge', true)
	)
end

function suite:testBareUrlLabelIsNotLinked()
	local label = internal.sources({ importedFrom = 'https://example.org/x' }, 'module', 'X', 'Module:X')[1].label
	self:assertNotStringContains('://', label, true)
end

function suite:testModulePage()
	local out = doc(fakeTitle('Module:Mbox', 828), { git = 'true' })
	self:assertStringContains('<div class="t-documentation t-documentation--git">', out, true)
	self:assertStringContains('From [[Module:Mbox/doc]]', out, true)
	self:assertStringContains('[button Edit -> Special:EditPage/Module:Mbox/doc (', out, true)
	self:assertStringContains('[button History -> Special:PageHistory/Module:Mbox/doc (', out, true)
	self:assertStringContains('[button Purge -> Special:Purge/Module:Mbox (', out, true)
	self:assertStringContains('[[Category:Modules]]', out, true)
	self:assertNotStringContains('documentation|', out, true)
end

function suite:testDocSubpage()
	local current = fakeTitle('Module:Mbox/doc', 828)
	current.basePageTitle = fakeTitle('Module:Mbox', 828)
	local out = doc(current, { git = 'true' })
	self:assertStringContains('Documentation subpage', out, true)
	self:assertStringContains('Shown on [[Module:Mbox]]', out, true)
	self:assertStringContains('[button Back to the module -> Module:Mbox (', out, true)
	self:assertStringContains('[[Category:Modules documentation|Mbox]]', out, true)
	self:assertNotStringContains('[[Category:Modules]]', out, true)
end

function suite:testFlagsReadAsYesNo()
	local out = doc(fakeTitle('Module:Mbox', 828), { git = 'no', fromWikipedia = '' })
	self:assertStringContains('<div class="t-documentation">', out, true)
	self:assertNotStringContains('wiki-tools', out, true)
	self:assertNotStringContains('Imported', out, true)
end

function suite:testBlankFirstArgumentFallsBackToTheTitle()
	self:assertStringContains('From [[Module:Mbox/doc]]', doc(fakeTitle('Module:Mbox', 828), { [1] = '' }), true)
end

function suite:testNoCategoriesOutsideModuleAndTemplate()
	self:assertNotStringContains('[[Category:', doc(fakeTitle('User:Someone', 2), { git = 'true' }), true)
end

return suite
