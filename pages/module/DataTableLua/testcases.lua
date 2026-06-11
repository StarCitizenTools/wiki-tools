require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local dt = require('Module:DataTableLua')

-- Returns true if `list` contains `value`.
local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- parseColumns

function suite:testParseColumnsEmpty()
	self:assertEquals(0, #dt.parseColumns(''))
	self:assertEquals(0, #dt.parseColumns(nil))
end

function suite:testParseColumnsBareProperty()
	local cols = dt.parseColumns('Size')
	self:assertEquals(1, #cols)
	self:assertEquals('Size', cols[1].property)
	self:assertEquals(nil, cols[1].label)
	self:assertEquals(nil, cols[1].size)
	self:assertEquals(nil, cols[1].filter)
end

function suite:testParseColumnsLabel()
	local cols = dt.parseColumns('Subtype ; label=Type')
	self:assertEquals('Subtype', cols[1].property)
	self:assertEquals('Type', cols[1].label)
end

function suite:testParseColumnsSize()
	local cols = dt.parseColumns('Page Image ; size=100px')
	self:assertEquals('Page Image', cols[1].property)
	self:assertEquals('100px', cols[1].size)
end

function suite:testParseColumnsFilterFlag()
	local cols = dt.parseColumns('Manufacturer ; filter')
	self:assertEquals('Manufacturer', cols[1].property)
	self:assertEquals(true, cols[1].filter)
end

function suite:testParseColumnsAllModifiers()
	local cols = dt.parseColumns('Is item base variant ; label=Base variant ; filter')
	self:assertEquals('Is item base variant', cols[1].property)
	self:assertEquals('Base variant', cols[1].label)
	self:assertEquals(true, cols[1].filter)
end

-- Property names and labels keep their internal spaces; only surrounding
-- whitespace is trimmed.
function suite:testParseColumnsPreservesInternalSpaces()
	local cols = dt.parseColumns('Maximum range ; label=Max range')
	self:assertEquals('Maximum range', cols[1].property)
	self:assertEquals('Max range', cols[1].label)
end

-- All three spacing styles around the separator parse identically.
function suite:testParseColumnsSpacingStyles()
	local spaced = dt.parseColumns('Size ; filter')
	local trailing = dt.parseColumns('Size; filter')
	local tight = dt.parseColumns('Size;filter')
	self:assertEquals('Size', spaced[1].property)
	self:assertEquals('Size', trailing[1].property)
	self:assertEquals('Size', tight[1].property)
	self:assertEquals(true, spaced[1].filter)
	self:assertEquals(true, trailing[1].filter)
	self:assertEquals(true, tight[1].filter)
end

-- Blank lines are dropped and per-line indentation is trimmed; order is kept.
function suite:testParseColumnsMultilineOrderAndBlanks()
	local cols = dt.parseColumns('\n    Size ; filter\n\n    Subtype ; label=Type\n    Class\n')
	self:assertEquals(3, #cols)
	self:assertEquals('Size', cols[1].property)
	self:assertEquals('Subtype', cols[2].property)
	self:assertEquals('Class', cols[3].property)
end

-- A line with no property (only modifiers) is dropped.
function suite:testParseColumnsDropsEmptyProperty()
	local cols = dt.parseColumns('; filter\nSize')
	self:assertEquals(1, #cols)
	self:assertEquals('Size', cols[1].property)
end

-- Unknown modifiers are ignored without error.
function suite:testParseColumnsIgnoresUnknownModifier()
	local cols = dt.parseColumns('Size ; wat ; filter')
	self:assertEquals('Size', cols[1].property)
	self:assertEquals(true, cols[1].filter)
end

-- buildAskArgs

function suite:testBuildAskArgsQueryCondition()
	local args = dt.buildAskArgs('Personal weapons', dt.parseColumns('Size'))
	-- Main-namespace restriction ([[:+]]) must precede the category condition.
	self:assertEquals('[[:+]] [[Category:Personal weapons]]', args[1])
end

function suite:testBuildAskArgsLeadPrintouts()
	local args = dt.buildAskArgs('Personal weapons', dt.parseColumns('Size'))
	self:assertTrue(contains(args, '?Page Image#100px='))
	self:assertTrue(contains(args, '?=Name'))
end

function suite:testBuildAskArgsPrintoutFormatting()
	local args = dt.buildAskArgs('X', dt.parseColumns('Subtype ; label=Type'))
	self:assertTrue(contains(args, '?Subtype=Type'))
end

function suite:testBuildAskArgsBarePrintout()
	local args = dt.buildAskArgs('X', dt.parseColumns('Class'))
	self:assertTrue(contains(args, '?Class'))
end

function suite:testBuildAskArgsFixedOptions()
	local args = dt.buildAskArgs('X', dt.parseColumns('Size'))
	self:assertTrue(contains(args, 'format=datatables'))
	self:assertTrue(contains(args, 'mainlabel=-'))
	self:assertTrue(contains(args, 'datatables-pageLength=10'))
end

-- Facet indices are 0-based and offset by the two lead columns.
-- This mirrors the original Personal weapon query exactly.
function suite:testBuildAskArgsFacetIndicesParity()
	local cols = dt.parseColumns(table.concat({
		'Size ; filter',
		'Subtype ; label=Type ; filter',
		'Class ; filter',
		'Ammo ; filter',
		'Effective range',
		'Maximum range ; label=Max range',
		'Muzzle velocity',
		'Damage',
		'Manufacturer ; filter',
		'Is item base variant ; label=Base variant ; filter',
	}, '\n'))
	local args = dt.buildAskArgs('Personal weapons', cols)
	self:assertTrue(contains(args, 'datatables-searchPanes.columns=2,3,4,5,10,11'))
end

-- No facets means no searchPanes.columns argument at all.
function suite:testBuildAskArgsNoFacets()
	local args = dt.buildAskArgs('X', dt.parseColumns('Size\nClass'))
	for _, v in ipairs(args) do
		self:assertFalse(v:find('searchPanes.columns', 1, true) ~= nil)
	end
end

function suite:testBuildAskArgsAppendsConditions()
	local cols = dt.parseColumns('Size ; filter')
	local args = dt.buildAskArgs('Guns', cols, '[[Damage type::Laser]][[Firing type::Cannon]]')
	self:assertEquals('[[:+]] [[Category:Guns]] [[Damage type::Laser]][[Firing type::Cannon]]', args[1])
end

function suite:testBuildAskArgsNilConditionsUnchanged()
	local cols = dt.parseColumns('Size')
	local args = dt.buildAskArgs('Guns', cols, nil)
	self:assertEquals('[[:+]] [[Category:Guns]]', args[1])
end

function suite:testBuildAskArgsEmptyConditionsUnchanged()
	local cols = dt.parseColumns('Size')
	local args = dt.buildAskArgs('Guns', cols, '')
	self:assertEquals('[[:+]] [[Category:Guns]]', args[1])
end

return suite
