require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local documentation = require('Module:Documentation')

local suite = ScribuntoUnit:new()

local internal = documentation._internal

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

return suite
