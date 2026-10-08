require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local parse = require('Module:Dependencies/Parse')

local suite = ScribuntoUnit:new()

function suite:testRequireLiteralsSortedAndUnique()
	local found = parse.lua(
		"local a = require('Module:Icon')\nlocal b = require(\"Module:Details\")\nlocal c = require('Module:Icon')"
	)
	self:assertDeepEquals({ 'Module:Details', 'Module:Icon' }, found.requires)
end

function suite:testRequireWithoutParentheses()
	self:assertDeepEquals({ 'Module:Icon' }, parse.lua("local icon = require 'Module:Icon'").requires)
end

function suite:testPcallRequire()
	self:assertDeepEquals({ 'Module:Icon' }, parse.lua("local ok, icon = pcall(require, 'Module:Icon')").requires)
end

function suite:testRequireThroughAStringVariable()
	self:assertDeepEquals(
		{ 'Module:Icon' },
		parse.lua("local NAME = 'Module:Icon'\nlocal icon = require(NAME)").requires
	)
end

function suite:testNormalisesNamespaceAndFirstLetter()
	self:assertDeepEquals({ 'Module:Icon' }, parse.lua("require('module:icon')").requires)
end

function suite:testBuiltinsAreNotModulesButStrictIsFlagged()
	local found = parse.lua("require('strict')\nlocal util = require('libraryUtil')")
	self:assertDeepEquals({}, found.requires)
	self:assertTrue(found.strict)
end

function suite:testStrictFlagOffWithoutStrict()
	self:assertFalse(parse.lua("require('Module:Icon')").strict)
end

function suite:testLoadDataAndLoadJsonData()
	local found = parse.lua("local a = mw.loadData('Module:A/data')\nlocal b = mw.loadJsonData('Module:B/data.json')")
	self:assertDeepEquals({ 'Module:A/data', 'Module:B/data.json' }, found.loads)
	self:assertDeepEquals({}, found.requires)
end

function suite:testDynamicRequireIsAPatternNotARequire()
	local found = parse.lua("local kind = require('Module:Entity/' .. name)")
	self:assertDeepEquals({ 'Module:Entity/…' }, found.dynamic)
	self:assertDeepEquals({}, found.requires)
end

function suite:testDynamicRequireWithNoLiteralAfterNamespaceIsDropped()
	self:assertDeepEquals({}, parse.lua("local m = require('Module:' .. name)").dynamic)
end

function suite:testConcatenatedLiteralsAreARequire()
	self:assertDeepEquals({ 'Module:Entity/Base' }, parse.lua("require('Module:Entity/' .. 'Base')").requires)
end

function suite:testCommentsAreIgnored()
	local src =
		"-- require('Module:A')\n--[[ require('Module:B') ]]\n--[==[ require('Module:C') ]==]\nrequire('Module:D')"
	self:assertDeepEquals({ 'Module:D' }, parse.lua(src).requires)
end

function suite:testIdentifierEndingInRequireIsNotACall()
	self:assertDeepEquals({}, parse.lua("local function myrequire(x) end\nmyrequire('Module:A')").requires)
end

function suite:testMethodNamedRequireIsNotACall()
	local src = "local x = loader.require('Module:A')\nlocal y = loader:require('Module:B')"
	self:assertDeepEquals({}, parse.lua(src).requires)
end

function suite:testInvokeBasic()
	self:assertDeepEquals({ { module = 'Module:Mbox', func = 'main' } }, parse.invokes('{{#invoke:Mbox|main|title=x}}'))
end

function suite:testInvokeCaseAndSpacing()
	self:assertDeepEquals({ { module = 'Module:Mbox', func = 'main' } }, parse.invokes('{{ #Invoke: Mbox | main }}'))
end

function suite:testInvokeSubst()
	self:assertDeepEquals(
		{ { module = 'Module:Mbox', func = 'main' } },
		parse.invokes('{{safesubst:#invoke:Mbox|main}}')
	)
end

function suite:testInvokeSafesubstParameterIdiom()
	self:assertDeepEquals(
		{ { module = 'Module:Key', func = 'keypress' } },
		parse.invokes('{{{{{|safesubst:}}}#invoke:key|keypress}}')
	)
end

