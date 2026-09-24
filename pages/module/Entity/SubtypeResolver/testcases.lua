require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local SubtypeResolver = require('Module:Entity/SubtypeResolver')

local suite = ScribuntoUnit:new()

-- Loaders around real, requirable modules keep the test offline-safe.
local MAP = {
	ship = function()
		return require('Module:Entity/Vehicle/Ship')
	end,
	ground = function()
		return require('Module:Entity/Vehicle/GroundVehicle')
	end,
}

function suite:testResolvesMappedToken()
	self:assertEquals(require('Module:Entity/Vehicle/Ship'), SubtypeResolver.resolve('ship', MAP))
end

function suite:testNilWhenUnmapped()
	self:assertEquals(nil, SubtypeResolver.resolve('nope', MAP))
end

function suite:testNilWhenTokenNilOrEmpty()
	self:assertEquals(nil, SubtypeResolver.resolve(nil, MAP))
	self:assertEquals(nil, SubtypeResolver.resolve('', MAP))
end

function suite:testLoadsOnlyTheSelectedLeaf()
	local loaded = {}
	local map = {
		a = function()
			loaded[#loaded + 1] = 'a'
			return {}
		end,
		b = function()
			loaded[#loaded + 1] = 'b'
			return {}
		end,
	}
	SubtypeResolver.resolve('a', map)
	self:assertDeepEquals({ 'a' }, loaded)
end

function suite:testFamilyArgNormalizes()
	self:assertEquals('jumppoint', SubtypeResolver.familyArg({ family = ' JumpPoint ' }))
	self:assertEquals('ship', SubtypeResolver.familyArg({ family = 'ship' }))
end

function suite:testFamilyArgNilWhenAbsentBlankOrNotString()
	self:assertEquals(nil, SubtypeResolver.familyArg(nil))
	self:assertEquals(nil, SubtypeResolver.familyArg({}))
	self:assertEquals(nil, SubtypeResolver.familyArg({ family = '  ' }))
	self:assertEquals(nil, SubtypeResolver.familyArg({ family = 42 }))
end

return suite
