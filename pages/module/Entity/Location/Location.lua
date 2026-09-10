require('strict')

--- @module Entity/Location
--- Location kind: entities backed by the game-data /api/locations endpoint
--- (star systems, planets, moons, stations, …). Two classifications are
--- modelled: SolarSystem (the StarSystem leaf) and jump points (the JumpPoint
--- leaf). matches() claims exactly the records a leaf renders: SolarSystem
--- records and jump-point gates (the locations API types gates as 'Anomaly',
--- a token shared with wreck sites, so a gate is recognised by name — see
--- isJumpPointRecord). Every other location stays unclaimed until its leaf
--- exists. This module is kind identity only; the starmap vocabulary and
--- the two starmap bridges the leaves' enrich hooks call live in
--- Module:Entity/Location/Util.

local subtypeResolver = require('Module:Entity/SubtypeResolver')

local p = {}

--- Canonical kind name, exposed as Data.get().result.kind (non-empty and
--- unique, enforced by the Registry conformance test).
p.name = 'Location'

--- Kind-declared pages (Template:Location injects |kind=Location) render
--- through the editorial fork when no location record resolves — the entry
--- path for the ~84 lore systems that exist only in the starmap.
p.editorialMode = true

--- @type string
p.parent = 'Entity/Base'

--- Family token → leaf module path (SubtypeResolver adds 'Module:'). The
--- tokens are the leaves' p.family tags and the values a curated |family=
--- may name on a record-less page.
local LOCATION_SUBTYPE_MAP = {
	starsystem = 'Entity/Location/StarSystem',
	jumppoint = 'Entity/Location/JumpPoint',
}

--- The leaf a kind-declared page with no typed record resolves to: the lore
--- star systems that exist only in the starmap. Overridden by |family=.
p.defaultFamily = 'starsystem'

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'locations/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- The literal name suffix that separates a jump-point gate from every other
--- Anomaly-typed record. One constant so the length arithmetic below cannot
--- drift from the text.
local JUMP_POINT_SUFFIX = 'Jump Point'

--- Is this location record a jump-point gate? The locations API types jump
--- points as 'Anomaly', a token it shares with records that are NOT jump
--- points (the "Stanton-Pyro Jump Point Wreck Site"), so the type alone cannot
--- dispatch; a gate's name either ends exactly in "Jump Point" (every record
--- but one) or begins exactly with "Jump Point " (the one upstream misnaming,
--- "Jump Point Pyro Castra" — a real Pyro gate whose page still deserves its
--- record). Exact anchored matches, never a substring one: the wreck site
--- carries the words mid-name (neither anchor) and stays unresolved.
--- Case-sensitive and untrimmed BY DESIGN: the API emits the title-case
--- 'Jump Point' form with no trailing whitespace on every observed record,
--- and normalizing here would loosen the gate beyond observed data. The ONE
--- predicate recordFamily uses to tell a gate from every other Anomaly-typed
--- record, so matches() and resolveSubtype() cannot drift.
--- @param apiData table|nil
--- @return boolean
local function isJumpPointRecord(apiData)
	if type(apiData) ~= 'table' or type(apiData.type) ~= 'table' then
		return false
	end
	-- The unambiguous token: a handful of records (the Stanton-side gates) are
	-- typed 'JumpPoint' outright — no name check needed or wanted there, since
	-- repurposed gates carry STALE names ("Stanton - Magnus Jump Point" is the
	-- in-game Stanton - Nyx gate; its parent object, Nyx Gateway, is the
	-- truth). Name anchors below apply only to the ambiguous 'Anomaly' token.
	if apiData.type.name == 'JumpPoint' then
		return true
	end
	if apiData.type.name ~= 'Anomaly' or type(apiData.name) ~= 'string' then
		return false
	end
	return apiData.name:sub(-#JUMP_POINT_SUFFIX) == JUMP_POINT_SUFFIX
		or apiData.name:sub(1, #JUMP_POINT_SUFFIX + 1) == JUMP_POINT_SUFFIX .. ' '
end

--- Family token of a typed location record: 'jumppoint' for a gate,
--- 'starsystem' for a SolarSystem record, false for a typed record no leaf
--- models (planets, wreck sites), nil when the record carries no type table
--- at all (no record, or the editorial fork's empty apiData).
--- @param apiData table|nil
--- @return string|false|nil
local function recordFamily(apiData)
	if type(apiData) ~= 'table' or type(apiData.type) ~= 'table' then
		return nil
	end
	if isJumpPointRecord(apiData) then
		return 'jumppoint'
	end
	if apiData.type.name == 'SolarSystem' then
		return 'starsystem'
	end
	return false
end

--- Positive identification: a location signature (`respawn_location_type`, a
--- field no item, vehicle, commodity, mission, or blueprint record carries)
--- AND a record one of this kind's leaves renders. Nil-safe, strict boolean,
--- order-independent — the declared-kind gate offers a record of any kind to
--- matches(), and a kind claims a record exactly when it can render it.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.respawn_location_type ~= nil and type(recordFamily(apiData)) == 'string'
end

--- Refine to the family leaf. A typed record decides alone: its family token
--- (see recordFamily), or nil for a record no leaf models — a declared kind
--- or a |family= arg never rescues a wreck site. With no typed record (the
--- editorial fork), the curated |family= names the leaf when it is one this
--- kind maps (the starmap-only tunnels declare `jumppoint`); otherwise a
--- kind-declared page takes the StarSystem default, and an undeclared page
--- resolves nothing.
--- @param apiData table|nil
--- @param args table|nil
--- @return table|nil leaf module
function p.resolveSubtype(apiData, args)
	local family = recordFamily(apiData)
	if family == nil then
		family = subtypeResolver.familyArg(args)
		if (family == nil or LOCATION_SUBTYPE_MAP[family] == nil) and type(args) == 'table' and args.kind ~= nil then
			family = p.defaultFamily
		end
	end
	return subtypeResolver.resolve(family or nil, LOCATION_SUBTYPE_MAP)
end

--- Editorial fields every location leaf renders in its Lore section:
--- API-absent, pure-editorial. Leaf-specific fields live on the leaves and
--- merge over this fragment (Module:Entity/Assembly.mergeEditorialManifests).
--- @return table
function p.getEditorialManifest()
	return {
		discoveredin = { arg = 'discoveredin', smw = 'Discovered in' },
		discoveredby = { arg = 'discoveredby', smw = 'Discovered by' },
		historicalnames = { arg = 'historicalnames' },
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	isJumpPointRecord = isJumpPointRecord,
	recordFamily = recordFamily,
	LOCATION_SUBTYPE_MAP = LOCATION_SUBTYPE_MAP,
}

return p
