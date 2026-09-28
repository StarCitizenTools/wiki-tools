require('strict')

--- @module Module toc
--- The functions a Lua module defines and the line each starts on. Imported from
--- https://runescape.wiki/w/Module:Module_toc.

-- <nowiki>
local p = {}

--- @class ModuleTocFunction
--- @field name string
--- @field line integer

--- @param content string
--- @return integer[] byte positions of every newline, ascending
local function newlinePositions(content)
	local positions = {}
	local pos = string.find(content, '\n', 1, true)
	while pos do
		positions[#positions + 1] = pos
		pos = string.find(content, '\n', pos + 1, true)
	end
	return positions
end

--- The 1-based line holding byte `pos`: one more than the newlines before it.
--- @param pos integer
--- @param newlines integer[]
--- @return integer
local function lineAt(pos, newlines)
	local low, high = 0, #newlines
	while low < high do
		local mid = math.floor((low + high + 1) / 2)
		if newlines[mid] < pos then
			low = mid
		else
			high = mid - 1
		end
	end
	return low + 1
end

--- @param content string
--- @return ModuleTocFunction[]
local function findFunctions(content)
	local found = {}
	local newlines = newlinePositions(content)
	for _, pattern in ipairs({
		'%sfunction%s+([^%s%(]+)%s*%(()',
		'%s([%w_%.]+)%s*=%s*function%s*%(()',
	}) do
		for name, pos in string.gmatch(content, pattern) do
			found[#found + 1] = { name = name, line = lineAt(pos, newlines) }
		end
	end
	return found
end

--- The functions `content` defines, in line order. Comments are blanked first,
--- keeping their newlines so later line numbers stay right.
--- @param content string Lua source
--- @return ModuleTocFunction[]
function p.functions(content)
	local function keepNewlines(comment)
		return string.rep('\n', #newlinePositions(comment))
	end
	local stripped = content:gsub('(%-%-%[(=-)%[.-%]%2%])', keepNewlines):gsub('%-%-[^\n]*', '')
	local found = findFunctions(stripped)
	table.sort(found, function(a, b)
		return a.line < b.line
	end)
	return found
end

return p
-- </nowiki>
