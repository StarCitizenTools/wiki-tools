require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local moduleToc = require('Module:Module toc')

local suite = ScribuntoUnit:new()

function suite:testDeclaredAndAssignedFunctionsInLineOrder()
	local src = 'local p = {}\n\n'
		.. 'function p.main(frame)\nend\n\n'
		.. 'local function helper(a)\nend\n\n'
		.. 'p.alias = function()\nend\n\n'
		.. 'return p\n'
	self:assertDeepEquals({
		{ name = 'p.main', line = 3 },
		{ name = 'helper', line = 6 },
		{ name = 'p.alias', line = 9 },
	}, moduleToc.functions(src))
end

function suite:testCommentsAreIgnoredAndKeepTheirLines()
	local src = 'local p = {}\n--[[\nfunction fake()\n]]\nlocal function real()\nend\n-- function alsoFake()\n'
	self:assertDeepEquals({ { name = 'real', line = 5 } }, moduleToc.functions(src))
end

-- A signature wrapped after its "(" puts a newline right at the match position.
function suite:testWrappedSignature()
	local src = 'local p = {}\nfunction p.long(\n\ta,\n\tb\n)\nend\nreturn p\n'
	self:assertDeepEquals({ { name = 'p.long', line = 2 } }, moduleToc.functions(src))
end

function suite:testLastLineWithoutNewline()
	self:assertDeepEquals(
		{ { name = 'last', line = 2 } },
		moduleToc.functions('local p = {}\nlocal function last() end')
	)
end

function suite:testNoFunctions()
	self:assertDeepEquals({}, moduleToc.functions('return { a = 1 }\n'))
end

return suite
