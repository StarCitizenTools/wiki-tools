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

--- @type table<string, { label: string, class: string }>
local TIERS = {
	flightready = { label = 'Flight ready', class = 'production-status-badge--flight-ready' },
	inproduction = { label = 'In production', class = 'production-status-badge--in-production' },
	inconcept = { label = 'In concept', class = 'production-status-badge--in-concept' },
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
--- @return { label: string, class: string }|nil
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

-- Test-only exports. Not part of the public API.
p._internal = {
	resolve = resolve,
	TIERS = TIERS,
}

return p
