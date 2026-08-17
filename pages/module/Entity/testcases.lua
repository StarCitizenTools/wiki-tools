require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Entity = require('Module:Entity')

local suite = ScribuntoUnit:new()

local isIdentifiable = Entity._internal.isIdentifiable

--- Only the two fields the identity guard reads out of a Data.get result.
--- @param fields nil|{ apiData: table|nil, matchedKind: table|nil }
--- @return table
local function result(fields)
	fields = fields or {}
	return { apiData = fields.apiData or {}, matchedKind = fields.matchedKind }
end

function suite:testIdentifiableByUuid()
	self:assertTrue(isIdentifiable({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201' }, result()))
end

function suite:testIdentifiableByCuratedName()
	self:assertTrue(isIdentifiable({ name = 'Stanton system' }, result()))
end

function suite:testIdentifiableByApiRecordName()
	self:assertTrue(isIdentifiable({}, result({ apiData = { name = 'Stanton System' } })))
end

--- A bare `{{Location}}` on a lore system: the facade injects |kind=Location,
--- the editorial fork resolves it, and the page's identity is its title. Before
--- this guard learned about kinds it rejected the invocation outright, so a live
--- `{{Location}}` on Nexus system rendered the red error even though the starmap
--- record resolves and the infobox would have been correct.
function suite:testIdentifiableByDeclaredKindAlone()
	self:assertTrue(isIdentifiable({ kind = 'Location' }, result({ matchedKind = { name = 'Location' } })))
end

--- The kind must have actually CLAIMED the page. A misspelled |kind= resolves to
--- no kind, so it stays an error rather than silently rendering a title-only
--- shell — this is why the guard tests result.matchedKind, not raw args.kind.
function suite:testUnresolvedKindIsStillAnError()
	self:assertFalse(isIdentifiable({ kind = 'Lcoation' }, result()))
end

function suite:testNothingAtAllIsAnError()
	self:assertFalse(isIdentifiable({}, result()))
end

return suite