function suite:testInvokeUppercaseSafesubstWithNoinclude()
	self:assertDeepEquals(
		{ { module = 'Module:Ordinal', func = 'ordinal' } },
		parse.invokes('{{SAFESUBST:<noinclude />#invoke:Ordinal|ordinal}}')
	)
end

function suite:testInvokeSafesubstInsideIncludeonly()
	self:assertDeepEquals(
		{ { module = 'Module:Delink', func = 'delink' } },
		parse.invokes('{{<includeonly>safesubst:</includeonly>#invoke:delink|delink}}')
	)
end

function suite:testInvokeModulePrefixAndLowercase()
	self:assertDeepEquals({ { module = 'Module:Mbox', func = 'main' } }, parse.invokes('{{#invoke:Module:mbox|main}}'))
end

function suite:testInvokeParameterFunctionKeptVerbatim()
	self:assertDeepEquals({ { module = 'Module:Mbox', func = '{{{1}}}' } }, parse.invokes('{{#invoke:Mbox|{{{1}}}}}'))
end

function suite:testInvokesSortedAndUnique()
	local calls = parse.invokes('{{#invoke:B|x}}{{#invoke:A|y}}{{#invoke:B|x}}')
	self:assertDeepEquals({ { module = 'Module:A', func = 'y' }, { module = 'Module:B', func = 'x' } }, calls)
end

function suite:testInvokeWithParameterModuleIsSkipped()
	self:assertDeepEquals({}, parse.invokes('{{#invoke:{{{module}}}|main}}'))
end

function suite:testInvokeInHtmlCommentIgnored()
	self:assertDeepEquals({}, parse.invokes('<!-- {{#invoke:Mbox|main}} -->'))
end

function suite:testLuaStylesheetLiteral()
	local src =
		"local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = 'Module:Icon/styles.css' } })"
	self:assertDeepEquals({ 'Module:Icon/styles.css' }, parse.lua(src).styles)
end

function suite:testLuaStylesheetTableCallAndConstant()
	local src =
		"local STYLES = 'Module:RangeBar/styles.css'\nlocal s = frame:extensionTag{ name = 'templatestyles', args = { src = STYLES } }"
	self:assertDeepEquals({ 'Module:RangeBar/styles.css' }, parse.lua(src).styles)
end

function suite:testLuaPositionalExtensionTag()
	local src = "frame:extensionTag('templatestyles', '', { src = 'Module:Cite/styles.css' })"
	self:assertDeepEquals({ 'Module:Cite/styles.css' }, parse.lua(src).styles)
end

function suite:testLuaOtherExtensionTagIgnored()
	self:assertDeepEquals({}, parse.lua("frame:extensionTag({ name = 'ref', args = { src = 'x' } })").styles)
end

function suite:testLuaTagInAStringLiteral()
	local src = 'local s = \'<templatestyles src="Module:Mbox/styles.css" />\''
	self:assertDeepEquals({ 'Module:Mbox/styles.css' }, parse.lua(src).styles)
end

function suite:testWikitextStylesheetTags()
	local text = '<templatestyles src="Template:License/styles.css" /><TemplateStyles src=\'module:cite/styles.css\'/>'
	self:assertDeepEquals({ 'Module:Cite/styles.css', 'Template:License/styles.css' }, parse.styles(text))
end

function suite:testStylesheetWithoutNamespaceIsATemplatePage()
	self:assertDeepEquals({ 'Template:Hlist/styles.css' }, parse.styles('<templatestyles src=Hlist/styles.css />'))
end

function suite:testStylesheetInHtmlCommentIgnored()
	self:assertDeepEquals({}, parse.styles('<!-- <templatestyles src="A/styles.css" /> -->'))
end

function suite:testStylesheetWithMissingClosingQuoteIsMalformed()
	self:assertDeepEquals({}, parse.styles('<templatestyles src="Template:Spoiler box/styles.css/>'))
end

-- Files

function suite:testLuaFileLiterals()
	local src = 'local ICON = \'WikimediaUI-Code.svg\'\nlocal ROW = { source = "CdxIconReference.svg" }'
	self:assertDeepEquals({ 'CdxIconReference.svg', 'WikimediaUI-Code.svg' }, parse.lua(src).files.names)
