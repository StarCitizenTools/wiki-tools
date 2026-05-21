require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local categories = require('Module:Entity/Ports/Categories')
local helpers = categories._internal

-- splitCamel (internal)

function suite:testSplitCamelTwoWords()
	self:assertEquals('Manneuver Thruster', helpers.splitCamel('ManneuverThruster'))
end

function suite:testSplitCamelSingleWord()
	self:assertEquals('Turret', helpers.splitCamel('Turret'))
end

function suite:testSplitCamelEmpty()
	self:assertEquals('', helpers.splitCamel(''))
	self:assertEquals('', helpers.splitCamel(nil))
end

-- categories.lookup

function suite:testLookupPrimaryLabel()
	-- A label from HardpointCategory.php's primary list.
	local c = categories.lookup('Manned Turrets')
	self:assertEquals('Manned Turrets', c.label)
	self:assertEquals(10, c.order)
	self:assertEquals(false, c.collapsed)
	self:assertNotEquals(nil, c.expandIntoTypes)
end

function suite:testLookupCollapsedLabel()
	-- A label from HardpointCategory.php's collapsed list.
	local c = categories.lookup('Controllers')
	self:assertEquals('Controllers', c.label)
	self:assertEquals(true, c.collapsed)
end

function suite:testLookupUnknownLabel()
	-- A label not present in categories.json — primary, order 999, fail-open.
	local c = categories.lookup('SomeNewCategoryCIGAdded')
	self:assertEquals('SomeNewCategoryCIGAdded', c.label)
	self:assertEquals(999, c.order)
	self:assertEquals(false, c.collapsed)
end

function suite:testLookupEmpty()
	local c = categories.lookup('')
	self:assertEquals('Other', c.label)
	self:assertEquals(true, c.collapsed)
end

function suite:testLookupNil()
	local c = categories.lookup(nil)
	self:assertEquals('Other', c.label)
	self:assertEquals(true, c.collapsed)
end

-- categories.deriveLabel

function suite:testDeriveLabelFromApiCategoryLabel()
	-- Vehicle endpoint case: API supplies category_label directly.
	local label = categories.deriveLabel({ category_label = 'Manned Turrets', type = 'TurretBase' }, {})
	self:assertEquals('Manned Turrets', label)
end

function suite:testDeriveLabelFallsBackToTypeAlias()
	-- Item endpoint case: no category_label, but type matches a typeAlias.
	local label = categories.deriveLabel({ type = 'WeaponAttachment' }, {})
	self:assertEquals('Weapon attachments', label)
end

function suite:testDeriveLabelFallsBackToCompatAlias()
	-- M4A Cannon-style port: type is empty, compat resolves via typeAlias.
	local label = categories.deriveLabel({}, { 'WeaponAttachment.Barrel' })
	self:assertEquals('Weapon attachments', label)
end

function suite:testDeriveLabelFallsBackToSplitCamel()
	-- Unaliased type — synthesize a primary label from the type itself.
	local label = categories.deriveLabel({ type = 'SomeNewThing' }, {})
	self:assertEquals('Some New Thing', label)
end

function suite:testDeriveLabelOther()
	-- Nothing usable at all.
	local label = categories.deriveLabel({}, {})
	self:assertEquals('Other', label)
end

return suite
