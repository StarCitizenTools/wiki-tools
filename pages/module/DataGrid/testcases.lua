require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local dg = require('Module:DataGrid')
local Store = require('Module:Entity/Store')
local bucketLib = require('mw.ext.bucket')

local MANIFEST = {
	['Name'] = { type = 'TEXT', bucket = 'entity', field = 'name' },
	['Image'] = { type = 'TEXT', bucket = 'entity', field = 'image' },
	['Manufacturer'] = { type = 'PAGE', bucket = 'entity', field = 'manufacturer' },
	['Size'] = { type = 'INTEGER', bucket = 'entity', field = 'size' },
	['Effects'] = { type = 'TEXT', bucket = 'entity', field = 'effects', repeated = true },
	['Loaner vehicle'] = { type = 'PAGE', bucket = 'vehicle', field = 'loaner_vehicle', repeated = true },
	['Weapon class'] = { type = 'TEXT', bucket = 'item_weapon', field = 'weapon_class' },
	['Ndr'] = { type = 'DOUBLE', bucket = { Commodity = 'commodity', Item = 'item_tool' }, field = 'ndr' },
}

-- Store never reloads between suites, so a bare setManifests would leak the fake
-- manifest into every suite that requires Store afterwards; always restore the
-- real one (setManifests(nil)) before propagating any assertion failure.
local function withManifest(fn)
	Store._internal.setManifests({ MANIFEST })
	local ok, err = pcall(fn)
	Store._internal.setManifests(nil)
	if not ok then
		error(err, 0)
	end
end

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

-- A PAGE eyebrow part links through Util.pageTarget; a plain-text part never
-- does, even when its value happens to read like a title.
function suite:testEyebrowResolverPageLinksTextDoesNot()
	local pageOnly = dg._internal.eyebrowResolver({ { alias = 'Manufacturer', page = true } }, nil)
	local v = pageOnly({ Manufacturer = 'Aegis Dynamics' })
	self:assertEquals('Aegis Dynamics', v.text)
	self:assertEquals('Aegis Dynamics', v.href)

	local textOnly = dg._internal.eyebrowResolver({ { alias = 'Type', page = false } }, nil)
	local v2 = textOnly({ Type = 'Aegis Dynamics' })
	self:assertEquals('Aegis Dynamics', v2.text)
	self:assertEquals(nil, v2.href)
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

-- A column aliasing to a reserved lead key (Name, Image or DisplayName) collides
-- with the lead.
function suite:testDuplicateAliasDetectsLeadCollision()
	self:assertEquals('Name', dg.duplicateAlias(dg.parseColumns('Foo ; label=Name')))
	self:assertEquals('Image', dg.duplicateAlias(dg.parseColumns('Bar ; label=Image')))
end

function suite:testDuplicateAliasDetectsDisplayNameCollision()
	self:assertEquals('DisplayName', dg.duplicateAlias(dg.parseColumns('Foo ; label=DisplayName')))
end

-- `Image` is reserved only while the caller keeps the lead column for it. A
-- caller that renders the image as an editor column (Module:DataGrid/Static)
-- drops the lead and names its own; Name and DisplayName stay reserved either way.
function suite:testDuplicateAliasFreesImageWhenTheLeadIsDropped()
	self:assertEquals('Image', dg.duplicateAlias(dg.parseColumns('Image')))
	self:assertEquals(nil, dg.duplicateAlias(dg.parseColumns('Image'), { leadImage = false }))
	self:assertEquals('Name', dg.duplicateAlias(dg.parseColumns('Foo ; label=Name'), { leadImage = false }))
	self:assertEquals(
		'DisplayName',
		dg.duplicateAlias(dg.parseColumns('Foo ; label=DisplayName'), { leadImage = false })
	)
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

-- parseFilters

function suite:testParseFiltersEquality()
	local f = dg.parseFilters('Weapon class = Pistol')
	self:assertDeepEquals({ { 'Weapon class', '=', 'Pistol' } }, f)
end

function suite:testParseFiltersOr()
	local f = dg.parseFilters('Subject type = Ground vehicle || Grav-lev vehicle')
	self:assertDeepEquals(
		{ { any = { { 'Subject type', '=', 'Ground vehicle' }, { 'Subject type', '=', 'Grav-lev vehicle' } } } },
		f
	)
end

