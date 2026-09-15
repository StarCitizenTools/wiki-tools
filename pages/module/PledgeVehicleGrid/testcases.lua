require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Grid = require('Module:PledgeVehicleGrid')
local AGGridColumns = require('Module:AGGridColumns')
local bucketQuery = require('Module:BucketQuery')
local bucketLib = require('mw.ext.bucket')

local suite = ScribuntoUnit:new()

function suite:testFlightReadyLabelStripsPrefixes()
	self:assertEquals('Alpha 3.24.3', Grid._internal.flightReadyLabel('Update:Star Citizen Alpha 3.24.3'))
	self:assertEquals('Alpha 3.24.3', Grid._internal.flightReadyLabel('Star Citizen Alpha 3.24.3'))
	self:assertEquals(nil, Grid._internal.flightReadyLabel(nil))
	self:assertEquals(nil, Grid._internal.flightReadyLabel(''))
end

function suite:testSpecShape()
	local spec = Grid._internal.buildSpec()
	self:assertEquals('Vehicle', spec.kind)
	self:assertEquals(1000, spec.limit)
	self:assertDeepEquals({ any = { 'Category:Pledge ships', 'Category:Pledge vehicles' } }, spec.filters[1])
	local keys = {}
	for _, col in ipairs(spec.columns) do
		keys[col.as] = col.property or col.builtin
	end
	self:assertEquals('page_name', keys.Name)
	self:assertEquals('Name', keys.DisplayName)
	self:assertEquals('Image', keys.Image)
	self:assertEquals('Manufacturer', keys.Manufacturer)
	self:assertEquals('Added in version', keys['Flight ready'])
	self:assertEquals('Scm speed', keys['SCM speed'])
	self:assertEquals(nil, keys.Uuid)
	self:assertEquals(33, #spec.columns)
end

-- Every property the spec asks for must resolve against the real manifests, so
-- a manifest rename shows up here rather than as a red error on the live page.
function suite:testSpecColumnsResolveThroughStore()
	bucketQuery._internal.setManifests(nil)
	local spec = Grid._internal.buildSpec()
	for _, col in ipairs(spec.columns) do
		if col.property then
			self:assertTrue(bucketQuery.resolve(col.property, 'Vehicle') ~= nil, col.property)
		end
	end
end

-- p.main contains a Store failure (rate limit, bad manifest) the same way it
-- contains an empty result: one user-visible message, no script error.
function suite:testMainReportsStoredMessageOnStoreFailure()
	bucketQuery._internal.setManifests(nil)
	bucketLib._reset()
	bucketLib._failNext = true
	self:assertEquals(
		'<strong class="error">Module:PledgeVehicleGrid: no pledge vehicles stored.</strong>',
		Grid.main(nil)
	)
	bucketLib._reset()
end

--- A page whose stored name differs from its title (Dragonfly / Dragonfly
--- Black) shows the stored name as the card title while the link still
--- targets the page (Store's page_name builtin does not carry a page's
--- {{DISPLAYTITLE}}).
function suite:testVehicleCardShowsDisplayNameOverTitle()
	local rows =
		AGGridColumns.buildRowData({ { Name = 'Dragonfly', DisplayName = 'Dragonfly Black' } }, Grid._internal.columns)
	local card = rows[1].vehicle
	self:assertEquals('Dragonfly Black', card.title)
	self:assertEquals('Dragonfly', card.titleHref)
end

return suite