end

function suite:testLuaFileNamesAreNormalised()
	local src = "local a = 'File:placeholder_v2.png'\nlocal b = 'Placeholder v2.png'\nlocal c = 'Photo.JPG'"
	self:assertDeepEquals({ 'Photo.JPG', 'Placeholder v2.png' }, parse.lua(src).files.names)
end

function suite:testLuaStringsThatAreNotFiles()
	local src = "local a = 'Technical details'\nlocal b = mw.loadJsonData('Module:X/data.json')\n"
		.. "local c = name:gsub('%.svg$', '')\nlocal d = 'https://example.com/a.png'"
	self:assertDeepEquals({}, parse.lua(src).files.names)
end

function suite:testLuaFileInCommentIgnored()
	local src = "-- 'A.svg'\n--[[ 'B.svg' ]]\n--[==[ 'C.svg' ]==]\nlocal d = 'D.svg'"
	self:assertDeepEquals({ 'D.svg' }, parse.lua(src).files.names)
end

-- A CSS custom property inside a string starts with `--`, which is not a comment there.
function suite:testLuaDoubleDashInsideAStringIsNotAComment()
	local src = "local style = '--t-icon-url: \"%s\";'\nlocal icon = 'Sc-icon-uec.svg'"
	self:assertDeepEquals({ 'Sc-icon-uec.svg' }, parse.lua(src).files.names)
end

function suite:testLuaEscapedQuoteKeepsLaterStrings()
	self:assertDeepEquals({ 'E.svg' }, parse.lua("local a = 'It\\'s'\nlocal b = 'E.svg'").files.names)
end

function suite:testLuaLongStringHoldingWikitext()
	self:assertDeepEquals({ 'Logo.png' }, parse.lua('local s = [=[ [[File:Logo.png|20px]] ]=]').files.names)
end

function suite:testLuaNameBuiltAtRuntime()
	local found = parse.lua("eyebrow.icon = aggrid.thumb('File:Sc-icon-brand-' .. info.code .. '.svg', 20)").files
	self:assertDeepEquals({ 'Sc-icon-brand-….svg' }, found.dynamic)
	self:assertDeepEquals({}, found.names)
end

function suite:testLuaRuntimeNameWithNoLiteralTextIsDropped()
	local found = parse.lua("local file = name .. '.svg'").files
	self:assertDeepEquals({}, found.dynamic)
	self:assertDeepEquals({}, found.names)
end

function suite:testLuaConcatenatedLiteralsAreAName()
	self:assertDeepEquals({ 'Logo.svg' }, parse.lua("local file = 'Logo' .. '.svg'").files.names)
end

function suite:testLuaMediaUrl()
	local found = parse.lua("local css = 'url(https://media.starcitizen.tools/e/e8/CdxIconSuccess.svg)'").files
	self:assertDeepEquals({ 'CdxIconSuccess.svg' }, found.names)
	self:assertDeepEquals({ { name = 'CdxIconSuccess.svg', path = 'e/e8' } }, found.urls)
end

function suite:testLuaFilesSortedAndUnique()
	self:assertDeepEquals({ 'A.svg', 'B.svg' }, parse.lua("x = 'B.svg'\ny = 'A.svg'\nz = 'File:B.svg'").files.names)
end

function suite:testWikitextFiles()
	local text = '[[File:Foo.svg|20px]] [[image:bar.png]]\n{{#invoke:Mbox|main\n|icon=WikimediaUI-Alert.svg\n}}'
		.. '{{{image|Default.png}}}<span data-icon="Quoted.svg"></span>'
	self:assertDeepEquals(
		{ 'Bar.png', 'Default.png', 'Foo.svg', 'Quoted.svg', 'WikimediaUI-Alert.svg' },
		parse.files(text).names
	)
end

function suite:testWikitextWithoutFiles()
	self:assertDeepEquals({}, parse.files('This page uses no files. See [[Help:Images]].').names)
	self:assertDeepEquals({}, parse.files('<!-- [[File:Old.png]] -->').names)
end

function suite:testWikitextMediaUrl()
	local found = parse.files('[https://media.starcitizen.tools/4/40/RSItm.svg RSI]')
	self:assertDeepEquals({ 'RSItm.svg' }, found.names)
	self:assertDeepEquals({ { name = 'RSItm.svg', path = '4/40' } }, found.urls)