-- An empty `||` part (a trailing separator, or two in a row) drops rather than
-- widening the match with a blank-value clause; a chain left with no non-empty
-- part at all is a parse error, same as parseCategory.
function suite:testParseFiltersDropsEmptyOrParts()
	local f = dg.parseFilters('Series = Pulse || HoverQuad ||')
	self:assertDeepEquals({ { any = { { 'Series', '=', 'Pulse' }, { 'Series', '=', 'HoverQuad' } } } }, f)
	local _, err = dg.parseFilters('Size = ||')
	self:assertEquals('Size = ||', err)
end

function suite:testParseFiltersHasValueAndNotEqual()
	self:assertDeepEquals({ { 'Weapon class', '+' } }, dg.parseFilters('Weapon class = +'))
	self:assertDeepEquals(
		{ { 'Production state', '!=', 'Flight ready' } },
		dg.parseFilters('Production state != Flight ready')
	)
end

function suite:testParseFiltersNumeric()
	self:assertDeepEquals({ { 'Size', '>=', 3 } }, dg.parseFilters('Size >= 3'))
	local _, err = dg.parseFilters('Size > big')
	self:assertEquals('Size > big', err)
end

-- The operator is whichever candidate starts EARLIEST in the line, not the
-- first one OPERATORS happens to list: a relational operator inside the
-- value must not pre-empt an earlier "=".
function suite:testParseFiltersOperatorInValueDoesNotPreemptAnEarlierEquals()
	self:assertDeepEquals({ { 'Name', '=', 'A<=B' } }, dg.parseFilters('Name = A<=B'))
end

function suite:testParseFiltersStripsLinkAndBlankLines()
	self:assertDeepEquals(
		{ { 'Manufacturer', '=', 'Aegis Dynamics' } },
		dg.parseFilters('\n  Manufacturer = [[Aegis Dynamics|Aegis]]\n\n')
	)
end

function suite:testParseFiltersRejectsBareLine()
	local _, err = dg.parseFilters('Category:Ships')
	self:assertEquals('Category:Ships', err)
end

-- `;` is the primary Or separator: a template parameter cannot carry a raw
-- `|` (MediaWiki splits it before Lua runs), so `datatablerewrite` emits `;`.
-- `||` remains accepted for an editor's `{{!}}{{!}}`.
function suite:testParseFiltersOrAcceptsSemicolon()
	local f = dg.parseFilters('Subject type = Ground vehicle; Grav-lev vehicle')
	self:assertDeepEquals(
		{ { any = { { 'Subject type', '=', 'Ground vehicle' }, { 'Subject type', '=', 'Grav-lev vehicle' } } } },
		f
	)
end

-- The property name and every value are entity-decoded, since {{PAGENAME}}
-- escapes "&" and "'" and Bucket stores the plain text.
function suite:testParseFiltersDecodesEntities()
	self:assertDeepEquals(
		{ { 'Manufacturer', '=', 'Klaus & Werner' } },
		dg.parseFilters('Manufacturer = Klaus &#38; Werner')
	)
	self:assertDeepEquals({ { 'Manufacturer', '=', "Whammer's" } }, dg.parseFilters('Manufacturer = Whammer&#39;s'))
end

-- parseCategory

function suite:testParseCategory()
	self:assertEquals('Category:Guns', dg.parseCategory('Guns'))
	self:assertDeepEquals(
		{ any = { 'Category:Pledge ships', 'Category:Pledge vehicles' } },
		dg.parseCategory('Pledge ships || Pledge vehicles')
	)
	local _, err = dg.parseCategory('Systems|+depth=0')
	self:assertEquals('Systems|+depth=0', err)
end

