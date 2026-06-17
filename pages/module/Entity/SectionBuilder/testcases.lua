require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local suite = ScribuntoUnit:new()

-- push() — nil/'' collapse + chaining

function suite:testPushAppendsPresentContent()
	local items = {}
	sectionBuilder.push(items, 'Health', '100')
	self:assertEquals(1, #items)
	self:assertEquals('Health', items[1].label)
	self:assertEquals('100', items[1].content)
end

function suite:testPushSkipsNil()
	local items = {}
	sectionBuilder.push(items, 'Health', nil)
	self:assertEquals(0, #items)
end

function suite:testPushSkipsEmptyString()
	local items = {}
	sectionBuilder.push(items, 'Health', '')
	self:assertEquals(0, #items)
end

function suite:testPushKeepsFalseAndZero()
	-- false / 0 are real values, not "missing" — only nil and '' collapse.
	local items = {}
	sectionBuilder.push(items, 'Flag', false)
	sectionBuilder.push(items, 'Count', 0)
	self:assertEquals(2, #items)
	self:assertEquals(false, items[1].content)
	self:assertEquals(0, items[2].content)
end

function suite:testPushReturnsItemsForChaining()
	local items = {}
	self:assertTrue(sectionBuilder.push(items, 'A', '1') == items)
end

-- pushNonNil() — collapses on nil ONLY (keeps '')

function suite:testPushNonNilKeepsEmptyString()
	-- the whole point: '' is kept (push would drop it)
	local items = {}
	sectionBuilder.pushNonNil(items, 'Cooling rate', '')
	self:assertEquals(1, #items)
	self:assertEquals('Cooling rate', items[1].label)
	self:assertEquals('', items[1].content)
end

function suite:testPushNonNilSkipsNil()
	local items = {}
	sectionBuilder.pushNonNil(items, 'Cooling rate', nil)
	self:assertEquals(0, #items)
end

function suite:testPushNonNilKeepsValueAndChains()
	local items = {}
	self:assertTrue(sectionBuilder.pushNonNil(items, 'Power', '120') == items)
	self:assertEquals('120', items[1].content)
end

-- section() — payload presence gate + field passthrough

function suite:testSectionNilWhenNoPayload()
	self:assertEquals(nil, sectionBuilder.section({ key = 'x', label = 'X', items = {} }))
	self:assertEquals(nil, sectionBuilder.section({ key = 'x', label = 'X' }))
	self:assertEquals(nil, sectionBuilder.section({ key = 'x', content = '' }))
end

function suite:testSectionFromItems()
	local s = sectionBuilder.section({
		key = 'component',
		label = 'Component',
		collapsible = true,
		collapsed = true,
		items = { { label = 'Health', content = '100' } },
	})
	self:assertEquals('component', s.key)
	self:assertEquals('Component', s.label)
	self:assertEquals(true, s.collapsible)
	self:assertEquals(true, s.collapsed)
	self:assertEquals(1, #s.items)
	-- unset payloads stay absent (nil), so the table equals the hand-built one
	self:assertEquals(nil, s.sections)
	self:assertEquals(nil, s.content)
	self:assertEquals(nil, s.class)
	self:assertEquals(nil, s.columns)
end

function suite:testSectionFromSections()
	local s = sectionBuilder.section({
		key = 'dimensions',
		label = 'Dimensions',
		sections = { { label = 'Cargo', content = 'c' }, { label = 'Physical', content = 'p' } },
	})
	self:assertEquals('dimensions', s.key)
	self:assertEquals(2, #s.sections)
	self:assertEquals(nil, s.items)
end

function suite:testSectionFromContent()
	local s = sectionBuilder.section({ key = 'd', label = 'Cargo dimensions', content = 'blob' })
	self:assertEquals('blob', s.content)
	self:assertEquals(nil, s.items)
end

function suite:testSectionPassesItemClass()
	local s = sectionBuilder.section({
		key = 'armor',
		label = 'Damage resistance',
		items = { { content = 'tiles', class = 't-infobox-item--block' } },
	})
	self:assertEquals('t-infobox-item--block', s.items[1].class)
end

function suite:testSectionPassesColumns()
	-- columns is a section-level layout hint the renderer (Assembly.mergeSections)
	-- carries through; section() must reproduce it like the other metadata fields.
	local s =
		sectionBuilder.section({ key = 'x', label = 'X', columns = 2, items = { { label = 'L', content = '1' } } })
	self:assertEquals(2, s.columns)
end

-- build() — nil filtering, including interspersed nils

function suite:testBuildFiltersNils()
	local a = sectionBuilder.section({ key = 'a', items = { { label = 'L', content = '1' } } })
	local b = sectionBuilder.section({ key = 'b', items = { { label = 'M', content = '2' } } })
	local out = sectionBuilder.build(a, nil, b)
	self:assertEquals(2, #out)
	self:assertEquals('a', out[1].key)
	self:assertEquals('b', out[2].key)
end

function suite:testBuildAllNilIsEmpty()
	self:assertEquals(0, #sectionBuilder.build(nil, nil))
	self:assertEquals(0, #sectionBuilder.build())
end

function suite:testBuildSingleSection()
	local out = sectionBuilder.build(sectionBuilder.section({ key = 'a', items = { { label = 'L', content = '1' } } }))
	self:assertEquals(1, #out)
end

return suite
