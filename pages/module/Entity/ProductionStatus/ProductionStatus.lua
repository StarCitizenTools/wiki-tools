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

--- @type table<string, { label: string, class: string, desc: string }>
local TIERS = {
	flightready = {
		label = 'Flight ready',
		class = 'production-status-badge--ready',
		desc = 'The vehicle can fly/drive with full operations including physics, interactions, systems, fuel, cargo, and more.',
	},
	inproduction = {
		label = 'In production',
		class = 'production-status-badge--production',
		desc = 'The vehicle is in active development.',
	},
	activeproduction = {
		label = 'Active production',
		class = 'production-status-badge--production',
		desc = 'Development, designers, and QA work from start to finish on the vehicle.',
	},
	activeforsquadron42 = {
		label = 'Active for Squadron 42',
		class = 'production-status-badge--production',
		desc = 'The vehicle is mentioned to be in development for Squadron 42, but is not available in the Persistent Universe.',
	},
	longtermproduction = {
		label = 'Long term production',
		class = 'production-status-badge--production',
		desc = 'Development work is planned and added to the Roadmap.',
	},
	inconcept = {
		label = 'In concept',
		class = 'production-status-badge--concept',
		desc = 'Artists and designers determine the concept look, 3D renders, and functional design for a vehicle.',
	},
	inlore = {
		label = 'In lore',
		class = 'production-status-badge--concept',
		desc = 'The vehicle is mentioned in lore only.',
	},
}

local p = {}

--- Normalized tier key for a status string (lowercase, non-alphanumerics
--- stripped) — e.g. "flight-ready" / "Flight ready" → "flightready". Lets callers
--- branch on production state (e.g. suppress loaners for flight-ready ships)
--- without re-implementing the normalization. nil for an empty / non-string value.
---
--- @param status string|nil
--- @return string|nil
function p.key(status)
	if type(status) ~= 'string' or status == '' then
		return nil
	end
	return (status:lower():gsub('[^%a%d]', ''))
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

--- The description for a production status (for a tooltip), or nil for unknown.
--- @param status string|nil
--- @return string|nil
function p.tooltip(status)
	local tier = resolve(status)
	return tier and tier.desc or nil
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolve = resolve,
	TIERS = TIERS,
}

return p
