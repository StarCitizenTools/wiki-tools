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

-- Consecutive columns sharing a group nest under one header; a run ends as soon
-- as the group changes, so a group is a POSITION and never silently reorders.
function suite:testGroupColumnDefsNestsRuns()
	local defs = { { field = 'lead' }, { field = 'c1' }, { field = 'c2' }, { field = 'c3' }, { field = 'c4' } }
	local groups = { false, 'Rock', 'Rock', 'Charge', false }
	local out = dg._internal.groupColumnDefs(defs, groups)
	self:assertEquals(4, #out)
	self:assertEquals('lead', out[1].field)
	self:assertEquals('Rock', out[2].headerName)
	self:assertEquals(2, #out[2].children)
	self:assertEquals('c1', out[2].children[1].field)
	self:assertEquals('Charge', out[3].headerName)
	self:assertEquals(1, #out[3].children)
	self:assertEquals('c4', out[4].field)
end

-- A non-adjacent repeat of a group name starts a SECOND group rather than pulling
-- the column out of order.
function suite:testGroupColumnDefsDoesNotReorder()
	local defs = { { field = 'a' }, { field = 'b' }, { field = 'c' } }
	local out = dg._internal.groupColumnDefs(defs, { 'Rock', 'Charge', 'Rock' })
	self:assertEquals(3, #out)
	self:assertEquals('Rock', out[1].headerName)
	self:assertEquals('Charge', out[2].headerName)
	self:assertEquals('Rock', out[3].headerName)
	self:assertEquals('c', out[3].children[1].field)
end

-- Several eyebrow columns compose one line, so specs a reader needs to identify a
-- row travel in the lead card instead of costing a column each.
function suite:testEyebrowResolverComposes()
	local resolve = dg._internal.eyebrowResolver({ { alias = 'Type' }, { alias = 'Charges' } }, nil)
	local v = resolve({ Type = 'Active', Charges = '5' })
	self:assertEquals('Active · 5', v.text)
	-- With no filter column the whole line is the filter value.
	self:assertEquals('Active · 5', v.full)
	-- Absent parts drop out rather than leaving a dangling separator.
	self:assertEquals('Active', resolve({ Type = 'Active' }).text)
	self:assertEquals(nil, resolve({}))
end

-- A composed eyebrow strips the column headers that would say what a number is, so
-- `suffix` puts the unit back: "Active · 5 · 60" tells a reader nothing.
function suite:testEyebrowResolverSuffixes()
	local resolve = dg._internal.eyebrowResolver({
		{ alias = 'Type' },
		{ alias = 'Charges', suffix = 'charges', suffix1 = 'charge' },
		{ alias = 'Duration', suffix = 's' },
	}, nil)
	self:assertEquals('Active · 5 charges · 60 s', resolve({ Type = 'Active', Charges = '5', Duration = '60' }).text)
	-- Most passive modules have exactly one charge, so "1 charges" would be wrong on
	-- more rows than it is right.
	self:assertEquals('Passive · 1 charge', resolve({ Type = 'Passive', Charges = '1' }).text)
	-- A suffix on an absent value adds nothing — no stray unit on an empty part.
	self:assertEquals('Active', resolve({ Type = 'Active' }).text)
end

-- A filter-flagged eyebrow keys the lead's set filter on that column alone;
-- filtering on the composed line would give one option per row.
function suite:testEyebrowResolverFilterValue()
	local typePart = { alias = 'Type' }
	local resolve = dg._internal.eyebrowResolver(
		{ typePart, { alias = 'Charges', suffix = 'charges', suffix1 = 'charge' } },
		typePart
	)
	local v = resolve({ Type = 'Passive', Charges = '1' })
	self:assertEquals('Passive · 1 charge', v.text)
	-- An undecorated filter column is unchanged by the decoration rule.
	self:assertEquals('Passive', v.full)
end

-- prefix joins with NO space and suffix with one, matching how each is actually
-- written: a size is "S1", a unit is a separate word.
function suite:testEyebrowResolverPrefix()
	local resolve = dg._internal.eyebrowResolver({
		{ alias = 'Size', prefix = 'S' },
		{ alias = 'Slots', suffix = 'slots', suffix1 = 'slot' },
	}, nil)
	self:assertEquals('S2 · 2 slots', resolve({ Size = '2', Slots = '2' }).text)
	self:assertEquals('S1 · 1 slot', resolve({ Size = '1', Slots = '1' }).text)
end

-- The set filter lists the DECORATED value, so a size filter offers "S1" — the
-- term a reader recognises — rather than a bare "1".
function suite:testEyebrowFilterValueIsDecorated()
	local size = { alias = 'Size', prefix = 'S' }
	local resolve =
		dg._internal.eyebrowResolver({ size, { alias = 'Slots', suffix = 'slots', suffix1 = 'slot' } }, size)
	local v = resolve({ Size = '1', Slots = '1' })
	self:assertEquals('S1 · 1 slot', v.text)
	self:assertEquals('S1', v.full)
end

-- A pinned lead takes a fixed width: pinned lives outside AG Grid's centre
-- viewport, where flex has nothing to flex against, and the two together leave the
-- column unpinned entirely.
function suite:testPinnedLeadDropsFlex()
	local unpinned = dg._internal.buildSpecs({}, {}, {}, false)[1]
	self:assertEquals(1, unpinned.flex)
	self:assertEquals(nil, unpinned.pinned)
	self:assertEquals(nil, unpinned.width)
	local pinned = dg._internal.buildSpecs({}, {}, {}, true)[1]
	self:assertEquals('left', pinned.pinned)
	self:assertEquals(260, pinned.width)
	self:assertEquals(nil, pinned.flex)
end

-- `group=` places a column under a shared header.
function suite:testParseColumnsGroupClause()
	local cols = dg.parseColumns('Modifier resistance ; label=Resistance ; group=Rock')
	self:assertEquals('Rock', cols[1].group)
	local charges = dg.parseColumns('Charges ; eyebrow ; suffix=charges ; suffix1=charge')[1]
	self:assertEquals('charges', charges.suffix)
	self:assertEquals('charge', charges.suffix1)
	self:assertEquals('S', dg.parseColumns('Size ; eyebrow ; prefix=S')[1].prefix)
	self:assertEquals(nil, dg.parseColumns('X')[1].group)
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
