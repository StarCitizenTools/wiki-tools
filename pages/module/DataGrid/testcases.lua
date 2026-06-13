require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local dg = require('Module:DataGrid')

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- parseColumns (carried over from Module:DataTableLua)

function suite:testParseColumnsEmpty()
	self:assertEquals(0, #dg.parseColumns(''))
	self:assertEquals(0, #dg.parseColumns(nil))
end

function suite:testParseColumnsBareProperty()
	local cols = dg.parseColumns('Size')
	self:assertEquals(1, #cols)
	self:assertEquals('Size', cols[1].property)
	self:assertEquals(nil, cols[1].label)
	self:assertEquals(nil, cols[1].filter)
end

function suite:testParseColumnsLabel()
	local cols = dg.parseColumns('Subtype ; label=Type')
	self:assertEquals('Subtype', cols[1].property)
	self:assertEquals('Type', cols[1].label)
end

function suite:testParseColumnsFilterFlag()
	self:assertEquals(true, dg.parseColumns('Manufacturer ; filter')[1].filter)
end

function suite:testParseColumnsSpacingStyles()
	self:assertEquals('Size', dg.parseColumns('Size ; filter')[1].property)
	self:assertEquals('Size', dg.parseColumns('Size;filter')[1].property)
	self:assertEquals(true, dg.parseColumns('Size;filter')[1].filter)
end

function suite:testParseColumnsMultilineOrderAndBlanks()
	local cols = dg.parseColumns('\n  Size ; filter\n\n  Subtype ; label=Type\n  Class\n')
	self:assertEquals(3, #cols)
	self:assertEquals('Size', cols[1].property)
	self:assertEquals('Subtype', cols[2].property)
	self:assertEquals('Class', cols[3].property)
end

function suite:testParseColumnsDropsEmptyProperty()
	local cols = dg.parseColumns('; filter\nSize')
	self:assertEquals(1, #cols)
	self:assertEquals('Size', cols[1].property)
end

-- columnAlias

function suite:testColumnAliasUsesLabel()
	self:assertEquals('Type', dg.columnAlias({ property = 'Subtype', label = 'Type' }))
end

function suite:testColumnAliasFallsBackToProperty()
	self:assertEquals('Class', dg.columnAlias({ property = 'Class' }))
end

-- duplicateAlias

function suite:testDuplicateAliasNoneWhenUnique()
	self:assertEquals(nil, dg.duplicateAlias(dg.parseColumns('Size\nClass')))
end

function suite:testDuplicateAliasDetectsRepeat()
	self:assertEquals('Size', dg.duplicateAlias(dg.parseColumns('Size\nSize')))
end

-- A column aliasing to a reserved lead key (Name or Image) collides with the lead.
function suite:testDuplicateAliasDetectsLeadCollision()
	self:assertEquals('Name', dg.duplicateAlias(dg.parseColumns('Foo ; label=Name')))
	self:assertEquals('Image', dg.duplicateAlias(dg.parseColumns('Bar ; label=Image')))
end

-- buildQuery

function suite:testBuildQueryCondition()
	self:assertEquals('[[:+]] [[Category:Guns]]', dg.buildQuery('Guns', dg.parseColumns('Size'))[1])
end

function suite:testBuildQueryLeadPrintouts()
	local q = dg.buildQuery('Guns', dg.parseColumns('Size'))
	self:assertTrue(contains(q, '?Page Image=Image'))
	self:assertTrue(contains(q, '?=Name'))
end

function suite:testBuildQueryAlwaysAliasesColumns()
	local q = dg.buildQuery('X', dg.parseColumns('Subtype ; label=Type\nClass'))
	self:assertTrue(contains(q, '?Subtype=Type'))
	self:assertTrue(contains(q, '?Class=Class'))
end

function suite:testBuildQueryFixedOptions()
	local q = dg.buildQuery('X', dg.parseColumns('Size'))
	self:assertTrue(contains(q, 'mainlabel=-'))
	self:assertTrue(contains(q, 'limit=1000'))
end

function suite:testBuildQueryAppendsConditions()
	local q = dg.buildQuery('Guns', dg.parseColumns('Size'), '[[Damage type::Laser]]')
	self:assertEquals('[[:+]] [[Category:Guns]] [[Damage type::Laser]]', q[1])
end

function suite:testBuildQueryNilConditionsUnchanged()
	self:assertEquals('[[:+]] [[Category:Guns]]', dg.buildQuery('Guns', dg.parseColumns('Size'), nil)[1])
end

function suite:testBuildQueryEmptyConditionsUnchanged()
	self:assertEquals('[[:+]] [[Category:Guns]]', dg.buildQuery('Guns', dg.parseColumns('Size'), '')[1])
end

return suite
