require('strict')

--- @module RangeBar
--- A reusable horizontal range bar: a label/value header above a fixed gradient
--- axis with the active value band highlighted. The band is drawn vividly; the
--- rest of the axis is shown dimmed and gap-separated, so the bar reads as "this
--- slice of the whole range." An optional reference tick marks a notable value
--- (e.g. 0) as a bare line. The header (label + value) matches Module:ProgressBars
--- so range bars and meter bars sit together consistently.
---
--- Domain-agnostic: the caller supplies the header text, the axis extent, the
--- gradient colour stops (in domain units), and the band. The gradient is fixed hex
--- (not theme tokens) by design — a chosen palette looks identical in light and dark
--- themes. Dynamic values (segment position/gradient, tick) are passed as CSS custom
--- properties the stylesheet consumes; the header text uses theme-aware tokens.

local p = {}

local STYLES = 'Module:RangeBar/styles.css'
local DEFAULT_GAP = 1.2
local DEFAULT_TICK_COLOR = 'rgba(0, 0, 0, 0.5)'

--- @class RangeBarStop
--- @field at number Domain value where this colour sits.
--- @field color string CSS hex colour at that value.

--- @class RangeBarData
--- @field label string|nil Header label, shown top-left (e.g. "Temperature").
--- @field value string|nil Header value, shown top-right (e.g. the formatted range).
--- @field min number Active band lower bound (domain units).
--- @field max number Active band upper bound (domain units).
--- @field domain table { min = number, max = number } — the fixed axis extent.
--- @field stops RangeBarStop[] Gradient stops across the domain, ascending by `at` (>= 2).
--- @field tick number|nil Optional reference value drawn as a vertical line (no label).
--- @field tickColor string|nil CSS colour for the tick line. Defaults to a dark translucent line.
--- @field gap number|nil Gap (in % of bar width) separating the band from the dim flanks. Defaults to 1.2.

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

	local gap = tonumber(data.gap) or DEFAULT_GAP
	local lo = clampPct(min, dMin, dMax)
	local hi = clampPct(max, dMin, dMax)

	local root = mw.html.create('div'):addClass('t-range-bar')

	-- Header (label + value), matching the meter-bar style. Shown when either is set.
	local label = type(data.label) == 'string' and data.label or ''
	local value = type(data.value) == 'string' and data.value or ''
	if label ~= '' or value ~= '' then
		local head = root:tag('div'):addClass('t-range-bar__head')
		head:tag('span'):addClass('t-range-bar__label'):wikitext(label)
		head:tag('span'):addClass('t-range-bar__value'):wikitext(value)
	end

	local track = root:tag('div'):addClass('t-range-bar__track')

	-- A segment is positioned and coloured purely through custom properties; the
	-- right flank uses a computed width too, so every segment shares one rule.
	local function seg(left, width, bg, dim)
		track
			:tag('div')
			:addClass('t-range-bar__seg' .. (dim and ' t-range-bar__seg--dim' or ''))
			:css('--t-range-bar-seg-left', fmtNum(left) .. '%')
			:css('--t-range-bar-seg-width', fmtNum(width) .. '%')
			:css('--t-range-bar-seg-bg', bg)
	end

	if lo - gap > 0 then
		seg(0, lo - gap, gradientFor(stops, dMin, min), true)
	end
	seg(lo, hi - lo, gradientFor(stops, min, max), false)
	if hi + gap < 100 then
		seg(hi + gap, 100 - (hi + gap), gradientFor(stops, max, dMax), true)
	end

	-- Reference tick: a bare line (no label); the band position + header carry the
	-- numbers.
	local tick = tonumber(data.tick)
	if tick ~= nil then
		track
			:tag('div')
			:addClass('t-range-bar__tick')
			:css('--t-range-bar-tick-left', fmtNum(clampPct(tick, dMin, dMax)) .. '%')
			:css('--t-range-bar-tick-color', data.tickColor or DEFAULT_TICK_COLOR)
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
}

return p
