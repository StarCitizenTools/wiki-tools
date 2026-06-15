require('strict')

--- @module FalloffChart
--- A reusable filled-area chart for a piecewise curve (e.g. weapon damage over
--- distance). Domain-agnostic: the caller supplies the curve vertices, the axis
--- extents, optional vertical markers, a horizontal floor reference, and header /
--- axis / caption text. The filled area is a clip-path polygon stashed in a custom
--- property and consumed bare (TemplateStyles-safe); other positions are custom
--- properties the stylesheet consumes. The header matches MeterBar / RangeBar so
--- charts and bars sit together.

local p = {}

local STYLES = 'Module:FalloffChart/styles.css'

--- @class FalloffChartPoint
--- @field x number Distance (domain units).
--- @field y number Value (e.g. damage).

--- @class FalloffChartMarker
--- @field at number Domain value where the tick sits.
--- @field label string|nil Tick label.

--- @class FalloffChartData
--- @field points FalloffChartPoint[] Curve vertices, ascending by x (>= 2).
--- @field domain number Axis max (min is 0).
--- @field yMax number Value-axis max (min is 0).
--- @field label string|nil Header label (top-left).
--- @field value string|nil Header value (top-right).
--- @field markers FalloffChartMarker[]|nil Vertical ticks.
--- @field floor number|nil Horizontal reference line at this value.
--- @field axisMin string|nil Axis label (bottom-left).
--- @field axisMax string|nil Axis label (bottom-right).
--- @field caption string|nil Sub-caption line.

--- Two-decimal format, trailing zeros (and a bare dot) stripped: 16.70 -> "16.7".
--- @param n number
--- @return string
local function fmtNum(n)
	local s = string.format('%.2f', n)
	s = s:gsub('%.?0+$', '')
	return s
end

--- A value as a 0-100 percentage of [0, max], clamped.
--- @param v number
--- @param max number
--- @return number
local function clampPct(v, max)
	if max <= 0 then
		return 0
	end
	local pct = v / max * 100
	if pct < 0 then
		return 0
	end
	if pct > 100 then
		return 100
	end
	return pct
end

--- Build the clip-path polygon for the filled area under the curve. Points map to
--- chart space (x% across the domain, y% down from the top where y=yMax is the
--- top), then close to the baseline corners.
--- @param points FalloffChartPoint[]
--- @param domain number
--- @param yMax number
--- @return string
local function buildClip(points, domain, yMax)
	local coords = { '0% 100%' }
	for _, pt in ipairs(points) do
		local x = clampPct(pt.x, domain)
		local y = 100 - clampPct(pt.y, yMax)
		table.insert(coords, fmtNum(x) .. '% ' .. fmtNum(y) .. '%')
	end
	table.insert(coords, '100% 100%')
	return 'polygon(' .. table.concat(coords, ', ') .. ')'
end

--- @param data FalloffChartData
--- @return string|nil
function p.render(data)
	data = data or {}
	local points = data.points
	local domain = tonumber(data.domain)
	local yMax = tonumber(data.yMax)
	if type(points) ~= 'table' or points[2] == nil or domain == nil or yMax == nil or domain <= 0 or yMax <= 0 then
		return nil
	end

	local root = mw.html.create('div'):addClass('t-falloff')

	local label = type(data.label) == 'string' and data.label or ''
	local value = type(data.value) == 'string' and data.value or ''
	if label ~= '' or value ~= '' then
		local head = root:tag('div'):addClass('t-falloff__head')
		head:tag('span'):addClass('t-falloff__label'):wikitext(label)
		head:tag('span'):addClass('t-falloff__value'):wikitext(value)
	end

	local chart = root:tag('div'):addClass('t-falloff__chart')
	chart:tag('div'):addClass('t-falloff__area'):css('--t-falloff-clip', buildClip(points, domain, yMax))

	local floor = tonumber(data.floor)
	if floor ~= nil then
		chart
			:tag('div')
			:addClass('t-falloff__floor')
			:css('--t-falloff-floor-top', fmtNum(100 - clampPct(floor, yMax)) .. '%')
	end

	if type(data.markers) == 'table' then
		for _, marker in ipairs(data.markers) do
			local at = tonumber(marker.at)
			if at ~= nil then
				local tick = chart
					:tag('div')
					:addClass('t-falloff__tick')
					:css('--t-falloff-tick-left', fmtNum(clampPct(at, domain)) .. '%')
				if marker.label then
					tick:tag('span'):addClass('t-falloff__tick-label'):wikitext(marker.label)
				end
			end
		end
	end

	local axisMin = type(data.axisMin) == 'string' and data.axisMin or ''
	local axisMax = type(data.axisMax) == 'string' and data.axisMax or ''
	if axisMin ~= '' or axisMax ~= '' then
		local axis = root:tag('div'):addClass('t-falloff__axis')
		axis:tag('span'):wikitext(axisMin)
		axis:tag('span'):wikitext(axisMax)
	end

	if type(data.caption) == 'string' and data.caption ~= '' then
		root:tag('div'):addClass('t-falloff__caption'):wikitext(data.caption)
	end

	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. tostring(root)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	fmtNum = fmtNum,
	clampPct = clampPct,
	buildClip = buildClip,
}

return p
