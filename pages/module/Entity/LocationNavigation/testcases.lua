require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Model = require('Module:Entity/LocationNavigation/Model')
local Gauge = require('Module:Entity/LocationNavigation/Gauge')
local systemMapData = require('Module:SystemMap/Data')
local NavData = require('Module:Entity/LocationNavigation/Data')
local Store = require('Module:Entity/Store')
local LocationNavigation = require('Module:Entity/LocationNavigation')
local bucketLib = require('mw.ext.bucket')

local suite = ScribuntoUnit:new()

local function place(page, classification, zone, extra)
	local row = { page = page, classification = classification, zone = zone }
	for key, value in pairs(extra or {}) do
		row[key] = value
	end
	return row
end

local DATA_CENTRES =
	{ '2UB-RB9-5', '4HJ-LVE-A', '5WQ-R2V-C', '8FK-Q2X-K', 'D79-ECG-R', 'E2Q-NSG-Y', 'QVX-J88-J', 'TMG-XEV-2' }

--- microTech as the approved board draws it.
local function microTechRows()
	local rows = {
		place(
			'New Babbage',
			'Landing zone',
			'surface',
			{ amenities = { 'Hospital', 'Hangar (XL)', 'Commodity Trading' }, image = 'New Babbage.jpg' }
		),
		place('Frostbite', 'Settlement', 'surface'),
		place('MT OpCenter TLI-4', 'Data center', 'surface'),
		place('Shubin Mining Facility SM0-10', 'Mining site', 'surface'),
		place('Shubin Mining Facility SM0-13', 'Mining site', 'surface'),
		place('The Necropolis', nil, 'surface'),
		place('Port Tressler', 'Orbital station', 'orbit'),
		place('Comm Array ST4-22', 'Comm array', 'orbit'),
		place('MIC-L2 Long Forest Station', 'Rest stop', 'lagrange', { lagrange = 'L2' }),
		place('MIC-L1 Shallow Frontier Station', 'Rest stop', 'lagrange', { lagrange = 'L1' }),
		place('MIC-L4 Red Crossroads Station', 'Rest stop', 'lagrange', { lagrange = 'L4' }),
	}
	for _, code in ipairs(DATA_CENTRES) do
		rows[#rows + 1] = place('MT DataCenter ' .. code, 'Data center', 'surface')
	end
	return rows
end

local function rowKeys(panel)
	local keys = {}
	for _, row in ipairs(panel.rows) do
		keys[#keys + 1] = row.key
	end
	return keys
end

local function findGroup(groups, heading)
	for _, group in ipairs(groups) do
		if group.heading == heading then
			return group
		end
	end
	return nil
end

function suite:testFamiliesByTrailingCode()
	local items = {}
	for _, code in ipairs(DATA_CENTRES) do
		items[#items + 1] = { page = 'MT DataCenter ' .. code, label = 'MT DataCenter ' .. code }
	end
	items[#items + 1] = { page = 'MT OpCenter TLI-4', label = 'MT OpCenter TLI-4' }
	local entries = Model.families(items)
	self:assertEquals(2, #entries)
	self:assertEquals('MT DataCenter', entries[1].family)
	self:assertEquals(8, #entries[1].members)
	self:assertDeepEquals({ page = 'MT DataCenter 2UB-RB9-5', label = '2UB-RB9-5' }, entries[1].members[1])
	self:assertDeepEquals({ page = 'MT OpCenter TLI-4', label = 'MT OpCenter TLI-4' }, entries[2])
end

function suite:testFamiliesByPrefixCode()
	local entries = Model.families({
		{ page = 'HDMS-Hadley', label = 'HDMS-Hadley' },
		{ page = 'HDMS-Edmond', label = 'HDMS-Edmond' },
		{ page = 'Lorville', label = 'Lorville' },
	})
	self:assertEquals('HDMS', entries[1].family)
	self:assertDeepEquals(
		{ { page = 'HDMS-Edmond', label = 'Edmond' }, { page = 'HDMS-Hadley', label = 'Hadley' } },
		entries[1].members
	)
	self:assertDeepEquals({ page = 'Lorville', label = 'Lorville' }, entries[2])
end

function suite:testGroupsSortAlphabeticallyWithOtherLast()
	local groups = Model.groups({
		place('The Necropolis', nil, 'surface'),
		place('Frostbite', 'Settlement', 'surface'),
		place('MT OpCenter TLI-4', 'Data center', 'surface'),
	}, true)
	self:assertEquals('Data centers', groups[1].heading)
	self:assertEquals('Settlements', groups[2].heading)
	self:assertEquals(Model.OTHER, groups[3].heading)
end

function suite:testPlanetPanel()
	local panel = Model.bodyPanel(systemMapData.findBody('MicroTech (planet)'), microTechRows())
	self:assertDeepEquals({ 'surface', 'orbit', 'moons', 'lagrange' }, rowKeys(panel))
	self:assertEquals('[[Stanton system|Stanton system]] › Stanton IV · Super-Earth', panel.eyebrow)
	self:assertEquals('[[MicroTech (planet)|microTech]]', panel.title)
	local surface = panel.rows[1]
	self:assertEquals('New Babbage', surface.cards[1].label)
	self:assertEquals('Hospital (T1) · Hangar (XL) · Commodity trading', surface.cards[1].meta)
	self:assertEquals('MT DataCenter', findGroup(surface.groups, 'Data centers').entries[1].family)
	self:assertEquals('Calliope', panel.rows[3].moons[1].label)
	self:assertEquals('4a', panel.rows[3].moons[1].designation)
	local lagrange = panel.rows[4]
	self:assertDeepEquals({ 'L1', 'L2' }, { lagrange.near[1].point, lagrange.near[2].point })
	self:assertEquals('L4', lagrange.far[1].point)
end

--- Before migration a planet has moons and no places: the disc gets its own
--- cap row rather than overlapping the first orbit arc.
function suite:testPlanetWithOnlyMoonsGetsACapRow()
	local panel = Model.bodyPanel(systemMapData.findBody('MicroTech (planet)'), {})
	self:assertDeepEquals({ 'cap', 'moons' }, rowKeys(panel))
end

function suite:testMoonPanelFocusesOnTheMoon()
	local panel = Model.bodyPanel(systemMapData.findBody('Calliope'), {
		place('Shubin Processing Facility SPMC-3', 'Processing facility', 'surface'),
		place('Comm Array ST4-31', 'Comm array', 'orbit'),
	})
	self:assertDeepEquals({ 'surface', 'orbit' }, rowKeys(panel))
	self:assertEquals('[[Stanton system|Stanton system]] › [[MicroTech (planet)|microTech]] › 4a', panel.eyebrow)
end

function suite:testStarPanelListsPlacesAroundTheStar()
	local panel = Model.bodyPanel(systemMapData.findBody('Stanton (star)'), {
		place('Pyro Gateway', 'Gateway station', 'star'),
	})
	self:assertEquals('orbit', panel.rows[#panel.rows].key)
	self:assertEquals('Gateway stations', panel.rows[#panel.rows].groups[1].heading)
end

function suite:testBodyWithNothingToShowIsNil()
	self:assertEquals(nil, Model.bodyPanel(systemMapData.findBody('Stanton (star)'), {}))
end

function suite:testInsidePanel()
	local panel = Model.insidePanel('New Babbage', {
		place('Brentworth Care Center (New Babbage)', 'Hospital', 'inside'),
		place('New Babbage Interstellar Spaceport', 'Spaceport', 'inside'),
		place('Aspire Grand', 'Residences', 'inside'),
	}, systemMapData.findBody('MicroTech (planet)'))
	self:assertEquals('[[New Babbage|New Babbage]]', panel.title)
	self:assertEquals('[[Stanton system|Stanton system]] › [[MicroTech (planet)|microTech]]', panel.eyebrow)
	self:assertEquals('Hospitals', panel.groups[1].heading)
	self:assertDeepEquals(
		{ page = 'Brentworth Care Center (New Babbage)', label = 'Brentworth Care Center' },
		panel.groups[1].entries[1]
	)
	self:assertEquals(nil, Model.insidePanel('New Babbage', {}, nil))
end

local function ofClass(elements, class)
	local out = {}
	for _, element in ipairs(elements) do
		if element.class == class then
			out[#out + 1] = element
		end
	end
	return out
end

function suite:testGaugeDiscAndAxisTopTheFirstRow()
	local gauge = Gauge.row({ key = 'surface' }, { icon = 'MicroTech Icon.png' }, true)
	local disc = ofClass(gauge.wide, 'disc')[1]
	self:assertDeepEquals({ 5, -75, 150 }, { disc.left, disc.top, disc.size })
	self:assertEquals(nil, disc.modifier)
	self:assertEquals(75, ofClass(gauge.wide, 'axis')[1].top)
	disc = ofClass(gauge.narrow, 'disc')[1]
	self:assertDeepEquals({ 2, -26, 52 }, { disc.left, disc.top, disc.size })
	self:assertEquals(nil, disc.modifier)
end

--- Most bodies have no icon (311/323 planets, 55/74 moons in systems.json):
--- the disc still needs a CSS circle rather than an empty borderless span.
function suite:testGaugeIconLessDiscGetsThePlainModifier()
	local gauge = Gauge.row({ key = 'surface' }, {}, true)
	local disc = ofClass(gauge.wide, 'disc')[1]
	self:assertEquals('plain', disc.modifier)
	self:assertEquals(nil, disc.file)
end

function suite:testGaugeOrbitArc()
	local gauge = Gauge.row({ key = 'orbit' }, {}, false)
	local arc = ofClass(gauge.wide, 'arc')[1]
	self:assertDeepEquals({ -160, -458, 480 }, { arc.left, arc.top, arc.width })
	arc = ofClass(gauge.narrow, 'arc')[1]
	self:assertDeepEquals({ -62, -158, 180 }, { arc.left, arc.top, arc.width })
end

function suite:testGaugeMoonArcsAndGlyphs()
	local gauge = Gauge.row({
		key = 'moons',
		moons = { { km = 600, icon = 'a.png' }, { km = 300, icon = 'b.png' }, { km = 500, icon = 'c.png' } },
	}, {}, false)
	local arcs = ofClass(gauge.wide, 'arc')
	self:assertDeepEquals(
		{ { -240, -618 }, { -320, -742 }, { -400, -866 } },
		{ { arcs[1].left, arcs[1].top }, { arcs[2].left, arcs[2].top }, { arcs[3].left, arcs[3].top } }
	)
	local glyphs = ofClass(gauge.wide, 'glyph')
	self:assertDeepEquals({ 16, 13, 15 }, { glyphs[1].size, glyphs[2].size, glyphs[3].size })
	self:assertEquals(22, glyphs[1].top + glyphs[1].size / 2)
	arcs = ofClass(gauge.narrow, 'arc')
	self:assertDeepEquals(
		{ { -92, -186 }, { -122, -210 }, { -152, -234 } },
		{ { arcs[1].left, arcs[1].top }, { arcs[2].left, arcs[2].top }, { arcs[3].left, arcs[3].top } }
	)
end

function suite:testGaugeLagrangeDiamonds()
	local row = { key = 'lagrange', near = { { point = 'L1' }, { point = 'L2' } }, far = { { point = 'L4' } } }
	local gauge = Gauge.row(row, {}, false)
	local arcs = ofClass(gauge.wide, 'arc')
	self:assertDeepEquals(
		{ { -520, -1178 }, { -820, -1742 } },
		{ { arcs[1].left, arcs[1].top }, { arcs[2].left, arcs[2].top } }
	)
	local diamonds = ofClass(gauge.wide, 'diamond')
	self:assertDeepEquals({ { 32, 16 }, { 120, 16 }, { 76, 54 } }, {
		{ diamonds[1].left, diamonds[1].top },
		{ diamonds[2].left, diamonds[2].top },
		{ diamonds[3].left, diamonds[3].top },
	})
	self:assertEquals(32, ofClass(gauge.wide, 'break')[1].top)
	self:assertEquals(32, ofClass(gauge.wide, 'axis')[1].height)
	arcs = ofClass(gauge.narrow, 'arc')
	self:assertDeepEquals(
		{ { -192, -386 }, { -272, -510 } },
		{ { arcs[1].left, arcs[1].top }, { arcs[2].left, arcs[2].top } }
	)
	self:assertEquals(64, ofClass(gauge.narrow, 'break')[1].top)
end

function suite:testGaugeNearOnlyHasNoBreak()
	local gauge = Gauge.row({ key = 'lagrange', near = { { point = 'L1' } }, far = {} }, {}, false)
	self:assertEquals(1, #ofClass(gauge.wide, 'arc'))
	self:assertEquals(0, #ofClass(gauge.wide, 'break'))
end

--- Swap Store fields for the duration of fn; the runner never reloads modules,
--- so this is the table Data holds.
local function withStore(fields, fn)
	local saved = {}
	for name, value in pairs(fields) do
		saved[name] = Store[name]
		Store[name] = value
	end
	local ok, err = pcall(fn)
	for name, value in pairs(saved) do
		Store[name] = value
	end
	if not ok then
		error(err, 0)
	end
end

function suite:testChildrenQueryShape()
	local seen
	withStore({
		query = function(spec)
			seen = spec
			return { { page = 'New Babbage', zone = 'surface' } }
		end,
	}, function()
		local rows = NavData.children('MicroTech (planet)')
		self:assertEquals('New Babbage', rows[1].page)
	end)
	self:assertDeepEquals({ { 'Parent', 'MicroTech (planet)' }, { 'Zone', '+' } }, seen.filters)
	self:assertEquals('Location', seen.kind)
end

function suite:testChildrenDegradesOnFailure()
	withStore({
		query = function()
			error('rate limited')
		end,
	}, function()
		self:assertEquals(nil, NavData.children('MicroTech (planet)'))
	end)
end

--- Runs through the REAL Store.query/BucketQuery (no Store stub) against the
--- live property manifest, proving `Parent`/`Zone` resolve to the `location`
--- bucket the current manifest actually declares, not a guessed spelling.
function suite:testChildrenQueriesTheRealManifestThroughBucketQuery()
	bucketLib._reset()
	NavData.children('MicroTech (planet)')
	local chain = bucketLib._chains[1]
	self:assertEquals('entity', chain.bucket)
	self:assertDeepEquals({ { 'location', 'location.page_name', 'entity.page_name' } }, chain.join)
	self:assertDeepEquals({
		{ 'location.parent', '=', 'MicroTech (planet)' },
		{ op = 'not', { 'location.zone', '&&NULL&&' } },
	}, chain.where)
end

function suite:testContextOfABodyIsItself()
	withStore({
		pageValue = function()
			error('must not read Bucket')
		end,
	}, function()
		local context = NavData.context('MicroTech (planet)')
		self:assertEquals('MicroTech (planet)', context.body.entry.page)
	end)
end

function suite:testContextWalksParentsToTheBody()
	local stored = {
		['Riker Memorial Spaceport'] = { Zone = 'inside', Parent = 'Area18' },
		['Area18'] = { Zone = 'surface', Parent = 'ArcCorp (planet)' },
	}
	withStore({
		pageValue = function(page, name)
			return (stored[page] or {})[name]
		end,
	}, function()
		local context = NavData.context('Riker Memorial Spaceport')
		self:assertEquals('ArcCorp (planet)', context.body.entry.page)
		self:assertEquals('inside', context.zone)
		self:assertEquals('Area18', context.parent)
	end)
end

function suite:testContextWalkIsBounded()
	local reads = 0
	withStore({
		pageValue = function(_, name)
			reads = reads + 1
			return name == 'Parent' and 'Nowhere' or nil
		end,
	}, function()
		self:assertEquals(nil, NavData.context('Somewhere').body)
	end)
	self:assertTrue(reads <= NavData.MAX_HOPS + 2)
end

--- Swap NavData fields for the duration of fn.
local function withNavData(fields, fn)
	local saved = {}
	for name, value in pairs(fields) do
		saved[name] = NavData[name]
		NavData[name] = value
	end
	local ok, err = pcall(fn)
	for name, value in pairs(saved) do
		NavData[name] = value
	end
	if not ok then
		error(err, 0)
	end
end

function suite:testRenderPlanetPanel()
	withNavData({
		children = function()
			return microTechRows()
		end,
	}, function()
		local html = LocationNavigation.render('MicroTech (planet)')
		self:assertStringContains('Stanton IV · Super-Earth', html, true)
		for _, key in ipairs({ 'surface', 'orbit', 'moons', 'lagrange' }) do
			self:assertStringContains('t-location-nav__row--' .. key, html, true)
		end
		self:assertStringContains('[[MT DataCenter 2UB-RB9-5|2UB-RB9-5]]', html, true)
		self:assertStringContains('[[MIC-L1 Shallow Frontier Station|L1]]', html, true)
		self:assertStringContains('[[File:New Babbage.jpg|112px|link=|alt=]]', html, true)
		self:assertStringContains('t-location-nav__g--wide', html, true)
		self:assertStringContains('t-location-nav__g--narrow', html, true)
		self:assertStringContains('aria-hidden="true"', html, true)
	end)
end

function suite:testRenderInsidePanelComesFirst()
	withNavData({
		context = function()
			return {
				subject = 'Riker Memorial Spaceport',
				body = systemMapData.findBody('ArcCorp (planet)'),
				zone = 'inside',
				parent = 'Area18',
			}
		end,
		children = function(page)
			if page == 'Area18' then
				return { place('Riker Memorial Spaceport', 'Spaceport', 'inside') }
			end
			return { place('Area18', 'Landing zone', 'surface') }
		end,
	}, function()
		local html = LocationNavigation.render('Riker Memorial Spaceport')
		local inside = html:find('Spaceports', 1, true)
		local surface = html:find('t-location-nav__row--surface', 1, true)
		self:assertTrue(inside ~= nil and surface ~= nil and inside < surface)
		self:assertStringContains('<ul class="t-location-nav__inside-list">', html, true)
	end)
end

function suite:testRenderNothingToShow()
	withNavData({
		context = function()
			return { subject = 'Nowhere' }
		end,
		children = function()
			return {}
		end,
	}, function()
		self:assertEquals('', LocationNavigation.render('Nowhere'))
	end)
end

--- Swap mw.title.new for the duration of fn, as Store's tests do.
local function withTitleNew(stub, fn)
	local saved = mw.title.new
	mw.title.new = stub
	local ok, err = pcall(fn)
	mw.title.new = saved
	if not ok then
		error(err, 0)
	end
end

function suite:testNormalisePageFixesCapitalisation()
	withTitleNew(function(text)
		self:assertEquals('microTech (planet)', text)
		return { text = 'MicroTech (planet)', namespace = 0 }
	end, function()
		self:assertEquals('MicroTech (planet)', LocationNavigation._internal.normalisePage('microTech (planet)'))
	end)
end

function suite:testNormalisePageRejectsNonMainNamespace()
	withTitleNew(function(text)
		return { text = text, namespace = 4 }
	end, function()
		self:assertEquals(nil, LocationNavigation._internal.normalisePage('Module:X'))
	end)
end

function suite:testNormalisePageRejectsUnresolvableOrNonString()
	self:assertEquals(nil, LocationNavigation._internal.normalisePage(nil))
	withTitleNew(function()
		return nil
	end, function()
		self:assertEquals(nil, LocationNavigation._internal.normalisePage('Bad::Title'))
	end)
end

return suite
