-- <nowiki>
local hatnote = require('Module:Hatnote')._hatnote
local mbox = require('Module:Mbox')._mbox
local i18n = require('Module:i18n'):new()
local TNT = require('Module:Translate'):new()
local lang = mw.getContentLanguage()
local p = {}

--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t(key)
	return i18n:translate(key)
end

--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate(key, ...)
	local success, translation = pcall(TNT.format, 'Module:Documentation/i18n.json', key or '', ...)

	if not success or translation == nil then
		return key
	end

	return translation
end

--- The Source row lines of the Technical details panel: where the page is
--- maintained (`git=`) and where it came from (`fromWikipedia=`).
--- @param args table the {{Documentation}} arguments
--- @param pageType string 'module' or 'template'
--- @param rootText string
--- @param page string the documented page
--- @return table[] DependenciesSource[]
local function sources(args, pageType, rootText, page)
	local list = {}
	if args.git then
		local repoUrl = 'https://github.com/StarCitizenTools/wiki-tools/tree/main/pages/'
			.. pageType
			.. '/'
			.. mw.uri.encode(rootText, 'PATH')
		list[#list + 1] = {
			label = 'wiki-tools',
			text = 'Synced with [' .. repoUrl .. ' wiki-tools] on GitHub',
		}
	end
	if args.fromWikipedia then
		list[#list + 1] = {
			label = 'from Wikipedia',
			text = 'Imported from [https://en.wikipedia.org/wiki/' .. mw.uri.encode(page, 'WIKI') .. ' Wikipedia]',
		}
	end
	return list
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

function p.doc(frame)
	local title = mw.title.getCurrentTitle()
	local args = frame:getParent().args
	local page = args[1] or string.gsub(title.fullText, '/[Dd]o[ck]u?$', '')
	local ret, cats, ret1, ret2, ret3
	local pageType = title.namespace == 828 and 'module' or 'template'
	local sourceLines = sources(args, pageType, title.rootText, page)

	-- subpage header
	if title.subpageText == 'doc' then
		ret = mbox(
			translate('message_subpage_title', page),
			translate('message_subpage_desc', page, translate(pageType)),
			{ icon = 'WikimediaUI-Notice.svg' }
		)

		if title.namespace == 10 or title.namespace == 828 then
			cats = '[[Category:'
				.. string.format(t('category_documentation'), t('category_' .. pageType))
				.. '|'
				.. title.baseText
				.. ']]'
			ret2 = technicalDetails({ sources = sourceLines })
		else
			cats = ''
			ret2 = ''
		end

		return tostring(ret) .. ret2 .. cats
	end

	-- template header
	-- don't use mw.html as we aren't closing the main div tag
	ret1 = '<div class="documentation">'

	ret2 = mw.html
		.create(nil)
		:tag('div')
		:addClass('documentation-header')
		:tag('span')
		:addClass('documentation-title')
		:wikitext(lang:ucfirst(translate('message_documentation_title', pageType)))
		:done()
		:tag('span')
		:addClass('documentation-links plainlinks')
		:wikitext(
			'[['
				.. tostring(mw.uri.fullUrl(page .. '/doc', { action = 'view' }))
				.. ' view]]'
				.. '[['
				.. tostring(mw.uri.fullUrl(page .. '/doc', { action = 'edit' }))
				.. ' edit]]'
				.. '[['
				.. tostring(mw.uri.fullUrl(page .. '/doc', { action = 'history' }))
				.. ' history]]'
				.. '[<span class="jsPurgeLink">['
				.. tostring(mw.uri.fullUrl(title.fullText, { action = 'purge' }))
				.. ' purge]</span>]'
		)
		:done()
		:done()
		:tag('div')
		:addClass('documentation-subheader')
		:tag('span')
		:addClass('documentation-documentation')
		:wikitext(translate('message_transclude_desc', page))
		:done()
		:wikitext(frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:Documentation/styles.css' } }))
		:done()

	ret3 = {}

	if args.fromWikipedia then
		table.insert(
			ret3,
			'[[Category:' .. string.format(t('category_imported_from_wikipedia'), lang:ucfirst(pageType)) .. ']]'
		)
	end

	if title.namespace == 828 then
		-- Testcase page
		if title.subpageText == 'testcases' then
			table.insert(
				ret3,
				hatnote(translate('message_module_tests', title.baseText), { icon = 'WikimediaUI-LabFlask.svg' })
			)
		end

		table.insert(ret3, string.format('[[Category:%s]]', t('category_module')))
	end

	table.insert(ret3, technicalDetails({ addCategories = args.category, sources = sourceLines }))

	if title.namespace == 828 then
		-- Unit tests
		local testcaseTitle = title.text .. '/testcases'
		if mw.title.new(testcaseTitle, 'Module').exists then
			-- There is probably a better way :P
			table.insert(ret3, frame:preprocess('{{#invoke:' .. testcaseTitle .. '|run}}'))
		end
	end

	return ret1 .. tostring(ret2) .. '<div class="documentation-content">' .. table.concat(ret3) .. '</div>'
end

return p

-- </nowiki>
