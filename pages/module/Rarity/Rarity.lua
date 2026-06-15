require('strict')

--- @module Rarity
--- Renders an item rarity tier as a coloured badge. Reusable from modules
--- (`p.badge`) and from wikitext / `{{Rarity}}` (`p.main`). The rarity palette is
--- defined in Module:Rarity/styles.css (hardcoded, theme-aware, tinted to match
--- the success / warning badge contrast); this module only maps a rarity string
--- to its tier label + class and delegates rendering to Module:BadgeLua.

local badge = require('Module:BadgeLua')

local p = {}

local STYLES = 'Module:Rarity/styles.css'

--- @type table<string, { label: string, class: string }>
local TIERS = {
	common = { label = 'Common', class = 'rarity-badge--common' },
	uncommon = { label = 'Uncommon', class = 'rarity-badge--uncommon' },
	rare = { label = 'Rare', class = 'rarity-badge--rare' },
	epic = { label = 'Epic', class = 'rarity-badge--epic' },
	legendary = { label = 'Legendary', class = 'rarity-badge--legendary' },
}

--- Resolve a rarity string (any case, trimmed) to its tier descriptor, or nil
--- for an empty / unknown value.
---
--- @param rarity string|nil
--- @return { label: string, class: string }|nil
local function resolve(rarity)
	if type(rarity) ~= 'string' then
		return nil
	end
	return TIERS[mw.ustring.lower(mw.text.trim(rarity))]
end

--- Render the rarity badge. Returns nil for an empty / unknown rarity so callers
--- can omit it entirely.
---
--- @param rarity string|nil
--- @return string|nil
function p.badge(rarity)
	local tier = resolve(rarity)
	if not tier then
		return nil
	end
	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. badge.render({ text = tier.label, class = 'rarity-badge ' .. tier.class })
end

--- Wikitext entry point: `{{#invoke:Rarity|main|<rarity>}}` or `|rarity=`.
--- Returns empty string for an unknown rarity so it vanishes inline.
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)
	return p.badge(args.rarity or args[1]) or ''
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolve = resolve,
}

return p
