require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local static = require('Module:DataGrid/Static')
local DataGrid = require('Module:DataGrid')
local BucketQuery = require('Module:BucketQuery')
local bucketLib = require('mw.ext.bucket')

local MANIFEST = {
	['Name'] = { type = 'TEXT', bucket = 'entity', field = 'name' },
	['Image'] = { type = 'TEXT', bucket = 'entity', field = 'image' },
	['Manufacturer'] = { type = 'PAGE', bucket = 'entity', field = 'manufacturer' },
	['Loaner vehicle'] = { type = 'PAGE', bucket = 'vehicle', field = 'loaner_vehicle', repeated = true },
	['Orders'] = { type = 'TEXT', bucket = 'mission', field = 'orders', repeated = true },
	['Legality'] = { type = 'TEXT', bucket = 'mission', field = 'legality' },
	['Uec'] = { type = 'INTEGER', bucket = 'mission', field = 'uec' },
	['Available'] = { type = 'BOOLEAN', bucket = 'mission', field = 'available' },
}

-- Store never reloads between suites, so a bare setManifests would leak the fake
-- manifest into every suite that requires Store afterwards; always restore the
-- real one (setManifests(nil)) before propagating any assertion failure.
local function withManifest(fn)
	BucketQuery._internal.setManifests({ MANIFEST })
	local ok, err = pcall(fn)
	BucketQuery._internal.setManifests(nil)
	if not ok then
		error(err, 0)
	end
end

--- The runner's mw.title.new answers every title, so the image guard's rejection
--- path is only reachable by standing in for it.
local function withRejectedTitle(bad, fn)
	local original = mw.title.new
	mw.title.new = function(text)
		if text == bad then
			return nil
		end
		return original(text)
	end
	local ok, err = pcall(fn)
	mw.title.new = original
	if not ok then
		error(err, 0)
	end
end

