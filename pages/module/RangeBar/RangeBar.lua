require('strict')

--- @module RangeBar
--- A reusable horizontal range bar: highlights an active value band on a fixed
--- gradient axis. The band is drawn vividly; the rest of the axis is shown dimmed
--- and gap-separated, so the bar reads as "this slice of the whole range." An
--- optional reference tick marks a notable value (e.g. 0). Domain-agnostic: the
--- caller supplies the axis extent, the gradient colour stops (in domain units),
--- the band, and a label formatter, so it serves temperature ranges, operating
--- bands, tolerances, or any "sub-range of a known scale" value.
---
--- The gradient is fixed hex (not theme tokens) by design — a chosen palette looks
--- identical in light and dark themes — while the labels use Citizen tokens and
--- stay theme-aware.

local p = {}

local STYLES = 'Module:RangeBar/styles.css'
local DEFAULT_GAP = 1.2
local DEFAULT_TICK_COLOR = 'rgba(0, 0, 0, 0.5)'
-- Label-collision sizing. Band-edge labels sit outside the band so they never
-- overlap each other; these heuristics decide tick-label visibility and edge
-- clamping, sized for the ~300px infobox bar (the module's consumer).
local NOMINAL_BAR_PX = 300
local LABEL_CHAR_PX = 8
local LABEL_GAP_PCT = 0.5

local ulen = mw.ustring.len

--- @class RangeBarStop
--- @field at number Domain value where this colour sits.
--- @field color string CSS hex colour at that value.

--- @class RangeBarData
--- @field min number Active band lower bound (domain units).
--- @field max number Active band upper bound (domain units).
--- @field domain table { min = number, max = number } — the fixed axis extent.
--- @field stops RangeBarStop[] Gradient stops across the domain, ascending by `at` (>= 2).
--- @field tick number|nil Optional reference value drawn as a vertical line.
--- @field tickColor string|nil CSS colour for the tick line. Defaults to a dark translucent line.
--- @field gap number|nil Gap (in % of bar width) separating the band from the dim flanks. Defaults to 1.2.
--- @field format fun(value: number): string|nil Band-edge label formatter. Defaults to tostring.
--- @field formatTick fun(value: number): string|nil Tick label formatter. Defaults to `format`.

--- Position of a value on the axis as a 0-100 percentage, clamped to the bar.
---
--- @param value number
--- @param lo number Axis minimum.
--- @param hi number Axis maximum.
--- @return number percentage in [0, 100]
local function clampPct(value, lo, hi)
	if hi <= lo then
		return 0
	end
	local pct = (value - lo) / (hi - lo) * 100
	if pct < 0 then
		return 0
	end
	if pct > 100 then
		return 100
	end
	return pct
end

local function hexToRgb(h)
	h = h:gsub('#', '')
	return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local function rgbToHex(r, g, b)
	return string.format('#%02x%02x%02x', math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
end

--- Interpolate the gradient colour at a domain value (clamped to the stop range).
--- Assumes `stops` is ascending by `at`.
---
--- @param stops RangeBarStop[]
--- @param value number
--- @return string hex colour
local function colorAt(stops, value)
	if value <= stops[1].at then
		return stops[1].color
	end
	local last = stops[#stops]
	if value >= last.at then
		return last.color
	end
	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]
		if value >= a.at and value <= b.at then
			local f = (value - a.at) / (b.at - a.at)
			local r1, g1, b1 = hexToRgb(a.color)
			local r2, g2, b2 = hexToRgb(b.color)
			return rgbToHex(r1 + f * (r2 - r1), g1 + f * (g2 - g1), b1 + f * (b2 - b1))
		end
	end
	return last.color
end

--- Format a number for CSS output: two decimals, trailing zeros (and a bare dot)
--- stripped, so "34.60" -> "34.6", "50.00" -> "50".
---
--- @param n number
--- @return string
local function fmtNum(n)
	local s = string.format('%.2f', n)
	s = s:gsub('%.?0+$', '')
	return s
end

--- Build a CSS linear-gradient across the sub-range [a, b], including any stop
--- that falls strictly inside it so the gradient tracks the palette accurately.
---
--- @param stops RangeBarStop[]
--- @param a number
--- @param b number
--- @return string CSS linear-gradient
local function gradientFor(stops, a, b)
	local span = b - a
	local parts = { colorAt(stops, a) .. ' 0%' }
	if span > 0 then
		for _, s in ipairs(stops) do
			if s.at > a and s.at < b then
				table.insert(parts, s.color .. ' ' .. fmtNum((s.at - a) / span * 100) .. '%')
			end
		end
	end
	table.insert(parts, colorAt(stops, b) .. ' 100%')
	return 'linear-gradient(90deg, ' .. table.concat(parts, ', ') .. ')'
end

--- Estimated rendered width of a label as a percentage of the bar, used to keep
--- labels from colliding. Tuned for the infobox bar width.
---
--- @param text string
--- @return number
local function labelWidthPct(text)
	return ulen(text) * LABEL_CHAR_PX / NOMINAL_BAR_PX * 100
end

--- Whether two [left, right] percentage boxes overlap (within a small gap).
---
--- @param a number[]
--- @param b number[]
--- @return boolean
local function overlaps(a, b)
	return a[2] + LABEL_GAP_PCT > b[1] and b[2] + LABEL_GAP_PCT > a[1]
end

--- Render a range bar. Returns the TemplateStyles tag plus the HTML, or nil when
--- the inputs are unusable (missing bounds/domain/stops, or an empty domain).
---
--- @param data RangeBarData
--- @return string|nil
function p.render(data)
	data = data or {}
	local min = tonumber(data.min)
	local max = tonumber(data.max)
	local domain = data.domain or {}
	local dMin = tonumber(domain.min)
	local dMax = tonumber(domain.max)
	local stops = data.stops
	if min == nil or max == nil or dMin == nil or dMax == nil or dMax <= dMin then
		return nil
	end
	if type(stops) ~= 'table' or stops[2] == nil then
		return nil
	end
	if min > max then
		min, max = max, min
	end

	local fmt = type(data.format) == 'function' and data.format or tostring
	local fmtTick = type(data.formatTick) == 'function' and data.formatTick or fmt
	local gap = tonumber(data.gap) or DEFAULT_GAP
	local lo = clampPct(min, dMin, dMax)
	local hi = clampPct(max, dMin, dMax)

	local root = mw.html.create('div'):addClass('range-bar')
	local track = root:tag('div'):addClass('range-bar__track')

	if lo - gap > 0 then
		track
			:tag('div')
			:addClass('range-bar__seg range-bar__seg--dim')
			:css('left', '0')
			:css('width', fmtNum(lo - gap) .. '%')
			:css('background', gradientFor(stops, dMin, min))
	end
	track
		:tag('div')
		:addClass('range-bar__seg')
		:css('left', fmtNum(lo) .. '%')
		:css('width', fmtNum(hi - lo) .. '%')
		:css('background', gradientFor(stops, min, max))
	if hi + gap < 100 then
		track
			:tag('div')
			:addClass('range-bar__seg range-bar__seg--dim')
			:css('left', fmtNum(hi + gap) .. '%')
			:css('right', '0')
			:css('background', gradientFor(stops, max, dMax))
	end

	local tick = tonumber(data.tick)
	if tick ~= nil then
		track
			:tag('div')
			:addClass('range-bar__tick')
			:css('left', fmtNum(clampPct(tick, dMin, dMax)) .. '%')
			:css('background', data.tickColor or DEFAULT_TICK_COLOR)
	end

	-- Band-edge labels sit just OUTSIDE the band — min's right edge at the band
	-- start, max's left edge at the band end — so they never overlap each other
	-- however narrow the band; each clamps to the bar edge if it would overflow.
	local labels = root:tag('div'):addClass('range-bar__labels')
	local minText, maxText = fmt(min), fmt(max)
	local wMin, wMax = labelWidthPct(minText), labelWidthPct(maxText)

	local minBox
	if lo - wMin >= 0 then
		labels:tag('span'):css('left', fmtNum(lo) .. '%'):css('transform', 'translateX(-100%)'):wikitext(minText)
		minBox = { lo - wMin, lo }
	else
		labels:tag('span'):css('left', '0'):css('transform', 'none'):wikitext(minText)
		minBox = { 0, wMin }
	end

	local maxBox
	if hi + wMax <= 100 then
		labels:tag('span'):css('left', fmtNum(hi) .. '%'):css('transform', 'none'):wikitext(maxText)
		maxBox = { hi, hi + wMax }
	else
		labels:tag('span'):css('left', '100%'):css('transform', 'translateX(-100%)'):wikitext(maxText)
		maxBox = { 100 - wMax, 100 }
	end

	-- The tick line is always drawn (above); show its label only when it clears
	-- both band-edge labels and isn't sitting exactly on an endpoint.
	if tick ~= nil and tick ~= min and tick ~= max then
		local tp = clampPct(tick, dMin, dMax)
		local tickText = fmtTick(tick)
		local wTick = labelWidthPct(tickText)
		local tickBox = { tp - wTick / 2, tp + wTick / 2 }
		if not overlaps(tickBox, minBox) and not overlaps(tickBox, maxBox) then
			labels:tag('span'):addClass('range-bar__label--tick'):css('left', fmtNum(tp) .. '%'):wikitext(tickText)
		end
	end

	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. tostring(root)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	clampPct = clampPct,
	colorAt = colorAt,
	gradientFor = gradientFor,
	fmtNum = fmtNum,
	labelWidthPct = labelWidthPct,
	overlaps = overlaps,
}

return p
