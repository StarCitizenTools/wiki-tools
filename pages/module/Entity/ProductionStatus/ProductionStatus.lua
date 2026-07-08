require('strict')

--- @module Entity/ProductionStatus
--- Resolves a vehicle's production status to a colored badge. Mirrors
--- Module:Rarity. Used only by Module:Entity/Vehicle (the header badge) — other
--- entities are in the API because they are already in-game, so a status badge
--- there would be noise. Status is normalized (lowercase, non-alphanumerics
--- stripped) so the API value "flight-ready" and editorial "Flight ready" both
--- resolve to the same tier.

local badge = require('Module:BadgeLua')

local STYLES = 'Module:Entity/ProductionStatus/styles.css'

--- Legacy / alternate status strings (already normalized) that map onto a
--- canonical tier key. "In lore" was the old label for the Lore-only tier.
--- @type table<string, string>
local ALIASES = {
	inlore = 'loreonly',
}

--- @type table<string, { label: string, class: string }>
local TIERS = {
	flightready = {
		label = 'Flight ready',
		class = 'production-status-badge--ready',
	},
	inproduction = {
		label = 'In production',
		class = 'production-status-badge--production',
	},
	activeproduction = {
		label = 'Active production',
		class = 'production-status-badge--production',
	},
	activeforsquadron42 = {
		label = 'Active for Squadron 42',
		class = 'production-status-badge--production',
	},
	longtermproduction = {
		label = 'Long term production',
		class = 'production-status-badge--production',
	},
	inconcept = {
		label = 'In concept',
		class = 'production-status-badge--concept',
	},
	loreonly = {
		label = 'Lore-only',
		class = 'production-status-badge--concept',
	},
	unconfirmed = {
		label = 'Unconfirmed',
		class = 'production-status-badge--unconfirmed',
	},
}

local p = {}

--- Canonical tier key for a status string: lowercase, non-alphanumerics stripped,
--- then aliases applied — e.g. "flight-ready" / "Flight ready" → "flightready",
--- and both "In lore" and "Lore-only" → "loreonly". Lets callers branch on
--- production state (e.g. suppress loaners for flight-ready ships, drop pledge
--- availability for lore-only ships) without re-implementing the normalization.
--- nil for an empty / non-string value.
---
--- @param status string|nil
--- @return string|nil
function p.key(status)
	if type(status) ~= 'string' or status == '' then
		return nil
	end
	local key = (status:lower():gsub('[^%a%d]', ''))
	return ALIASES[key] or key
end

--- Resolve a production status string (any case, non-alphanumerics stripped) to
--- its tier descriptor, or nil for an empty / unknown value.
---
--- @param status string|nil
--- @return { label: string, class: string, desc: string }|nil
local function resolve(status)
	local key = p.key(status)
	return key and TIERS[key] or nil
end

--- Render the production status badge. Returns nil for an empty / unknown status
--- so callers can omit it entirely.
---
--- @param status string|nil
--- @return string|nil
function p.badge(status)
	local tier = resolve(status)
	if not tier then
		return nil
	end
	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. badge.render({ text = tier.label, class = 'production-status-badge ' .. tier.class })
end

--- The display label for a production status (for a category), or nil for unknown.
--- @param status string|nil
--- @return string|nil
function p.label(status)
	local tier = resolve(status)
	return tier and tier.label or nil
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolve = resolve,
	TIERS = TIERS,
}

return p
