require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Infobox = require('Module:Entity/Infobox')

local suite = ScribuntoUnit:new()

local buildMetadataSection = Infobox._internal.buildMetadataSection

--- A chain link contributing one Metadata row, shaped like StarSystem's
--- getMetadataItems (the only implementer today: the ARK starmap code).
--- @param label string
--- @param content string
--- @return table chainLink
local function contributor(label, content)
	return {
		getMetadataItems = function()
			return { { label = label, content = content } }
		end,
	}
end

--- @param section table|nil
--- @param label string
--- @return any
local function findItem(section, label)
	for _, item in ipairs(section and section.items or {}) do
		if item.label == label then
			return item.content
		end
	end
end

function suite:testGenericRowsFromApiData()
	local section = buildMetadataSection({}, { class_name = 'AEGS_Gladius', version = '4.9.0' }, { uuid = 'abc' })
	self:assertEquals('abc', findItem(section, 'UUID'))
	self:assertEquals('AEGS_Gladius', findItem(section, 'Class name'))
	self:assertEquals('4.9.0', findItem(section, 'Version'))
end

-- The chain's getMetadataItems rows are appended after the generic ones.
function suite:testChainContributedRowsAreAppended()
	local section = buildMetadataSection({ contributor('Starmap code', 'STANTON') }, { class_name = 'x' }, {})
	self:assertEquals('STANTON', findItem(section, 'Starmap code'))
	self:assertEquals('Starmap code', section.items[#section.items].label)
end

-- No generic row carries content here, so the section exists ONLY because the
-- chain contributed a row: deleting the chain loop collapses it to nil. This is
-- the live shape of a kind-declared lore system (no uuid, no API record).
function suite:testChainRowAloneKeepsTheSection()
	local section = buildMetadataSection({ contributor('Starmap code', 'NEXUS') }, {}, {})
	self:assertEquals('Metadata', section.label)
	self:assertEquals(true, section.collapsed)
	self:assertEquals('NEXUS', findItem(section, 'Starmap code'))
end

-- Every link is walked, not just the leaf.
function suite:testEveryChainLinkContributes()
	local chain = { contributor('Root row', 'r'), {}, contributor('Leaf row', 'l') }
	local section = buildMetadataSection(chain, {}, {})
	self:assertEquals('r', findItem(section, 'Root row'))
	self:assertEquals('l', findItem(section, 'Leaf row'))
end

-- A link with no hook, and a hook returning nil, are both tolerated.
function suite:testNilWhenEveryRowIsEmpty()
	self:assertEquals(nil, buildMetadataSection({}, {}, {}))
	self:assertEquals(
		nil,
		buildMetadataSection({ {}, {
			getMetadataItems = function()
				return nil
			end,
		} }, {}, {})
	)
end

-- Entity tags render as <data> elements so the visible text is the display name
-- while the value attribute carries the tag UUID.
function suite:testEntityTagsRowCarriesTheUuidAsAValueAttribute()
	local content = findItem(
		buildMetadataSection({}, { entity_tag_map = { { uuid = 'u1', name = 'Ballistic' } } }, {}),
		'Entity tags'
	)
	self:assertEquals('<data value="u1">Ballistic</data>', content)
end

-- ── Footer buttons ─────────────────────────────────────────────────────────

local buildFooterSection = Infobox._internal.buildFooterSection

function suite:testFooterVerseGuideButton()
	local section = buildFooterSection({}, {}, { verseguideurl = 'https://verseguide.com/location/STANTON' })
	self:assertStringContains('VerseGuide', section.content)
	self:assertStringContains('https://verseguide.com/location/STANTON', section.content)
	self:assertStringContains('t%-button%-%-verseguide', section.content)
end

function suite:testFooterVerseGuideOrderAfterChainBeforeWikiApi()
	-- Official RSI properties (Galactapedia, the chain's Starmap) sit adjacent;
	-- the community site follows them; Wiki API closes the row.
	local chain = {
		{
			getFooterButtons = function()
				return { { label = 'Starmap', url = 'https://example.com/s', icon = 'Sc-icon-galactapedia.svg' } }
			end,
		},
	}
	local args = {
		galactapediaurl = 'https://example.com/g',
		verseguideurl = 'https://example.com/v',
		uuid = 'u-1',
	}
	local content = buildFooterSection(chain, {}, args).content
	local galactapedia = content:find('Galactapedia', 1, true)
	local starmap = content:find('Starmap', 1, true)
	local verseguide = content:find('VerseGuide', 1, true)
	local wikiApi = content:find('Wiki API', 1, true)
	self:assertTrue(galactapedia < starmap and starmap < verseguide and verseguide < wikiApi)
end

function suite:testFooterNilWithNoButtons()
	self:assertEquals(nil, buildFooterSection({}, {}, {}))
	-- An empty-string arg is absent, not a blank button.
	self:assertEquals(nil, buildFooterSection({}, {}, { verseguideurl = '' }))
end

return suite
