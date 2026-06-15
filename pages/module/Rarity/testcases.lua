require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Rarity = require('Module:Rarity')

local suite = ScribuntoUnit:new()

function suite:testResolveKnown()
	local r = Rarity._internal.resolve('Rare')
	self:assertEquals('Rare', r.label)
	self:assertEquals('rarity-badge--rare', r.class)
end

function suite:testResolveCaseAndWhitespace()
	self:assertEquals('rarity-badge--epic', Rarity._internal.resolve('EPIC').class)
	self:assertEquals('rarity-badge--legendary', Rarity._internal.resolve('  legendary  ').class)
end

function suite:testResolveUnknown()
	self:assertEquals(nil, Rarity._internal.resolve('Mythic'))
	self:assertEquals(nil, Rarity._internal.resolve(''))
	self:assertEquals(nil, Rarity._internal.resolve(nil))
end

function suite:testBadgeUnknownReturnsNil()
	self:assertEquals(nil, Rarity.badge('Mythic'))
	self:assertEquals(nil, Rarity.badge(nil))
end

function suite:testBadgeKnownIncludesLabel()
	local b = Rarity.badge('Rare')
	self:assertEquals('string', type(b))
	self:assertEquals(true, b:find('Rare', 1, true) ~= nil)
end

return suite
