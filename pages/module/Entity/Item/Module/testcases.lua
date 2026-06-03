require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Module = require('Module:Entity/Item/Module')
local item = require('Module:Entity/Item')
local helpers = Module._internal

-- An item shaped like the Aurora Mk II DM Module: type Module, owning a
-- vehicle set via related_items.set_name.
local function moduleWithSet()
	return {
		name = 'Aurora Mk II DM Module',
		type = 'Module',
		related_items = { set_name = 'Aurora Mk II' },
	}
end

-- resolveSetName

function suite:testResolveSetNamePresent()
	self:assertEquals('Aurora Mk II', helpers.resolveSetName(moduleWithSet()))
end

function suite:testResolveSetNameMissingRelatedItems()
	self:assertEquals(nil, helpers.resolveSetName({ name = 'X' }))
end

function suite:testResolveSetNameMissingSetName()
	self:assertEquals(nil, helpers.resolveSetName({ related_items = {} }))
end

function suite:testResolveSetNameEmptyString()
	self:assertEquals(nil, helpers.resolveSetName({ related_items = { set_name = '' } }))
end

function suite:testResolveSetNameNonTableRelated()
	self:assertEquals(nil, helpers.resolveSetName({ related_items = 'nope' }))
	self:assertEquals(nil, helpers.resolveSetName(nil))
end

-- getTypeInfo

function suite:testGetTypeInfoWithSet()
	local info = Module.getTypeInfo(moduleWithSet(), {})
	self:assertEquals('Vehicle module', info.name)
	self:assertEquals('Aurora Mk II', info.category)
end

function suite:testGetTypeInfoWithoutSet()
	local info = Module.getTypeInfo({ type = 'Module' }, {})
	self:assertEquals('Module', info.name)
	self:assertEquals('Modules', info.category)
end

-- getSections

function suite:testGetSectionsWithSet()
	local sections = Module.getSections(moduleWithSet(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('general', sections[1].key)
	self:assertEquals(1, #sections[1].items)
	self:assertEquals('Vehicle', sections[1].items[1].label)
	self:assertEquals('[[Aurora Mk II]]', sections[1].items[1].content)
end

function suite:testGetSectionsWithoutSet()
	self:assertEquals(0, #Module.getSections({ type = 'Module' }, {}))
end

-- getShortDescription

function suite:testGetShortDescriptionWithSet()
	local apiData = moduleWithSet()
	local typeInfo = Module.getTypeInfo(apiData, {})
	self:assertEquals('Vehicle module for the Aurora Mk II', Module.getShortDescription(apiData, {}, typeInfo, nil))
end

function suite:testGetShortDescriptionWithoutSetDelegatesToItem()
	-- No set → defer to Item's "<type> by <manufacturer>" composer. Assert it
	-- matches Item's own output for the same inputs (delegation), rather than
	-- hard-coding the composed string.
	local apiData = { type = 'Module' }
	local typeInfo = Module.getTypeInfo(apiData, {})
	local expected = item.getShortDescription(apiData, {}, typeInfo, nil)
	self:assertEquals(expected, Module.getShortDescription(apiData, {}, typeInfo, nil))
end

-- getStructuredData

function suite:testGetStructuredDataWithSet()
	self:assertEquals('Aurora Mk II', Module.getStructuredData(moduleWithSet(), {}).vehicle)
end

function suite:testGetStructuredDataWithoutSet()
	self:assertEquals(nil, Module.getStructuredData({ type = 'Module' }, {}).vehicle)
end

return suite
