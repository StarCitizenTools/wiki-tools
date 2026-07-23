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

function suite:testSplitCamelHandlesUnderscores()
	-- Snake_Case slugs (like the Char_Armor_* family) get underscore→space
	-- humanisation, then camelCase splitting. Used as the last-resort
	-- fallback when types.json doesn't have the slug.
	self:assertEquals('Char Armor Backpack', helpers.splitCamel('Char_Armor_Backpack'))
	self:assertEquals('FPS Deployable', helpers.splitCamel('FPS_Deployable'))
end

-- itemTypeCategory (internal — Module:Entity/Item/types.json lookup)

function suite:testItemTypeCategoryHit()
	-- A type slug catalogued in Module:Entity/Item/types.json. Returns
	-- the canonical plural category label.
	self:assertEquals('Backpacks', helpers.itemTypeCategory('Char_Armor_Backpack'))
	self:assertEquals('Personal weapons', helpers.itemTypeCategory('WeaponPersonal'))
	self:assertEquals('Gadgets', helpers.itemTypeCategory('Gadget'))
end

function suite:testItemTypeCategoryMiss()
	self:assertEquals(nil, helpers.itemTypeCategory('SomeNewTypeCIGAdded'))
end

function suite:testItemTypeCategoryNilSafe()
	self:assertEquals(nil, helpers.itemTypeCategory(nil))
	self:assertEquals(nil, helpers.itemTypeCategory(''))
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

function suite:testDeriveLabelFallsBackToItemTypeCategory()
	-- Item endpoint, no category_label, no typeAlias — falls through to
	-- the canonical wiki vocabulary (Module:Entity/Item/types.json).
	-- This is the fix for the "Char_Armor_Backpack appeared as a card
	-- title" bug.
	self:assertEquals('Backpacks', categories.deriveLabel({ type = 'Char_Armor_Backpack' }, {}))
	-- Same via bareCompat extraction (type=null, first compat is dotted).
	self:assertEquals('Personal weapons', categories.deriveLabel({}, { 'WeaponPersonal.Medium' }))
end

function suite:testDeriveLabelTypeAliasBeatsItemTypeCategory()
	-- typeAliases in categories.json wins over types.json so the
	-- vehicle-routing overrides stand. WeaponGun: types.json says "Guns",
	-- typeAlias says "Weapons" — alias wins.
	self:assertEquals('Weapons', categories.deriveLabel({ type = 'WeaponGun' }, {}))
end

function suite:testDeriveLabelSalvageHeadAliasesToMiningSalvage()
	-- Salvage heads are children of salvage arms / remote turrets. Aliasing
	-- SalvageHead → "Mining & Salvage" routes them under that card and lets
	-- them inherit its expandIntoTypes (so the head's SalvageModifier modules
	-- expand). types.json says "Salvage beams"; the alias wins.
	self:assertEquals('Mining & Salvage', categories.deriveLabel({ type = 'SalvageHead' }, {}))
end

function suite:testLookupMiningSalvageHasExpandAllowlist()
	-- Mining & Salvage carries an expandIntoTypes allowlist so salvage arms /
	-- mining arms surface their heads + modules in the L-tree.
	local c = categories.lookup('Mining & Salvage')
	self:assertEquals(false, c.collapsed)
	self:assertNotEquals(nil, c.expandIntoTypes)
end

function suite:testDeriveLabelFallsBackToSplitCamel()
	-- Type not in typeAliases AND not in types.json — synthesize a primary
	-- label from the type slug itself.
	local label = categories.deriveLabel({ type = 'SomeNewThing' }, {})
	self:assertEquals('Some New Thing', label)
end

function suite:testDeriveLabelSplitCamelHandlesSnakeCase()
	-- Truly unknown snake_Case slug — splitCamel humanises underscores too.
	local label = categories.deriveLabel({ type = 'Char_Helmet_Visor' }, {})
	self:assertEquals('Char Helmet Visor', label)
end

function suite:testDeriveLabelOther()
	-- Nothing usable at all.
	local label = categories.deriveLabel({}, {})
	self:assertEquals('Other', label)
end

return suite
