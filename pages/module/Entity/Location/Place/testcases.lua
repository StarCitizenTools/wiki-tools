require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Classes = require('Module:Entity/Location/Place/Classes')
local Amenities = require('Module:Entity/Location/Place/Amenities')
local Jurisdiction = require('Module:Entity/Location/Jurisdiction')
local Place = require('Module:Entity/Location/Place')
local Store = require('Module:Entity/Store')

local suite = ScribuntoUnit:new()

function suite:testClassLookupIsCaseAndSpaceInsensitive()
	local entry = Classes.get('  Mining Site ')
	self:assertEquals('Mining site', entry.name)
	self:assertEquals('Mining sites', entry.category)
	self:assertEquals('Outposts', entry.parent)
	self:assertEquals('surface', entry.zone)
end

function suite:testRestStopDefaultsToTheLagrangeZone()
	self:assertDeepEquals(
		{ name = 'Rest stop', category = 'Rest stops', parent = 'Space stations', zone = 'lagrange' },
		Classes.get('rest stop')
	)
end

--- Legacy values are not classes: the migration maps them, and an unmapped
--- value must not pass as one.
function suite:testUnknownOrEmptyClassIsNil()
	self:assertEquals(nil, Classes.get('Landmark'))
	self:assertEquals(nil, Classes.get(''))
	self:assertEquals(nil, Classes.get(nil))
end

function suite:testEveryClassIsComplete()
	for name, def in pairs(mw.loadJsonData('Module:Entity/Location/Place/classes.json').classes) do
		self:assertTrue(type(def.category) == 'string' and def.category ~= '', name .. ' category')
		self:assertTrue(type(def.parent) == 'string' and def.parent ~= '', name .. ' parent')
		self:assertTrue(Classes.ZONES[def.zone] == true, name .. ' zone ' .. tostring(def.zone))
	end
end

