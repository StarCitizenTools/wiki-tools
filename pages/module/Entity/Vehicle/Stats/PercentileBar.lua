require('strict')

--- @module Entity/Vehicle/Stats/PercentileBar
--- A detail-tab row showing a stat's value and where the ship places among its
--- size class: a bar filled to the class-percentile (visual standing) labelled
--- with the ship's rank (1st = best, medals for the podium). Degrades to a plain
--- labelled row when there is no cohort / the stat is missing.

local rangeBar = require('Module:RangeBar')
local standing = require('Module:Entity/Vehicle/Stats/Standing')

local p = {}

--- @param opts { label: string, valueText: string|nil, percentile: number|nil, rank: number|nil }
--- @return table|nil
function p.item(opts)
	if opts.valueText == nil then
		return nil
	end
	local pct = tonumber(opts.percentile)
	if pct == nil then
		return { label = opts.label, content = opts.valueText }
	end
	-- A podium medal (top 3 only) sits to the LEFT of the value, so the value stays
	-- flush-right across rows for scanning; the title carries the ordinal on hover. No
	-- separator character — the medal owns its spacing via a CSS margin (see
	-- standing.medal) so copying the value never picks up a stray space or the emoji.
	local value = opts.valueText
	local medal = opts.rank ~= nil and standing.medal(opts.rank) or nil
	if medal ~= nil then
		value = medal .. value
	end
	local bar = rangeBar.render({
		label = opts.label,
		value = value,
		min = 0,
		max = pct,
		domain = { min = 0, max = 100 },
		stops = standing.stops,
		tick = 50,
	})
	return { content = bar, class = 't-infobox-item--block' }
end

return p
