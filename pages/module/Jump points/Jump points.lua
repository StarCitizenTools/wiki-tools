-- Laid out as https://github.com/ari-party/scribunto-bundler output. This file is
-- the source: edit the registered chunks in place rather than re-bundling the
-- upstream https://github.com/ari-party/sct-module-jump-points over it.
local _bundler_load, _bundler_register = (function(superRequire)
	local loadingPlaceholder = { [{}] = true }

	local register
	local modules = {}

	local load
	local loaded = {}

	---@param name string
	---@param body function
	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	---@param name string
	---@return any
	load = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '"' .. name .. '"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name]()
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return load, register
end)(require)

_bundler_register('bundler_main', function()
	local JumpPoints = {}

	local Starmap = require('Module:Starmap')
	local systemShortName = require('Module:Entity/Location/Starmap').systemShortName
	local t = _bundler_load('jf3ffit_xZz7x9bGp9eHd')
	local stringUtil = _bundler_load('_XQt31IWCZw6yESgwQW4U')

	--- A gate's name and page title. Gate pages are titled
	--- "<Entry> - <Destination> jump point" with each system in its short form,
	--- so each side of the starmap designation loses its decorations: an alias
	--- parenthetical ("Kyuk'ya (Indra)") or the Vanduul catalogue form
	--- (VS-9 "Vulture"), neither of which is in a page title.
	---@param designation string
	---@return string name
	---@return string page
	local function gate(designation)
		local name = stringUtil.clean(designation)
		local entry, exit = name:match('^(.-)%s+%-%s+(.+)$')
		if entry then
			name = (systemShortName(entry) or entry) .. ' - ' .. (systemShortName(exit) or exit)
		else
			name = stringUtil.removeParentheses(name)
		end
		return name, name .. ' jump point'
	end

	---@param frame table https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
	function JumpPoints.main(frame)
		local parent = frame:getParent()
		local args = parent.args

		local systemName = args[1] or string.gsub(mw.title.getCurrentTitle().text, ' system$', '')
		if not systemName then
			return t('error_invalid_args')
		end

		local children = Starmap.systemObjects(systemName)
		if not children then
			return t('error_no_data')
		end

		local hasJumppoints = false

		local wikitable = '{| class="wikitable"\n'
			.. '!'
			.. t('lbl_jumpgate')
			.. '\n'
			.. '!'
			.. t('lbl_direction')
			.. '\n'
			.. '!'
			.. t('lbl_size')
			.. '\n'
			.. '!'
			.. t('lbl_destination')
			.. '\n'

		for _, object in ipairs(children) do
			if object.type == 'JUMPPOINT' then
				hasJumppoints = true

				local exitObject = object.tunnel.exit
				-- Make sure the exit is not the current object
				if exitObject.code == object.code then
					exitObject = object.tunnel.entry
				end

				local exitName, exitPage = gate(exitObject.designation)
				local exitLink = '[[' .. exitPage .. '|' .. exitName .. ']]'
				local fromName, fromPage = gate(object.designation)

				wikitable = wikitable
					.. '|-\n'
					-- From this system
					.. '|[['
					.. fromPage
					.. '|'
					.. fromName
					.. ']]\n'
					-- Direction
					.. '|'
					.. t('val_direction_' .. string.lower(object.tunnel.direction))
					.. '\n'
					-- Size
					.. '|'
					.. t('val_size_' .. string.lower(object.tunnel.size))
					.. '\n'
					-- Path to target system's gate
					.. '|'
					.. exitLink
					.. ', '
					.. stringUtil.lowerFirst(
						stringUtil.clean(
							Starmap.inSystem(
								Starmap.findStructure(
									'system',
									Starmap.findStructure('object', exitObject.code).star_system.code
								)
							)
						)
					)
					.. '\n'
			end
		end

		wikitable = wikitable .. '|}'

		if hasJumppoints then
			return wikitable
		else
			return string.format(t('lbl_none'), systemName)
		end
	end

	function JumpPoints.test(page)
		return JumpPoints.main({
			getParent = function()
				return {
					args = { page },
				}
			end,
		})
	end

	return JumpPoints
end)

_bundler_register('jf3ffit_xZz7x9bGp9eHd', function()
	local TNT = require('Module:Translate'):new()
	local config = mw.loadJsonData('Module:Jump points/config.json')

	local lang
	if config.module_lang then
		lang = mw.getLanguage(config.module_lang)
	else
		lang = mw.getContentLanguage()
	end
	local langCode = lang:getCode()

	--- Wrapper function for Module:Translate.translate
	---@param key string The translation key
	---@param addSuffix? boolean Adds a language suffix if config.smw_multilingual_text is true
	---@return string value If the key was not found in the .tab page, the key is returned
	return function(key, addSuffix, ...)
		return TNT:translate('Module:Jump points/i18n.json', config, key, addSuffix, { ... }) or key
	end
end)

_bundler_register('_XQt31IWCZw6yESgwQW4U', function()
	local Common = require('Module:Common')

	local StringUtil = {
		removeParentheses = Common.removeParentheses,
	}

	--- Replace obnoxious characters
	---@param str string Input string
	---@return string
	function StringUtil.clean(str)
		local apostrophe = string.gsub(str, '’', "'")
		return apostrophe
	end

	--- Lower first character
	---@param str string Input string
	---@return string
	function StringUtil.lowerFirst(str)
		return string.lower(string.sub(str, 1, 1)) .. string.sub(str, 2)
	end

	return StringUtil
end)

return _bundler_load('bundler_main')