--- display_name list → the record shape the API serves.
local function amenityRecord(list)
	local amenities = {}
	for _, name in ipairs(list) do
		amenities[#amenities + 1] = { display_name = name }
	end
	return { amenities = amenities }
end

local NEW_BABBAGE_AMENITIES = {
	'Buy Armor',
	'Buy Clothing',
	'Buy Ship Items/Weapons',
	'Buy Weapons',
	'Commodity Trading',
	'Food Court',
	'Garage',
	'Hangar (XL)',
	'Hospital',
	'Rent Vehicles',
	'Vehicle Services',
}

local ARC_L2_AMENITIES = {
	'Buy Clothing',
	'Buy Ship Items/Weapons',
	'Clinic',
	'Commodity Trading',
	'Docking',
	'Food Court',
	'Hangar (L)',
	'Landing Pad (M)',
	'Refinery',
	'Rent Vehicles',
	'Vehicle Services',
}

function suite:testAmenityNamesKeepApiOrderAndDropDuplicates()
	local record = amenityRecord({ 'Garage', 'Hospital', 'Garage', '' })
	self:assertDeepEquals({ 'Garage', 'Hospital' }, Amenities.names(record))
	self:assertDeepEquals({}, Amenities.names({}))
end

function suite:testLandingZoneAmenitiesGroup()
	self:assertDeepEquals({
		{ label = 'Vehicles', text = 'Hangar (XL) · Garage · Vehicle services' },
		{ label = 'Trade & industry', text = 'Commodity trading' },
		{ label = 'Medical', text = 'Hospital (T1)' },
		{ label = 'Shops', text = 'Armor · Clothing · Ship items/weapons · Weapons · Rent vehicles · Food court' },
	}, Amenities.group(Amenities.names(amenityRecord(NEW_BABBAGE_AMENITIES))))
end

function suite:testRestStopAmenitiesGroup()
	local rows = Amenities.group(Amenities.names(amenityRecord(ARC_L2_AMENITIES)))
	self:assertDeepEquals(
		{ label = 'Vehicles', text = 'Hangar (L) · Landing pad (M) · Docking · Vehicle services' },
		rows[1]
	)
	self:assertDeepEquals({ label = 'Trade & industry', text = 'Commodity trading · Refinery' }, rows[2])
	self:assertDeepEquals({ label = 'Medical', text = 'Clinic (T2)' }, rows[3])
end

--- A new game amenity must surface, not vanish, until the table places it.
function suite:testUnknownAmenityGoesToOther()
	local rows = Amenities.group({ 'Event', 'Garage' })
	self:assertDeepEquals({ label = 'Other', text = 'Event' }, rows[#rows])
end

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

--- New Babbage, trimmed from the live record.
local function newBabbage()
	local record = amenityRecord(NEW_BABBAGE_AMENITIES)
	record.uuid = '122e8057-831d-4517-a23b-0eb8382b90a2'
	record.name = 'New Babbage'
	record.system = 'Stanton System'
	record.respawn_location_type = 'Other'
	record.type = { name = 'LandingZone', classification = 'Settlement' }
	record.parent = { uuid = '5a529db7-1a4e-45b0-bdcb-a5a0c7a7fc57', name = 'microTech', type_name = 'Planet' }
	record.jurisdiction = { name = 'microTech' }
	record.inheritedJurisdiction = 'microTech'
	return record
end

--- ARC-L2 Lively Pathway Station, trimmed from the live record: parented to the
--- star, as every Lagrange station is.
local function arcL2()
	local record = amenityRecord(ARC_L2_AMENITIES)
	record.uuid = '45b909df-7b0c-40c9-ab83-a7cd7d3a980f'
	record.name = 'ARC-L2 Lively Pathway Station'
	record.system = 'Stanton System'
	record.respawn_location_type = 'Other'
	record.type = { name = 'Manmade_VisibleOnInteraction', classification = 'Manmade' }
	record.parent = { uuid = '34ff378f-faee-47bb-b5fe-f505e665c5ca', name = 'Stanton', type_name = 'Star' }
	record.inheritedJurisdiction = 'UEE'
	return record
end

local ARC_L2_ARGS =
	{ classification = 'Rest stop', parent = 'ArcCorp (planet)', lagrange = 'L2', operator = 'Rest & Relax' }

function suite:testZoneFromRecordType()
	local zone = Place._internal.zone
	self:assertEquals('surface', zone(newBabbage(), { classification = 'Landing zone' }))
	self:assertEquals('orbit', zone({ type = { name = 'Manmade' }, parent = { type_name = 'Planet' } }, {}))
	self:assertEquals('star', zone({ type = { name = 'Manmade' }, parent = { type_name = 'Star' } }, {}))
	self:assertEquals('inside', zone({ type = { name = 'Outpost' }, parent = { type_name = 'LandingZone' } }, {}))
end

function suite:testZoneCuratedLagrangeAndRecordless()
	local zone = Place._internal.zone
	self:assertEquals('lagrange', zone(arcL2(), ARC_L2_ARGS))
	self:assertEquals('inside', zone({}, { classification = 'Spaceport' }))
	self:assertEquals('orbit', zone({ type = { name = 'NavPoint' } }, { zone = 'Orbit' }))
end

--- An Outpost parented to an asteroid base is inside it, the same as a
--- clinic inside a station.
function suite:testZoneOutpostInsideAnAsteroidBaseIsInside()
	self:assertEquals(
		'inside',
		Place._internal.zone({ type = { name = 'Outpost' }, parent = { type_name = 'Asteroid_ValidQT' } }, {})
	)
end

--- A curated |zone= overrides the record: the API parents Levski to the star
--- (Nyx) though it sits on Delamar, and the migration sets |zone= on pages
--- like it deliberately, not as stale legacy data.
function suite:testCuratedZoneOverridesTheRecord()
	local record = { type = { name = 'Manmade' }, parent = { type_name = 'Star' } }
	self:assertEquals('surface', Place._internal.zone(record, { zone = 'surface' }))
	self:assertEquals('star', Place._internal.zone(record, {}))
end

--- An invalid curated |zone= is dropped rather than applied: it still falls
--- through to the record, the same as if it had not been given at all.
function suite:testInvalidZoneFallsThroughToTheRecord()
	self:assertEquals(
		'star',
		Place._internal.zone({ type = { name = 'Manmade' }, parent = { type_name = 'Star' } }, { zone = 'nowhere' })
	)
end

function suite:testCuratedParentWinsAndDropsTheQualifier()
	local name, target = Place._internal.parentAnchor(newBabbage(), { parent = 'MicroTech (planet)' })
	self:assertEquals('MicroTech', name)
	self:assertEquals('MicroTech (planet)', target)
	name = Place._internal.parentAnchor(newBabbage(), {})
	self:assertEquals('microTech', name)
end

--- A piped |parent= stores the link TARGET, not the display text a pipe
--- substitutes for it; the display keeps the editor's own wording.
function suite:testPipedParentStoresTargetAndShowsPipeText()
	local name, target = Place._internal.parentAnchor(newBabbage(), { parent = '[[MicroTech (planet)|microTech]]' })
	self:assertEquals('microTech', name)
	self:assertEquals('MicroTech (planet)', target)
end

function suite:testTypeInfoFromClass()
	self:assertDeepEquals({ name = 'Rest stop', category = 'Rest stops' }, Place.getTypeInfo(ctx(arcL2(), ARC_L2_ARGS)))
	self:assertDeepEquals(
		{ name = 'Location', category = 'Locations with an unknown classification' },
		Place.getTypeInfo(ctx(arcL2(), { classification = 'Landmark' }))
	)
end

function suite:testCategoriesAreOperatorAndSystem()
	self:assertDeepEquals({ 'Rest & Relax', 'Stanton system' }, Place.getCategories(ctx(arcL2(), ARC_L2_ARGS)))
end

--- A piped |operator= categorises and stores the link TARGET; the Operator
--- row shows the editor's own pipe text.
function suite:testPipedOperatorUsesTargetForStorageAndPipeTextForDisplay()
	local args = { operator = '[[Rest & Relax|R&R]]' }
	self:assertDeepEquals({ 'Rest & Relax', 'Stanton system' }, Place.getCategories(ctx(arcL2(), args)))
	self:assertEquals('Rest & Relax', Place.getStructuredData(ctx(arcL2(), args)).operator)
	local sections = Place.getSections(ctx(arcL2(), args))
	self:assertEquals('[[Rest & Relax|R&R]]', sections[1].items[2].content)
end

--- |lagrange= is case-insensitive and stores upper-case.
function suite:testLagrangePointIsUppercasedAndValidated()
	local data = Place.getStructuredData(
		ctx(arcL2(), { classification = 'Rest stop', operator = 'Rest & Relax', lagrange = 'l2' })
	)
	self:assertEquals('L2', data.lagrange_point)
end

--- An unrecognised |lagrange= is dropped outright: not stored, not shown, and
--- it must not force the lagrange zone (the record decides instead). The
--- tracking category is the only trace it leaves.
function suite:testInvalidLagrangeIsIgnoredAndTracked()
	local args = { classification = 'Rest stop', operator = 'Rest & Relax', lagrange = 'Sunward from Bloom' }
	local data = Place.getStructuredData(ctx(arcL2(), args))
	self:assertEquals(nil, data.lagrange_point)
	self:assertEquals('star', data.zone)
	self:assertDeepEquals(
		{ 'Rest & Relax', 'Stanton system', 'Locations with an invalid zone or Lagrange point' },
		Place.getCategories(ctx(arcL2(), args))
	)
end

--- A |zone= outside the closed vocabulary is likewise dropped and tracked.
function suite:testInvalidZoneArgIsTracked()
	self:assertDeepEquals(
		{ 'Rest & Relax', 'Stanton system', 'Locations with an invalid zone or Lagrange point' },
		Place.getCategories(ctx(arcL2(), { operator = 'Rest & Relax', zone = 'nowhere' }))
	)
end

function suite:testShortDescriptions()
	self:assertEquals(
		'Landing zone on microTech in the Stanton system',
		Place.getShortDescription(ctx(newBabbage(), { classification = 'Landing zone' }))
	)
	self:assertEquals(
		'Rest stop at ArcCorp L2 in the Stanton system',
		Place.getShortDescription(ctx(arcL2(), ARC_L2_ARGS))
	)
	self:assertEquals(
		'Spaceport in Area18 in the Stanton system',
		Place.getShortDescription(ctx({}, { classification = 'Spaceport', parent = 'Area18', system = 'Stanton' }))
	)
end

function suite:testStructuredDataForARestStop()
	local data = Place.getStructuredData(ctx(arcL2(), ARC_L2_ARGS))
	self:assertEquals('Rest stop', data.classification)
	self:assertEquals('lagrange', data.zone)
	self:assertEquals('L2', data.lagrange_point)
	self:assertEquals('Rest & Relax', data.operator)
	self:assertEquals('ArcCorp (planet)', data.parent)
	self:assertEquals('Stanton system', data.system)
	self:assertEquals('UEE', data.jurisdiction)
	self:assertDeepEquals(ARC_L2_AMENITIES, data.amenities)
end

function suite:testSectionsForALandingZone()
	local sections =
		Place.getSections(ctx(newBabbage(), { classification = 'Landing zone', operator = 'MicroTech (company)' }))
	local labels = {}
	for _, item in ipairs(sections[1].items) do
		labels[#labels + 1] = item.label
	end
	self:assertDeepEquals({ 'Location', 'Operator', 'Jurisdiction' }, labels)
	self:assertEquals('[[MicroTech (company)|MicroTech]]', sections[1].items[2].content)
	self:assertEquals('amenities', sections[2].key)
	self:assertEquals('Hangar (XL) · Garage · Vehicle services', sections[2].items[1].content)
end

function suite:testGetFooterButtonsAndMetadataItemsFromStarmapCode()
	local args = { starmapcode = 'STANTON.STATIONS.X' }
	local buttons = Place.getFooterButtons(ctx({}, args))
	self:assertEquals(1, #buttons)
	self:assertEquals('Starmap', buttons[1].label)
	self:assertEquals('https://robertsspaceindustries.com/starmap?location=STANTON.STATIONS.X', buttons[1].url)
	local items = Place.getMetadataItems(ctx({}, args))
	self:assertEquals(1, #items)
	self:assertEquals('Starmap code', items[1].label)
end

function suite:testGetFooterButtonsAndMetadataItemsWithoutArgAreEmpty()
	self:assertDeepEquals({}, Place.getFooterButtons(ctx({}, {})))
	self:assertDeepEquals({}, Place.getMetadataItems(ctx({}, {})))
end

-- ── enrich: jurisdiction resolution ─────────────────────────────────────────

--- Swap Jurisdiction.fetch for a fixed table for the duration of fn, as
--- withLocationRecords in Location/testcases.lua does.
local function withJurisdictionRecords(records, fn)
	local saved = Jurisdiction.fetch
	Jurisdiction.fetch = function(uuid)
		return records[uuid]
	end
	local ok, err = pcall(fn)
	Jurisdiction.fetch = saved
	if not ok then
		error(err, 0)
	end
end

--- Swap Store.pageValue for a stub for the duration of fn.
local function withStorePageValue(stub, fn)
	local saved = Store.pageValue
	Store.pageValue = stub
	local ok, err = pcall(fn)
	Store.pageValue = saved
	if not ok then
		error(err, 0)
	end
end

--- A record with a uuid and no jurisdiction of its own, parented to a body.
local function outpostRecord()
	return {
		uuid = 'test-outpost',
		name = 'Test Outpost',
		type = { name = 'Outpost' },
		parent = { uuid = 'test-parent', name = 'Some Body', type_name = 'Planet' },
	}
end

function suite:testEnrichWalksTheChainForARecordWithAUuid()
	withJurisdictionRecords(
		{ ['test-parent'] = { uuid = 'test-parent', jurisdiction = { name = 'Hurston Dynamics' } } },
		function()
			local apiData = Place.enrich(ctx(outpostRecord(), {}))
			self:assertEquals('Hurston Dynamics', apiData.inheritedJurisdiction)
		end
	)
end

--- A curated |jurisdiction= wins outright: enrich must not walk the chain or
--- read the Store, and getStructuredData reports the curated value.
function suite:testEnrichSkipsTheWalkAndLookupForACuratedJurisdiction()
	local fetchCalled, pageValueCalled = false, false
	local savedFetch, savedPageValue = Jurisdiction.fetch, Store.pageValue
	Jurisdiction.fetch = function()
		fetchCalled = true
		return nil
	end
	Store.pageValue = function()
		pageValueCalled = true
		return nil
	end
	local ok, err = pcall(function()
		local args = { jurisdiction = 'Green Imperial' }
		local apiData = Place.enrich(ctx(outpostRecord(), args))
		self:assertFalse(fetchCalled)
		self:assertFalse(pageValueCalled)
		self:assertEquals('Green Imperial', Place.getStructuredData(ctx(apiData, args)).jurisdiction)
	end)
	Jurisdiction.fetch = savedFetch
	Store.pageValue = savedPageValue
	if not ok then
		error(err, 0)
	end
end

--- A page with no record reads its curated parent's stored Jurisdiction.
function suite:testEnrichReadsTheCuratedParentsStoredJurisdictionWhenThereIsNoRecord()
	local calledWith
	withStorePageValue(function(page, displayName, kind)
		calledWith = { page, displayName, kind }
		return 'microTech'
	end, function()
		local apiData = Place.enrich(ctx({}, { parent = 'Area18' }))
		self:assertEquals('microTech', apiData.inheritedJurisdiction)
	end)
	self:assertDeepEquals({ 'Area18', 'Jurisdiction', 'Location' }, calledWith)
end

--- A <ref> after the link reaches Lua as a strip marker; the link target must
--- still be what is stored and categorised.
local REF_MARKER = '\127\'"`UNIQ--ref-0000001A-QINU`"\'\127'

function suite:testPipedOperatorBeforeARefStoresTheTarget()
	local args = { classification = 'Rest stop', operator = '[[Rest & Relax|R&R]]' .. REF_MARKER }
	self:assertEquals('Rest & Relax', Place.getStructuredData(ctx(arcL2(), args)).operator)
	self:assertEquals('Rest & Relax', Place.getCategories(ctx(arcL2(), args))[1])
	local sections = Place.getSections(ctx(arcL2(), args))
	self:assertEquals('[[Rest & Relax|R&R]]' .. REF_MARKER, sections[1].items[2].content)
end

--- A plain, unlinked |operator= (no wikilink of its own) renders linked to
--- itself, the same target both ways round.
function suite:testPlainOperatorRendersLinkedToItself()
	local sections = Place.getSections(ctx(arcL2(), { operator = 'Rest & Relax' }))
	self:assertEquals('[[Rest & Relax|Rest & Relax]]', sections[1].items[2].content)
end

--- A Lagrange point names a point OF a body; without a curated parent the
--- record's star is all the page has.
function suite:testLagrangeWithoutParentIsTracked()
	local categories = Place.getCategories(ctx(arcL2(), { classification = 'Rest stop', lagrange = 'L2' }))
	local found = false
	for _, category in ipairs(categories) do
		found = found or category == 'Locations with an invalid zone or Lagrange point'
	end
	self:assertTrue(found)
end

function suite:testAmenitySummaryForALandingZoneCard()
	self:assertEquals(
		'Hospital (T1) · Hangar (XL) · Commodity trading',
		Amenities.summary(Amenities.names(amenityRecord(NEW_BABBAGE_AMENITIES)))
	)
	self:assertEquals(nil, Amenities.summary({}))
end

return suite
