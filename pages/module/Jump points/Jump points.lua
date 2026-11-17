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
	local stringUtil = _bundler_load('_XQt31IWCZw6yESgwQW4U')

	--- Starmap tunnel codes, lowercased
	local DIRECTION = { b = 'Bidirectional', u = 'Unidirectional' }
	local SIZE = { s = 'Small', m = 'Medium', l = 'Large' }

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
			return 'Invalid or missing parameters.'
		end

		local children = Starmap.systemObjects(systemName)
		if not children then
			return 'Data was unable to be retrieved.'
		end

		local hasJumppoints = false

		local wikitable = '{| class="wikitable"\n!Jump gate\n!Direction\n!Size\n!Destination\n'

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
				local direction = object.tunnel.direction
				local size = object.tunnel.size

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
					.. (DIRECTION[string.lower(direction)] or direction)
					.. '\n'
					-- Size
					.. '|'
					.. (SIZE[string.lower(size)] or size)
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
			return string.format('There are no known [[Jump point|jump points]] to or from %s.', systemName)
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
