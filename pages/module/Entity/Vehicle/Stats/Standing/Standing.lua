require('strict')

--- @module Entity/Vehicle/Stats/Standing
--- Shared visual language for how a ship stands within its size-class cohort:
--- its integer rank (1 = best), a podium medal (top 3) for that rank, and the
--- percentile colour scale (a muted olive at the low end fading to vibrant green
--- at the top — never red, a low standing is not "bad"). Used by the detail-tab
--- PercentileBars and the Overview rings (the colour) so they speak one scale.

local p = {}

--- Medals for the podium (rank 1-3); ranks beyond fall back to a plain ordinal.
local MEDALS = { '\240\159\165\135', '\240\159\165\136', '\240\159\165\137' } -- 🥇 🥈 🥉

--- Percentile colour scale endpoints (RGB): olive (low) -> green (high).
local LOW = { 0x6a, 0x7a, 0x52 }
local HIGH = { 0x3a, 0xa6, 0x76 }

--- @param rgb number[]
--- @return string  #rrggbb
local function hex(rgb)
	return string.format('#%02x%02x%02x', rgb[1], rgb[2], rgb[3])
end

--- Ordinal suffix for a positive integer (1->st, 2->nd, 3->rd, else th; 11-13->th).
--- @param n number
--- @return string
local function ordinalSuffix(n)
	local mod100 = n % 100
	if mod100 >= 11 and mod100 <= 13 then
		return 'th'
	end
	local mod10 = n % 10
	if mod10 == 1 then
		return 'st'
	elseif mod10 == 2 then
		return 'nd'
	elseif mod10 == 3 then
		return 'rd'
	end
	return 'th'
end

--- Rank position of `value` within `values`: 1 = best. position = (count strictly
--- better) + 1, so ties share a rank. `invert` ranks lower-as-better (e.g.
--- emissions, cross-section). nil for an empty list.
--- @param values number[]
--- @param value number
--- @param invert boolean|nil
--- @return number|nil
function p.position(values, value, invert)
	local n = #values
	if n == 0 then
		return nil
	end
	local better = 0
	for _, v in ipairs(values) do
		if invert then
			if v < value then
				better = better + 1
			end
		elseif v > value then
			better = better + 1
		end
	end
	return better + 1
end

--- Podium medal for a top-3 rank: just the emoji, with the full ordinal in a
--- `title` so it doubles as a hover tooltip (🥇 titled "1st of the size class").
--- nil beyond 3rd — later ranks in a small size class are noise, not signal.
--- @param position number
--- @return string|nil  HTML span for ranks 1-3, nil otherwise
function p.medal(position)
	local emoji = MEDALS[position]
	if emoji == nil then
		return nil
	end
	local ordinal = position .. ordinalSuffix(position)
	return tostring(mw.html.create('span'):attr('title', ordinal .. ' of the size class'):wikitext(emoji))
end

--- Interpolated colour for a 0-100 score along the percentile scale (olive ->
--- green). The Overview ring fill uses this so it matches the detail-tab bars.
--- @param score number
--- @return string  #rrggbb
function p.color(score)
	local t = math.max(0, math.min(100, tonumber(score) or 0)) / 100
	local function channel(i)
		return math.floor(LOW[i] + (HIGH[i] - LOW[i]) * t + 0.5)
	end
	return string.format('#%02x%02x%02x', channel(1), channel(2), channel(3))
end

--- RangeBar gradient stops for the same scale (the detail-tab bar fill).
p.stops = { { at = 0, color = hex(LOW) }, { at = 100, color = hex(HIGH) } }

return p
