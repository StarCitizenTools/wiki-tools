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

--- A failure in Module:Dependencies, or a module it requires, must not break
--- every documentation page: require and render it inside a pcall.
--- @param pageName string|nil
--- @param addCategories boolean|string|nil
--- @return string
local function dependencyNotices(pageName, addCategories)
	local ok, result = pcall(function()
		return require('Module:Dependencies')._main(pageName, addCategories)
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

	-- subpage header
	if title.subpageText == 'doc' then
		ret = mbox(
			translate('message_subpage_title', page),
			translate('message_subpage_desc', page, translate(pageType)),
			{ icon = 'WikimediaUI-Notice.svg' }
		)

		if title.namespace == 10 then -- Template namespace
			cats = '[[Category:'
				.. string.format(t('category_documentation'), t('category_' .. pageType))
				.. '|'
				.. title.baseText
				.. ']]'
			ret2 = dependencyNotices()
		elseif title.namespace == 828 then -- Module namespace
			cats = '[[Category:'
				.. string.format(t('category_documentation'), t('category_' .. pageType))
				.. '|'
				.. title.baseText
				.. ']]'
			ret2 = dependencyNotices()
			ret2 = ret2 .. require('Module:Module toc').main()
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

	if args.git then
		local repoUrl = 'https://github.com/StarCitizenTools/wiki-tools/tree/main/pages/'
			.. pageType
			.. '/'
			.. mw.uri.encode(title.rootText, 'PATH')

		table.insert(
			ret3,
			mbox(
				"'''" .. page .. "''' is maintained in the [" .. repoUrl .. ' wiki-tools] repository on GitHub.',
				'This '
					.. pageType
					.. ' is synced from the Git repository. Any on-wiki changes should also be made in GitHub, otherwise they may be overwritten on the next deployment.',
				{ icon = 'WikimediaUI-Code.svg' }
			)
		)
	end

	if args.fromWikipedia then
		table.insert(
			ret3,
			mbox(
				translate('message_from_wikipedia', title.fullText, mw.uri.encode(page, 'WIKI'), page),
				translate('message_from_wikipedia_subtext', pageType),
				{ icon = 'WikimediaUI-Logo-Wikipedia.svg' }
			)
		)
		--- Set category
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

	--- Dependency list
	table.insert(ret3, dependencyNotices(nil, args.category))

	--- Module stats bar
	if title.namespace == 828 then
		-- Function list
		table.insert(ret3, require('Module:Module toc').main())

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
