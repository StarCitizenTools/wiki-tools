require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Maintenance = require('Module:Maintenance')

local suite = ScribuntoUnit:new()

function suite:testBuildRowMapsEachStatus()
	self:assertEquals('Outdated', Maintenance.buildRow({ status = 'outdated' }).status)
	self:assertEquals('Obsolete', Maintenance.buildRow({ status = 'obsolete' }).status)
	self:assertEquals('Needs update', Maintenance.buildRow({ status = 'update' }).status)
	self:assertEquals('Needs cleanup', Maintenance.buildRow({ status = 'cleanup' }).status)
	self:assertEquals('Proposed for deletion', Maintenance.buildRow({ status = 'delete' }).status)
end

function suite:testBuildRowNeedsAKnownStatus()
	self:assertEquals(nil, Maintenance.buildRow({}))
	self:assertEquals(nil, Maintenance.buildRow({ status = '' }))
	self:assertEquals(nil, Maintenance.buildRow({ status = 'stale' }))
end

function suite:testBuildRowCarriesReasonAndBanner()
	local row = Maintenance.buildRow({ status = 'update', why = 'New release', banner = 'Cleanup' })
	self:assertEquals('New release', row.reason)
	self:assertEquals('Cleanup', row.banner)
end

-- No default: a banner that does not name itself is a wiring mistake, and a row
-- silently attributed to {{Outdated}} would be worse than a blank cell.
function suite:testBannerIsStoredAsGivenAndNotDefaulted()
	self:assertEquals('Cleanup', Maintenance.buildRow({ status = 'cleanup', banner = 'Cleanup' }).banner)
	self:assertEquals(nil, Maintenance.buildRow({ status = 'outdated' }).banner)
end

-- Bucket keeps '' as a value, so a blank parameter would read as "has a reason"
-- to every query. Blank and absent must both store nothing.
function suite:testBlankParametersAreStoredAsNothing()
	self:assertEquals(nil, Maintenance.buildRow({ status = 'outdated', why = '   ' }).reason)
end

-- An editor citing a source inside `why` hands the module the parser's strip
-- marker, not the ref. Storing it would put UNIQ--ref-...-QINU in the table,
-- where it renders as literal garbage and can never resolve (live case:
-- Shepherd MediLift Drone).
function suite:testStripMarkersAreNotStored()
	local marker = '\127\'"`UNIQ--ref-00000012-QINU`"\'\127'
	self:assertEquals('Canceled.', Maintenance.buildRow({ status = 'obsolete', why = 'Canceled.' .. marker }).reason)
	self:assertEquals(nil, Maintenance.buildRow({ status = 'obsolete', why = marker }).reason)
end

function suite:testReasonKeepsTheEditorsWikitext()
	-- The report renders the stored value, so a link must survive as a link.
	local why = 'Superseded by [[Update:Star Citizen Alpha 4.10.0|Alpha 4.10.0]]'
	self:assertEquals(why, Maintenance.buildRow({ status = 'obsolete', why = why }).reason)
end

function suite:testStatusIsTrimmed()
	self:assertEquals('Obsolete', Maintenance.buildRow({ status = ' obsolete ' }).status)
end

return suite
