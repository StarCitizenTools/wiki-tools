require('strict')

--- @module Entity/Vehicle
--- Vehicle type module. Barebones for now — exposes the vehicles API
--- endpoint so sibling renderers (Availability, Description, etc.) can
--- consume vehicle data through the standard Module:Entity/Data path.
--- Full vehicle infobox treatment (sections, structured data) lands
--- later; this is the minimum needed to route vehicle UUIDs.

local base = require('Module:Entity/Base')

local p = {}

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on. Every kind declares one (enforced by the Registry conformance test).
p.name = 'Vehicle'

--- @type string
p.parent = 'Entity/Base'

--- The vehicles endpoint includes uex_prices and msrp by default, so
--- no `include` param is required for Availability to render.
---
--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'vehicles/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- Positive identification: vehicles always carry the `is_vehicle`
--- key at the top level alongside `is_spaceship` and `is_gravlev`.
--- The value is the family flag (`is_vehicle=true` for ground vehicles,
--- `is_spaceship=true` for spaceships, `is_gravlev=true` for hover
--- bikes — a Cutlass Black has `is_vehicle=false, is_spaceship=true`),
--- so we check **presence** rather than value. Items don't have any
--- of these keys.
--- Safe on nil / empty / malformed apiData (returns false, never throws).
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.is_vehicle ~= nil
end

--- Refine a vehicle to its family subtype leaf. Every vehicle record carries all
--- three family flags; exactly one is truthy. Gravlev is checked first because a
--- hover bike may also set is_vehicle. Returns nil when no family flag is set
--- (the Vehicle kind itself stays the leaf).
--- @param apiData table|nil
--- @return table|nil
function p.resolveSubtype(apiData)
	if type(apiData) ~= 'table' then
		return nil
	end
	if apiData.is_gravlev then
		return require('Module:Entity/Vehicle/Gravlev')
	end
	if apiData.is_spaceship then
		return require('Module:Entity/Vehicle/Ship')
	end
	if apiData.is_vehicle then
		return require('Module:Entity/Vehicle/GroundVehicle')
	end
	return nil
end

--- Compose a vehicle short description: "<role> <familyNoun> by <manufacturer>".
--- role from apiData.role (a multi-role array joins on '/'); manufacturer from
--- the shared resolver (editorial-overridable via args.manufacturer). Pure.
--- @param apiData table
--- @param args table
--- @param familyNoun string  e.g. 'spaceship', 'ground vehicle', 'gravlev'
--- @return string
function p.formatShortDescription(apiData, args, familyNoun)
	local role = apiData.role
	-- The live vehicles API returns role as a plain string; this branch is
	-- defensive for legacy/multi-role vehicles that expose role as an array
	-- (historically '/'-joined).
	if type(role) == 'table' then
		role = table.concat(role, '/')
	end
	local parts = {}
	if role and role ~= '' then
		parts[#parts + 1] = role
	end
	parts[#parts + 1] = familyNoun
	local desc = table.concat(parts, ' ')
	local mfr = base.resolveManufacturer(apiData, args)
	if mfr and mfr.short then
		desc = desc .. ' by ' .. mfr.short
	end
	return mw.text.trim(desc)
end

return p
