require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Facet = require('Module:Entity/Facet/Dimensions')
local internal = Facet._internal

local suite = ScribuntoUnit:new()

-- hasBox()

function suite:testHasBoxValid()
	self:assertEquals(true, internal.hasBox({ length = 2, width = 1, height = 0.5 }))
end

function suite:testHasBoxStringNumbers()
	self:assertEquals(true, internal.hasBox({ length = '2', width = '1', height = '0.5' }))
end

function suite:testHasBoxZeroRejected()
	self:assertEquals(false, internal.hasBox({ length = 0, width = 1, height = 1 }))
end

function suite:testHasBoxMissingFieldRejected()
	self:assertEquals(false, internal.hasBox({ length = 2, width = 1 }))
end

function suite:testHasBoxNonNumberRejected()
	self:assertEquals(false, internal.hasBox({ length = 'big', width = 1, height = 1 }))
end

function suite:testHasBoxNilRejected()
	self:assertEquals(false, internal.hasBox(nil))
end

-- matches()

function suite:testMatchesNilFalse()
	self:assertEquals(false, Facet.matches(nil))
end

function suite:testMatchesNoDimensionFalse()
	self:assertEquals(false, Facet.matches({ mass = 5 }))
end

function suite:testMatchesVolumeOnlyDimensionFalse()
	-- Apollo-module shape: volume but no drawable box.
	self:assertEquals(false, Facet.matches({ dimension = { volume_converted = 1 } }))
end

function suite:testMatchesPhysicalOnlyTrue()
	self:assertEquals(true, Facet.matches({ dimension = { dimensions = { length = 1, width = 1, height = 1 } } }))
end

function suite:testMatchesCargoOnlyTrue()
	self:assertEquals(true, Facet.matches({ dimension = { cargo_dimension = { length = 1, width = 1, height = 1 } } }))
end

-- getSections() — assert on descriptor structure, not rendered markup

function suite:testGetSectionsNeitherReturnsEmpty()
	self:assertEquals(0, #Facet.getSections({ dimension = { volume_converted = 1 } }, {}))
end

function suite:testGetSectionsBothReturnsTabs()
	local sections = Facet.getSections({
		mass = 2000,
		dimension = {
			dimensions = { length = 2.1, width = 2.9, height = 0.9 },
			cargo_dimension = { length = 2.2, width = 0.2, height = 0.8 },
			volume_converted = 84000,
			volume_converted_unit = 'µSCU',
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('dimensions', sections[1].key)
	self:assertEquals('Dimensions', sections[1].label)
	self:assertEquals(2, #sections[1].sections)
	self:assertEquals('Cargo', sections[1].sections[1].label)
	self:assertEquals('Physical', sections[1].sections[2].label)
end

function suite:testGetSectionsPhysicalOnlyUntabbed()
	local sections = Facet.getSections({
		mass = 5,
		dimension = { dimensions = { length = 1, width = 1, height = 1 } },
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('Dimensions', sections[1].label)
	self:assertEquals(nil, sections[1].sections)
	self:assertTrue(type(sections[1].content) == 'string')
end

function suite:testGetSectionsCargoOnlyUntabbed()
	local sections = Facet.getSections({
		dimension = {
			cargo_dimension = { length = 1, width = 1, height = 1 },
			volume_converted = 900,
			volume_converted_unit = 'µSCU',
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('Cargo dimensions', sections[1].label)
	self:assertEquals(nil, sections[1].sections)
	self:assertTrue(type(sections[1].content) == 'string')
end

return suite
