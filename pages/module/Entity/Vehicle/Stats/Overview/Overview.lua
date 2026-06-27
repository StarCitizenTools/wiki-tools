require('strict')

--- @module Entity/Vehicle/Stats/Overview
--- The Stats "Overview" tab: a row of ProgressTiles ring-gauges, one per scored
--- axis (Offense / Defense / Mobility / Travel / Stealth), each the ship's
--- class-percentile, with a footer naming the cohort. A raw { label, items }
--- subsection (NO key). The per-driver breakdown lives in the same-named detail
--- tabs, so the rings carry no tooltip. Renders nil when there is no cohort
--- (pre-swap) or no axis has data.

local badge = require('Module:BadgeLua')
local profile = require('Module:Entity/Vehicle/Stats/Profile')
local progressTiles = require('Module:ProgressTiles')
local standing = require('Module:Entity/Vehicle/Stats/Standing')

local p = {}

local function family(apiData)
	if apiData.is_spaceship then
		return 'ship'
	end
	if apiData.is_gravlev then
		return 'gravlev'
	end
	return 'ground'
end

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view (unused; kept for the Stats.build call site)
--- @return table|nil  { label = 'Overview', items = {...} } or nil
function p.build(apiData, args, ed)
	local axes = profile.axisScores(apiData, family(apiData), tonumber(apiData.size_class))
	if axes[1] == nil then
		return nil
	end
	local tiles = {}
	for _, axis in ipairs(axes) do
		tiles[#tiles + 1] = {
			value = axis.score,
			label = axis.label,
			color = standing.color(axis.score),
		}
	end
	-- Footer beneath the rings: a Beta badge (left) and the cohort caption (right),
	-- "vs. N S<class> ships" — naming the size class the cohort is grouped by, which
	-- matches the infobox Size row's "S<class>". size_class is guaranteed present
	-- here: a nil size yields no cohort, so axes[1] would be nil above.
	local sizeClass = math.floor(tonumber(apiData.size_class) + 0.5)
	local footer = '<div class="t-stats-overview-footnote">'
		.. badge.render({ text = 'Beta' })
		.. '<span class="t-stats-overview-footnote__cohort">vs. '
		.. axes[1].cohortSize
		.. ' S'
		.. sizeClass
		.. ' ships</span>'
		.. '</div>'
	return {
		label = 'Overview',
		items = {
			{
				content = '<div class="t-stats-overview-profile">'
					.. progressTiles.render({ tiles = tiles })
					.. footer
					.. '</div>',
				class = 't-infobox-item--block',
			},
		},
	}
end

return p