--- The contents of every `<td>` in `html`, in document order.
local function cells(html)
	local out = {}
	for content in html:gmatch('<td.->(.-)</td>') do
		out[#out + 1] = content
	end
	return out
end

--- The contents of every `<th>` in `html`, in document order.
local function headers(html)
	local out = {}
	for content in html:gmatch('<th.->(.-)</th>') do
		out[#out + 1] = content
	end
	return out
end

--- The opening tag of every `<th>` or `<td>`, attributes included, in document
--- order, so a test can assert which column carries the image markers.
local function openTags(html, name)
	local out = {}
	for tag in html:gmatch('(<' .. name .. '.->)') do
		out[#out + 1] = tag
	end
	return out
end

--- One table from one row, for the cell-rendering tests.
local function render(columnSource, row, kind)
	return static._internal.buildTable({ row }, DataGrid.parseColumns(columnSource), kind)
end

-- The query is Module:DataGrid's: a category plus a filter reach Bucket as
-- conditions on the primary bucket, with the mission table joined for the
-- column that lives there.
function suite:testQuerySpecForCategoryAndFilter()
	bucketLib._reset()
	withManifest(function()
		local request, err = DataGrid.resolveArgs({
			category = 'Wikelo ship contracts',
			filter = 'Legality = Verified',
			kind = 'Mission',
			columns = 'Orders',
		}, { leadImage = false })
		self:assertEquals(nil, err)
		DataGrid.runQuery(request.spec)
		local chain = bucketLib._chains[1]
		self:assertEquals('entity', chain.bucket)
		self:assertEquals('mission', chain.join[1][1])
		self:assertEquals('Category:Wikelo ship contracts', chain.where[1][1])
		self:assertDeepEquals({ 'mission.legality', '=', 'Verified' }, chain.where[2])
		self:assertEquals(1000, chain.limit)
		-- A table with no image column does not fetch the image either. Fields of the
		-- primary bucket select unprefixed; a joined bucket's carry its name.
		self:assertDeepEquals({ 'page_name', 'name', 'mission.orders' }, chain.select)
	end)
end

-- A wrapping module's `primary` reaches the query, which is what lets a table
-- whose subject is not an Entity page list at all: rooted on `entity` the
-- category condition can only match pages that have an Entity row, so the rows
-- come back short rather than wrong-looking. The entity table stays a LEFT join
-- for the lead `Name`, so a page with no Entity row still lists.
function suite:testPrimaryRootsTheQueryOnTheWrappersBucket()
	bucketLib._reset()
	withManifest(function()
		local request, err = DataGrid.resolveArgs({
			category = 'Jump Point Year One',
			columns = 'Legality',
		}, static._internal.resolveOptions({ primary = 'mission' }))
		self:assertEquals(nil, err)
		DataGrid.runQuery(request.spec)
		local chain = bucketLib._chains[1]
		self:assertEquals('mission', chain.bucket)
		self:assertEquals('entity', chain.join[1][1])
		self:assertEquals('Category:Jump Point Year One', chain.where[1][1])
		-- The wrapper's own bucket selects unprefixed; the joined entity table does not.
		self:assertDeepEquals({ 'page_name', 'entity.name', 'legality' }, chain.select)
	end)
end

-- Options merge rather than replace: a wrapper sets `primary` without having to
-- know that the static table also opts out of the grid's lead image, and cannot
-- switch that image back on by passing its own options.
function suite:testResolveOptionsMergesAndKeepsLeadImageOff()
	local merged = static._internal.resolveOptions({ primary = 'maintenance', leadImage = true })
	self:assertEquals('maintenance', merged.primary)
	self:assertEquals(false, merged.leadImage)
	-- No options at all still opts the lead image out.
	self:assertEquals(false, static._internal.resolveOptions(nil).leadImage)
end

-- The page name is the one lead column, showing the stored name while the link
-- targets the page. The image is one of the editor's columns and renders where
-- they put it, with the cell class the stylesheet keys on and a header that opts
-- out of sorting.
function suite:testNameLeadsAndTheImageRendersWhereItIsPlaced()
	withManifest(function()
		local html = render('Legality\nImage', {
			Name = 'Wikelo Arrive to System',
			DisplayName = 'Arrive to System',
			Image = 'Wikelo contract.jpg',
			Legality = 'Verified',
		})
		self:assertDeepEquals({ 'Name', 'Legality', 'Image' }, headers(html))
		self:assertDeepEquals({ '<th>', '<th>', '<th class="unsortable">' }, openTags(html, 'th'))
		local row = cells(html)
		self:assertEquals('[[Wikelo Arrive to System|Arrive to System]]', row[1])
		self:assertEquals('Verified', row[2])
		self:assertEquals('[[File:Wikelo contract.jpg|200px|link=Wikelo Arrive to System]]', row[3])
		self:assertDeepEquals({ '<td>', '<td>', '<td class="t-datagrid-static__image">' }, openTags(html, 'td'))
	end)
end

-- A table that does not ask for an image has none, even when the row carries one
-- (another table on the page may want it): no cell, no header, no class.
function suite:testTableWithoutAnImageColumnHasNoImage()
	withManifest(function()
		local html = render('Legality', {
			Name = 'Wikelo Arrive to System',
			DisplayName = 'Arrive to System',
			Image = 'Wikelo contract.jpg',
			Legality = 'Verified',
		})
		self:assertDeepEquals({ 'Name', 'Legality' }, headers(html))
		self:assertDeepEquals({ '[[Wikelo Arrive to System|Arrive to System]]', 'Verified' }, cells(html))
		self:assertEquals(nil, html:find('File:', 1, true))
		self:assertEquals(nil, html:find('t-datagrid-static__image', 1, true))
		self:assertEquals(nil, html:find('unsortable', 1, true))
	end)
end

-- The image column is recognised by what it resolves to, not by the name it is
-- given, so `label=` retitles it and still renders the thumbnail.
function suite:testRelabelledImageColumnStillRendersAThumbnail()
	withManifest(function()
		local html = render('Image ; label=Contract image', {
			Name = 'Wikelo Arrive to System',
			['Contract image'] = 'Wikelo contract.jpg',
		})
		self:assertDeepEquals({ 'Name', 'Contract image' }, headers(html))
		self:assertDeepEquals({ '<th>', '<th class="unsortable">' }, openTags(html, 'th'))
		self:assertEquals('[[File:Wikelo contract.jpg|200px|link=Wikelo Arrive to System]]', cells(html)[2])
	end)
end

-- A PAGE property is a bare title in the row, so the cell has to build the link;
-- a repeated one lists them comma-separated.
function suite:testPageCellLinksAndListsLinks()
	withManifest(function()
		local html = render('Manufacturer\nLoaner vehicle', {
			Name = 'Gladius',
			Manufacturer = 'Aegis Dynamics',
			['Loaner vehicle'] = { 'Avenger Titan', 'Gladius Valiant' },
		})
		local row = cells(html)
		self:assertEquals('[[Aegis Dynamics]]', row[2])
		self:assertEquals('[[Avenger Titan]], [[Gladius Valiant]]', row[3])
	end)
end

-- The whole point of the static table: a repeated TEXT value keeps its stored
-- wikitext, so "50x [[Council Scrip]]" reaches the parser as text plus a link on
-- the page name alone. One value per line, since these are statements, not tags.
function suite:testRepeatedTextCellKeepsItsWikilinks()
	withManifest(function()
		local html = render('Orders', {
			Name = 'Wikelo Arrive to System',
			Orders = { '50x [[Council Scrip]]', '2x [[Quantanium]]' },
		})
		self:assertEquals('50x [[Council Scrip]]<br>2x [[Quantanium]]', cells(html)[2])
	end)
end

-- A number is grouped in the content language; a boolean is the word Yes or No,
-- not the grid's icon, because an icon is not text browser find can reach.
function suite:testNumberAndBooleanCells()
	withManifest(function()
		local row = cells(render('Uec\nAvailable', { Name = 'Contract', Uec = 25000, Available = true }))
		self:assertEquals('25,000', row[2])
		self:assertEquals('Yes', row[3])
		self:assertEquals('No', cells(render('Available', { Name = 'Contract', Available = false }))[2])
	end)
end

-- A field a row does not have is absent from it (Store's contract), which must
-- leave an empty cell rather than shift the row's remaining values left.
function suite:testMissingValueRendersAnEmptyCell()
	withManifest(function()
		local row = cells(render('Orders\nUec', { Name = 'Contract', Uec = 5 }))
		self:assertEquals(3, #row)
		self:assertEquals('[[Contract]]', row[1])
		self:assertEquals('', row[2])
		self:assertEquals('5', row[3])
	end)
end

-- A stored filename Title validation rejects drops its own cell; the rest of the
-- row still renders, instead of the bad name erroring the whole table.
function suite:testInvalidImageTitleDropsOnlyItsCell()
	withManifest(function()
		withRejectedTitle('File:Bad%27name.jpg', function()
			local row = cells(render('Legality\nImage', {
				Name = 'Contract',
				Image = 'Bad%27name.jpg',
				Legality = 'Verified',
			}))
			self:assertEquals('[[Contract]]', row[1])
			self:assertEquals('Verified', row[2])
			self:assertEquals('', row[3])
		end)
	end)
end

-- A column naming a property that does not exist fails the render with the
-- message {{Data table}} gives, under this module's own name.
function suite:testUnknownPropertyError()
	withManifest(function()
		local request, err = DataGrid.resolveArgs({ category = 'Guns', columns = 'Bogus' })
		self:assertEquals(nil, request)
		self:assertEquals(
			'<strong class="error">Module:DataGrid/Static: unknown property &#39;Bogus&#39;</strong>',
			static._internal.fail(err)
		)
	end)
end

-- `sort` orders the served rows, the static equivalent of the grid's initial
-- sort. Numeric values compare as numbers, and rows tied on the sort column keep
-- page-title order rather than being shuffled by table.sort.
function suite:testSortOrdersRowsAndKeepsTitleOrderOnTies()
	local results = {
		{ Name = 'Charlie', Uec = 5 },
		{ Name = 'Bravo', Uec = 40 },
		{ Name = 'Alpha', Uec = 5 },
	}
	static._internal.applySort(results, { { alias = 'Uec', direction = 'desc' } })
	self:assertEquals('Bravo', results[1].Name)
	self:assertEquals('Alpha', results[2].Name)
	self:assertEquals('Charlie', results[3].Name)
end

-- Numeric comparison is decided per key: a text first key does not make a
-- numeric second key compare as text ("40" before "5").
function suite:testSortDecidesNumericPerKey()
	local results = {
		{ Name = 'Alpha', Kind = 'Ship', Uec = 5 },
		{ Name = 'Bravo', Kind = 'Ship', Uec = 40 },
		{ Name = 'Charlie', Kind = 'Car', Uec = 1 },
	}
	static._internal.applySort(results, {
		{ alias = 'Kind', direction = 'desc' },
		{ alias = 'Uec', direction = 'asc' },
	})
	self:assertEquals('Alpha', results[1].Name)
	self:assertEquals('Bravo', results[2].Name)
	self:assertEquals('Charlie', results[3].Name)
end

-- A later key orders only the rows tied on every earlier key.
function suite:testSortAppliesKeysInPrecedence()
	local results = {
		{ Name = 'Alpha', Status = 'Released', Date = '2026-01-01' },
		{ Name = 'Bravo', Status = 'Upcoming', Date = '' },
		{ Name = 'Charlie', Status = 'Released', Date = '2026-08-26' },
	}
	static._internal.applySort(results, {
		{ alias = 'Status', direction = 'desc' },
		{ alias = 'Date', direction = 'desc' },
	})
	self:assertEquals('Bravo', results[1].Name)
	self:assertEquals('Charlie', results[2].Name)
	self:assertEquals('Alpha', results[3].Name)
end

return suite
