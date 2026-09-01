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

-- `kind=bar` opts a column into the signed-bar rendering, and `good=` names the
-- direction that helps; both are plain clauses like label= and size=.
function suite:testParseColumnsBarClauses()
	local cols = dg.parseColumns('Modifier resistance ; label=Resistance ; kind=bar ; good=lower')
	self:assertEquals(1, #cols)
	self:assertEquals('Modifier resistance', cols[1].property)
	self:assertEquals('Resistance', cols[1].label)
	self:assertEquals('bar', cols[1].kind)
	self:assertEquals('lower', cols[1].good)
	-- good is optional: an undirected bar column parses fine without it.
	self:assertEquals(nil, dg.parseColumns('X ; kind=bar')[1].good)
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

function suite:testParseColumnsKindClause()
	local cols = dg.parseColumns('Effects ; kind=effect')
	self:assertEquals('Effects', cols[1].property)
	self:assertEquals('effect', cols[1].kind)
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

-- A conditions-only query (no category) drops the category clause but keeps the
-- main-namespace restriction. This is the {{Manufacturer products}} path.
function suite:testBuildQueryConditionsOnly()
	local q = dg.buildQuery('', dg.parseColumns('Item type'), '[[Manufacturer::ArcCorp]]')
	self:assertEquals('[[:+]] [[Manufacturer::ArcCorp]]', q[1])
end

function suite:testBuildQueryNilCategoryWithConditions()
	local q = dg.buildQuery(nil, dg.parseColumns('Item type'), '[[Manufacturer::ArcCorp]]')
	self:assertEquals('[[:+]] [[Manufacturer::ArcCorp]]', q[1])
end

-- Degenerate guard: neither category nor conditions leaves the bare namespace
-- restriction. `main` rejects this combination before it can reach a query.
function suite:testBuildQueryNoCategoryNoConditions()
	self:assertEquals('[[:+]]', dg.buildQuery('', dg.parseColumns('Item type'))[1])
end

-- eyebrow flag (promotes a column into the lead card's eyebrow)

function suite:testParseColumnsEyebrowFlag()
	self:assertEquals(true, dg.parseColumns('Manufacturer ; eyebrow')[1].eyebrow)
end

function suite:testParseColumnsEyebrowWithOtherModifiers()
	local col = dg.parseColumns('Manufacturer ; label=Maker ; eyebrow')[1]
	self:assertEquals('Manufacturer', col.property)
	self:assertEquals('Maker', col.label)
	self:assertEquals(true, col.eyebrow)
end

function suite:testParseColumnsNoEyebrowByDefault()
	self:assertEquals(nil, dg.parseColumns('Size')[1].eyebrow)
end

return suite