end

function suite:testStylesheetFiles()
	local css = '.a { mask-image: url(https://media.starcitizen.tools/e/e8/CdxIconSuccess.svg); }\n'
		.. '.b { mask-image: url("https://media.starcitizen.tools/f/ff/Icon_faction_reputation_r0.svg"); }\n'
		.. '.c { background-image: url( https://media.starcitizen.tools/4/40/RSItm.svg ); }'
	local found = parse.stylesheetFiles(css)
	self:assertDeepEquals({ 'CdxIconSuccess.svg', 'Icon faction reputation r0.svg', 'RSItm.svg' }, found.names)
	self:assertDeepEquals({
		{ name = 'CdxIconSuccess.svg', path = 'e/e8' },
		{ name = 'Icon faction reputation r0.svg', path = 'f/ff' },
		{ name = 'RSItm.svg', path = '4/40' },
	}, found.urls)
end

function suite:testStylesheetUrlIsDecoded()
	local found = parse.stylesheetFiles('a { background: url(https://media.starcitizen.tools/a/ab/Bad%27name.jpg) }')
	self:assertDeepEquals({ "Bad'name.jpg" }, found.names)
end

function suite:testStylesheetThumbnailUrl()
	local css = 'a { background: url(https://media.starcitizen.tools/thumb/e/e8/X.svg/20px-X.svg.png) }'
	self:assertDeepEquals({ { name = 'X.svg', path = 'e/e8' } }, parse.stylesheetFiles(css).urls)
end

function suite:testStylesheetCommentIgnored()
	local css = '/* url(https://media.starcitizen.tools/e/e8/A.svg) or Special:FilePath/B.svg */ a { color: red; }'
	self:assertDeepEquals({}, parse.stylesheetFiles(css).names)
end

function suite:testLuaFormatPatternIsANameBuiltAtRuntime()
	local src = "local a = string.format('[[File:sc-icon-brand-%s.svg|36px|link=]]', code)\n"
		.. "local b = ('[[File:WikimediaUI-%s-ltr.svg|14px|link=]]'):format(dir)"
	local found = parse.lua(src).files
	self:assertDeepEquals({ 'Sc-icon-brand-….svg', 'WikimediaUI-…-ltr.svg' }, found.dynamic)
	self:assertDeepEquals({}, found.names)
end

-- A Lua pattern holds a `%` that is not a format directive.
function suite:testLuaPatternIsNotAFormat()
	local found = parse.lua("local base = name:match('^(.-)%.svg$')\nlocal s = ('%d%%.png'):format(n)").files
	self:assertDeepEquals({}, found.dynamic)
	self:assertDeepEquals({}, found.names)
end

function suite:testLuaRuntimeNameWithACallInTheMiddle()
	local found = parse.lua("local file = 'Sc-icon-' .. info.code:lower() .. '.svg'").files
	self:assertDeepEquals({ 'Sc-icon-….svg' }, found.dynamic)
end

function suite:testLuaRuntimeNameKeepsOnlyTheFileName()
	self:assertDeepEquals({}, parse.lua("local arg = '|icon=' .. name .. '.svg'").files.dynamic)
end

-- Not valid Lua, but the parser must not throw on any source.
function suite:testLuaLeadingConcatenationDoesNotThrow()
	self:assertDeepEquals({ 'B.svg' }, parse.lua(".. 'B.svg'").files.names)
end

function suite:testMediaUrlEndsAtWikitextSyntax()
	local url = 'https://media.starcitizen.tools/4/40/RSItm.svg'
	for _, text in ipairs({
		'[' .. url .. ']',
		'{{X|url=' .. url .. '|y=1}}',
		'{{X|' .. url .. '}}',
		'<ref>' .. url .. '</ref>',
	}) do
		self:assertDeepEquals({ 'RSItm.svg' }, parse.files(text).names, text)
	end
end

function suite:testQuotedAttributeFollowedByAnother()
	self:assertDeepEquals({ 'X.svg' }, parse.files('<span data-icon="X.svg" class="y"></span>').names)
end

return suite