-- `;` is the primary Or separator; `||` (from an editor's `{{!}}{{!}}`) still
-- yields the same result.
function suite:testParseCategoryAcceptsSemicolonOrLegacyPipes()
	local bySemicolon = dg.parseCategory('Fighters; Light fighters')
	self:assertDeepEquals({ any = { 'Category:Fighters', 'Category:Light fighters' } }, bySemicolon)
	self:assertDeepEquals(bySemicolon, dg.parseCategory('Fighters || Light fighters'))
end

-- Category names are entity-decoded, since {{PAGENAME}} escapes "&" and "'".
function suite:testParseCategoryDecodesEntities()
	self:assertEquals('Category:Klaus & Werner', dg.parseCategory('Klaus &#38; Werner'))
end

-- A chain with no non-empty part must error, not silently become an Or() of
-- nothing: Bucket's standardizeWhere collapses a zero-child Or to nil, which
-- would drop the condition and list arbitrary rows instead of erroring.
function suite:testParseCategoryEmptyChainErrors()
	local category, err = dg.parseCategory('||')
	self:assertEquals(nil, category)
	self:assertEquals('||', err)
end

-- buildSpec

function suite:testBuildSpecColumnsAndKindError()
	withManifest(function()
		local spec = dg.buildSpec(
			nil,
			'Category:Guns',
			{ { 'Size', '=', 1 } },
			dg.parseColumns('Manufacturer ; filter\nSize ; label=S')
		)
		self:assertDeepEquals({ 'Category:Guns', { 'Size', '=', 1 } }, spec.filters)
		self:assertEquals('Name', spec.columns[1].as)
		self:assertEquals('Image', spec.columns[2].as)
		self:assertEquals('DisplayName', spec.columns[3].as)
		self:assertDeepEquals({ property = 'Size', as = 'S' }, spec.columns[5])
		local _, err = dg.buildSpec(nil, nil, {}, dg.parseColumns('Ndr'))
		self:assertTrue(err:find('Ndr', 1, true) ~= nil and err:find('kind=', 1, true) ~= nil)
		local _, err2 = dg.buildSpec(nil, nil, {}, dg.parseColumns('Bogus'))
		self:assertTrue(err2:find("'Bogus'", 1, true) ~= nil)
	end)
end

-- The lead columns are the grid's unless a caller opts out of the image one. No
-- options and an options table without `leadImage` are both the grid's own shape,
-- down to the position of each lead column.
function suite:testBuildSpecLeadColumnsAndTheImageOptOut()
	withManifest(function()
		local function leadAliases(options)
			local spec = dg.buildSpec(nil, 'Category:Guns', {}, dg.parseColumns('Size'), options)
			local out = {}
			for _, column in ipairs(spec.columns) do
				out[#out + 1] = column.as
			end
			return out, spec
		end
		self:assertDeepEquals({ 'Name', 'Image', 'DisplayName', 'Size' }, leadAliases(nil))
		self:assertDeepEquals({ 'Name', 'Image', 'DisplayName', 'Size' }, leadAliases({}))
		local aliases, spec = leadAliases({ leadImage = false })
		self:assertDeepEquals({ 'Name', 'DisplayName', 'Size' }, aliases)
		self:assertEquals('page_name', spec.columns[1].builtin)
		self:assertDeepEquals({ property = 'Name', as = 'DisplayName' }, spec.columns[2])
	end)
end

-- Locks the exact kind list the "add kind=" message advertises, so a new kind
-- (KINDS + Store's manifests) that forgets to update this string fails here.
function suite:testBuildSpecCrossKindMessageListsAllKinds()
	withManifest(function()
		local _, err = dg.buildSpec(nil, nil, {}, dg.parseColumns('Ndr'))
		self:assertEquals(
			'"Ndr" lives in a different table per kind; add kind= (Vehicle, Item, Commodity, Location, Mission, Company or Wearable set)',
			err
		)
	end)
end

-- A relational filter on a non-numeric property, or `!=` on a repeated one, is a
-- static contract violation: catching it here (the resolved entry already carries
-- `type`/`repeated`) means an inline error instead of a Store runtime error.
function suite:testBuildSpecRejectsRelationalOnNonNumeric()
	withManifest(function()
		local _, err = dg.buildSpec(nil, nil, { { 'Weapon class', '>=', 3 } }, {})
		self:assertEquals('"Weapon class" is not numeric; >= needs a number column', err)
	end)
end

function suite:testBuildSpecRejectsNotEqualOnRepeated()
	withManifest(function()
		local _, err = dg.buildSpec(nil, nil, { { 'Effects', '!=', 'Toxic' } }, {})
		self:assertEquals('"Effects" is a list; != cannot be applied', err)
	end)
end

-- Store.needsKind ignores the kind already given, so a property that is by-kind
-- but not stored for THIS kind needs its own message: "add kind=" would be wrong
-- advice when kind= is already set.
function suite:testBuildSpecNotStoredForKindMessage()
	withManifest(function()
		local _, err = dg.buildSpec('Vehicle', nil, {}, dg.parseColumns('Ndr'))
		self:assertEquals('"Ndr" is not stored for kind Vehicle', err)
	end)
end

-- resolveArgs

-- The whole {{Data table}} grammar in one call, so Module:DataGrid/Static reaches
-- the same spec and the same messages without a second copy of the argument
-- handling.
function suite:testResolveArgsBuildsSpecColumnsKindAndSort()
	withManifest(function()
		local request, err = dg.resolveArgs({
			category = 'Guns',
			filter = 'Size >= 3',
			columns = 'Manufacturer ; filter\nSize ; label=S',
			sort = 'S desc',
		})
		self:assertEquals(nil, err)
		self:assertDeepEquals({ 'Category:Guns', { 'Size', '>=', 3 } }, request.spec.filters)
		self:assertEquals(2, #request.columns)
		self:assertEquals(nil, request.kind)
		self:assertEquals('S', request.sort.alias)
		self:assertEquals('desc', request.sort.direction)
	end)
end

-- Each contract violation is reported at the point an editor meets it, in the
-- order resolveArgs checks them, so the two templates fail identically.
function suite:testResolveArgsReportsEachViolation()
	withManifest(function()
		local function errorFor(args)
			local _, err = dg.resolveArgs(args)
			return err
		end
		self:assertEquals(
			'"conditions" is not supported; use "filter" (see Template:Data table)',
			errorFor({ conditions = '[[Category:Guns]]', category = 'Guns', columns = 'Size' })
		)
		self:assertEquals('unknown kind "Ship"', errorFor({ kind = 'Ship', category = 'Guns', columns = 'Size' }))
		self:assertEquals(
			'category "Guns|+depth=0": use plain names separated by ";"; membership is direct only',
			errorFor({ category = 'Guns|+depth=0', columns = 'Size' })
		)
		self:assertEquals('provide "category" or "filter"', errorFor({ columns = 'Size' }))
		self:assertEquals('no columns defined', errorFor({ category = 'Guns' }))
		self:assertEquals('duplicate column "Size"', errorFor({ category = 'Guns', columns = 'Size\nSize' }))
		self:assertEquals("unknown property 'Bogus'", errorFor({ category = 'Guns', columns = 'Bogus' }))
		self:assertEquals(
			'sort "Bogus": no column named Bogus',
			errorFor({ category = 'Guns', columns = 'Size', sort = 'Bogus' })
		)
	end)
end

-- The option reaches both duplicateAlias and buildSpec: with the image lead
-- dropped, an `Image` column is accepted and becomes an ordinary spec column in
-- the editor's own position, while the same call with no options is the duplicate
-- it has always been.
function suite:testResolveArgsThreadsTheLeadImageOption()
	withManifest(function()
		local args = { category = 'Guns', columns = 'Size\nImage' }
		local _, err = dg.resolveArgs(args)
		self:assertEquals('duplicate column "Image"', err)
		local request, optedOutErr = dg.resolveArgs(args, { leadImage = false })
		self:assertEquals(nil, optedOutErr)
		local aliases = {}
		for _, column in ipairs(request.spec.columns) do
			aliases[#aliases + 1] = column.as
		end
		self:assertDeepEquals({ 'Name', 'DisplayName', 'Size', 'Image' }, aliases)
	end)
end

-- runQuery: a Bucket infrastructure failure must come back as an error value,
-- not propagate as a script error that would red-error the whole page.
function suite:testRunQueryReturnsAnErrorInsteadOfPropagating()
	bucketLib._reset()
	withManifest(function()
		bucketLib._failNext = true
		local spec = dg.buildSpec(nil, 'Category:Guns', {}, dg.parseColumns('Manufacturer'))
		local results, err = dg.runQuery(spec)
		self:assertEquals(nil, results)
		self:assertTrue(err ~= nil)
	end)
end

function suite:testRunQuerySucceedsWithoutFailure()
	bucketLib._reset()
	withManifest(function()
		bucketLib._setRows('entity', { { name = 'Test' } })
		local spec = dg.buildSpec(nil, 'Category:Guns', {}, dg.parseColumns('Manufacturer'))
		local results, err = dg.runQuery(spec)
		self:assertEquals(nil, err)
		self:assertEquals(1, #results)
	end)
end

-- sortRows

-- Rows arrive in Bucket's store order; sorting by Name lists them by page
-- title instead.
function suite:testSortRowsOrdersByName()
	local results = { { Name = 'Charlie' }, { Name = 'Alpha' }, { Name = 'Bravo' } }
	dg.sortRows(results)
	self:assertEquals('Alpha', results[1].Name)
	self:assertEquals('Bravo', results[2].Name)
	self:assertEquals('Charlie', results[3].Name)
end

-- A row with no Name (a manifest gap, or a builtin resolution failure) sorts
-- first rather than erroring on a nil comparison.
function suite:testSortRowsMissingNameSortsFirst()
	local results = { { Name = 'Alpha' }, {}, { Name = 'Bravo' } }
	dg.sortRows(results)
	self:assertEquals(nil, results[1].Name)
	self:assertEquals('Alpha', results[2].Name)
	self:assertEquals('Bravo', results[3].Name)
end

-- parseSort

function suite:testParseSortEmpty()
	self:assertEquals(nil, dg.parseSort('', dg.parseColumns('Size')))
	self:assertEquals(nil, dg.parseSort(nil, dg.parseColumns('Size')))
end

function suite:testParseSortDefaultsToAsc()
	local sort = dg.parseSort('Size', dg.parseColumns('Size'))
	self:assertEquals('Size', sort.alias)
	self:assertEquals('asc', sort.direction)
end

function suite:testParseSortExplicitDirection()
	local columns = dg.parseColumns('Size')
	self:assertEquals('asc', dg.parseSort('Size asc', columns).direction)
	self:assertEquals('desc', dg.parseSort('Size desc', columns).direction)
end

-- A name may itself contain spaces, so the whole string is tried as a bare name
-- before the trailing word is split off as a direction.
function suite:testParseSortMultiWordName()
	local columns = dg.parseColumns('Weapon class')
	self:assertEquals('asc', dg.parseSort('Weapon class', columns).direction)
	local sort = dg.parseSort('Weapon class desc', columns)
	self:assertEquals('Weapon class', sort.alias)
	self:assertEquals('desc', sort.direction)
end

-- The name matches a relabelled column's raw property too, but resolves to the
-- ALIAS (the result-row key buildSpecs' specs carry as `label`).
function suite:testParseSortMatchesPropertyOfRelabelledColumn()
	local columns = dg.parseColumns('Subtype ; label=Type')
	local sort = dg.parseSort('Subtype desc', columns)
	self:assertEquals('Type', sort.alias)
	self:assertEquals('desc', sort.direction)
end

function suite:testParseSortUnknownColumn()
	local _, err = dg.parseSort('Bogus', dg.parseColumns('Size'))
	self:assertEquals('sort "Bogus": no column named Bogus', err)
end

-- An unmatched name portion is reported even when a trailing word happens to be
-- a valid direction: the direction error path applies only once the NAME is
-- confirmed to be a real column.
function suite:testParseSortUnknownColumnWithDirectionWord()
	local _, err = dg.parseSort('Bogus desc', dg.parseColumns('Size'))
	self:assertEquals('sort "Bogus": no column named Bogus', err)
end

function suite:testParseSortBadDirection()
	local _, err = dg.parseSort('Size dsc', dg.parseColumns('Size'))
	self:assertEquals('sort "dsc": direction must be asc or desc', err)
end

-- An `eyebrow` column is folded into the lead card and never gets its own spec,
-- so naming one in `sort` must error rather than resolve to an alias that then
-- matches nothing in buildSpecs (a silent no-op).
function suite:testParseSortRejectsEyebrowColumn()
	local columns = dg.parseColumns('Manufacturer ; eyebrow')
	local sort, err = dg.parseSort('Manufacturer', columns)
	self:assertEquals(nil, sort)
	self:assertEquals('sort "Manufacturer": no column named Manufacturer', err)
	local sort2, err2 = dg.parseSort('Manufacturer desc', columns)
	self:assertEquals(nil, sort2)
	self:assertEquals('sort "Manufacturer": no column named Manufacturer', err2)
end

-- buildSpecs / column classification

function suite:testColumnKindsFromManifestTypes()
	withManifest(function()
		local columns = dg.parseColumns('Manufacturer\nSize ; filter\nEffects\nLoaner vehicle\nWeapon class ; filter')
		local specs = dg._internal.buildSpecs({}, columns, {}, false, nil)
		self:assertEquals('link', specs[2].kind)
		self:assertEquals('number', specs[3].kind)
		self:assertEquals('aggridSet', specs[3].filter)
		self:assertEquals('valueList', specs[4].kind)
		self:assertEquals('linkList', specs[5].kind)
		self:assertEquals('smart', specs[6].kind)
		self:assertEquals('aggridSet', specs[6].filter)
	end)
end

-- `sort` lands on the ONE spec whose alias matches, leaving every other spec's
-- `sort` unset so AG Grid's initial sort applies to a single column.
function suite:testBuildSpecsAppliesSortToMatchingSpec()
	withManifest(function()
		local columns = dg.parseColumns('Manufacturer\nSize')
		local sort = dg.parseSort('Size desc', columns)
		local specs = dg._internal.buildSpecs({}, columns, {}, false, nil, sort)
		self:assertEquals(nil, specs[2].sort)
		self:assertEquals('desc', specs[3].sort)
	end)
end

function suite:testBuildSpecsLeavesSortUnsetWhenNoneGiven()
	withManifest(function()
		local columns = dg.parseColumns('Size')
		local specs = dg._internal.buildSpecs({}, columns, {}, false, nil)
		self:assertEquals(nil, specs[2].sort)
	end)
end

return suite
