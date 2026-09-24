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

return suite
