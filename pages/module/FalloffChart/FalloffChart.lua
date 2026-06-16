require('strict')

--- @module FalloffChart
--- A reusable filled-area chart for a piecewise curve (e.g. weapon damage over
--- distance). Domain-agnostic: the caller supplies the curve vertices, the axis
--- extents, optional vertical markers, a horizontal floor reference, y-axis end
--- values, an optional reach marker, and header / caption text. The translucent
--- fill and its thin top stroke are clip-path polygons stashed in custom properties
--- and consumed bare (TemplateStyles-safe). The plot box holds only the curve, floor,
--- gridlines, and bare tick lines; the y-axis labels sit in a gutter to its left and
--- the distance labels in an x-axis row beneath it (each centred under its tick, edge
--- labels clamped to the edges) so no label overlaps the curve. The header matches
--- MeterBar / RangeBar so charts and bars sit together.

local p = {}

local STYLES = 'Module:FalloffChart/styles.css'
local STROKE_THICKNESS = 3 -- vertical thickness (% of height) of the curve stroke band.
local X_EDGE_CLAMP = 6 -- x-axis labels within this % of the left edge anchor to it instead of centring.
local X_CLOSE_GAP = 16 -- two x-axis labels closer than this % left-align the right one (grows clear).
local X_END_ZONE = 80 -- x-axis labels at/past this % right-align on their tick; the scale-max is dropped.

--- @class FalloffChartPoint
--- @field x number Distance (domain units).
--- @field y number Value (e.g. damage).

--- @class FalloffChartMarker
--- @field at number Domain value where the tick sits.
--- @field label string|nil Tick label (shown in the x-axis row, under the tick line).

--- @class FalloffChartData
--- @field points FalloffChartPoint[] Curve vertices, ascending by x (>= 2).
--- @field domain number Axis max (min is 0).
--- @field yMax number Value-axis max (min is 0).
--- @field label string|nil Header label (top-left).
--- @field value string|nil Header value (top-right).
--- @field markers FalloffChartMarker[]|nil Vertical ticks with labels.
--- @field floor number|nil Horizontal reference line at this value.
--- @field yTicks table[]|nil { {at=number, label=string}, ... } y-axis gridlines + labels.
--- @field reach table|nil { at = number, label = string } — projectile-reach end marker.
--- @field scaleMax string|nil Scale-max label shown at the right end of the x-axis row.
--- @field caption string|nil Sub-caption line.
--- @field dataset table<string, any>|nil data-* attributes (key without the "data-"
---        prefix) emitted on the chart element, for optional client-side enhancement.

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

--- The filled-area polygon under the curve. Closes to the baseline at the LAST
--- point's x (not a hard 100%), so a curve that ends before the right edge (range-
--- or scale-clipped) leaves the remaining width empty instead of a dead triangle.
--- @param points FalloffChartPoint[]
--- @param domain number
--- @param yMax number
--- @return string
local function buildClip(points, domain, yMax)
	local coords = { '0% 100%' }
	for _, pt in ipairs(points) do
		table.insert(coords, fmtNum(clampPct(pt.x, domain)) .. '% ' .. fmtNum(100 - clampPct(pt.y, yMax)) .. '%')
	end
	table.insert(coords, fmtNum(clampPct(points[#points].x, domain)) .. '% 100%')
	return 'polygon(' .. table.concat(coords, ', ') .. ')'
end

--- A thin band hugging the curve (its top edge), drawn in the accent colour to make
--- the falloff shape read over the subtle fill. Top edge L→R, then the same edge
--- offset down by STROKE_THICKNESS, R→L.
--- @param points FalloffChartPoint[]
--- @param domain number
--- @param yMax number
--- @return string
local function buildStroke(points, domain, yMax)
	local top, bottom = {}, {}
	for _, pt in ipairs(points) do
		local x = fmtNum(clampPct(pt.x, domain))
		local y = 100 - clampPct(pt.y, yMax)
		table.insert(top, x .. '% ' .. fmtNum(y) .. '%')
		table.insert(bottom, 1, x .. '% ' .. fmtNum(math.min(100, y + STROKE_THICKNESS)) .. '%')
	end
	for _, c in ipairs(bottom) do
		table.insert(top, c)
	end
	return 'polygon(' .. table.concat(top, ', ') .. ')'
end

--- Adds a bare vertical tick line at domain value `at` inside the plot. The label
--- (if any) lives in the x-axis row, not here, so it can never overlap the curve.
--- @param chart table mw.html chart node
--- @param at number
--- @param domain number
--- @param lineClass string
local function addTickLine(chart, at, domain, lineClass)
	chart:tag('div'):addClass(lineClass):css('--t-falloff-tick-left', fmtNum(clampPct(at, domain)) .. '%')
end

--- Adds a distance label to the x-axis row at position `pos` (0-100%) with an
--- explicit alignment: 'tickright' right-aligns on the tick (grows left), 'tickleft'
--- left-aligns on it (grows right), 'start' anchors the left edge, else it centres.
--- @param xaxis table mw.html x-axis row node
--- @param pos number 0-100 percentage of the plot width.
--- @param labelText string
--- @param align string|nil 'tickright' | 'tickleft' | 'start' | nil (centre)
local function addXLabel(xaxis, pos, labelText, align)
	local lbl = xaxis:tag('span'):addClass('t-falloff__xlabel'):css('--t-falloff-x', fmtNum(pos) .. '%')
	if align == 'tickright' then
		lbl:addClass('t-falloff__xlabel--tickright')
	elseif align == 'tickleft' then
		lbl:addClass('t-falloff__xlabel--tickleft')
	elseif align == 'start' then
		lbl:addClass('t-falloff__xlabel--start')
	end
	lbl:wikitext(labelText)
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

	-- Expose the longest y-label width (in ch). The gutter is that width plus a
	-- --space-xxs gap (the same gap the x-axis row uses), so right-aligned labels
	-- flush their left edge to the container edge (lining up with the header) and sit
	-- the same distance from the axis as the x-axis labels do.
	local maxYLabelLen = 0
	if type(data.yTicks) == 'table' then
		for _, t in ipairs(data.yTicks) do
			if type(t.label) == 'string' then
				maxYLabelLen = math.max(maxYLabelLen, mw.ustring.len(t.label))
			end
		end
	end
	root:css('--t-falloff-label-len', maxYLabelLen .. 'ch')

	-- Plot row: a left y-axis gutter (labels sit outside the plot, so they never
	-- overlap the curve) beside the bordered plot box.
	local plot = root:tag('div'):addClass('t-falloff__plot')
	local yaxis = plot:tag('div'):addClass('t-falloff__yaxis')
	local chart = plot:tag('div'):addClass('t-falloff__chart')

	-- Emit data-* attributes (sorted, for deterministic output) so an optional
	-- client-side gadget can enhance the chart without re-deriving the model.
	if type(data.dataset) == 'table' then
		local keys = {}
		for k in pairs(data.dataset) do
			table.insert(keys, k)
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			chart:attr('data-' .. k, tostring(data.dataset[k]))
		end
	end

	-- Fill at the back; the curve stroke is added last (below) so it paints above
	-- the guideline layer (floor, gridlines, ticks) instead of being crossed by it.
	chart:tag('div'):addClass('t-falloff__area'):css('--t-falloff-clip', buildClip(points, domain, yMax))

	-- Floor reference line (where the curve bottoms out).
	local floor = tonumber(data.floor)
	if floor ~= nil then
		chart
			:tag('div')
			:addClass('t-falloff__floor')
			:css('--t-falloff-floor-top', fmtNum(100 - clampPct(floor, yMax)) .. '%')
	end

	-- y-axis: a shared value scale. Labels live in the left gutter; interior ticks
	-- also draw a gridline across the plot. Top/bottom labels anchor to the gutter
	-- edges; interior labels centre on their gridline — so none clip top or bottom.
	if type(data.yTicks) == 'table' then
		for _, t in ipairs(data.yTicks) do
			local at = tonumber(t.at)
			if at ~= nil and type(t.label) == 'string' then
				local label = yaxis:tag('div'):addClass('t-falloff__ylabel')
				if at >= yMax then
					label:addClass('t-falloff__ylabel--top')
				elseif at <= 0 then
					label:addClass('t-falloff__ylabel--bottom')
				else
					local top = fmtNum(100 - clampPct(at, yMax)) .. '%'
					chart:tag('div'):addClass('t-falloff__gridline'):css('--t-falloff-grid-top', top)
					label:addClass('t-falloff__ylabel--mid'):css('--t-falloff-grid-top', top)
				end
				label:wikitext(t.label)
			end
		end
	end

	-- Bare distance ticks inside the plot (lines only; labels go in the x-axis row).
	if type(data.markers) == 'table' then
		for _, marker in ipairs(data.markers) do
			if tonumber(marker.at) then
				addTickLine(chart, marker.at, domain, 't-falloff__tick')
			end
		end
	end

	-- Reach marker (projectile dies before the scale ends).
	if type(data.reach) == 'table' and tonumber(data.reach.at) then
		addTickLine(chart, data.reach.at, domain, 't-falloff__reach')
	end

	-- Curve stroke, painted last so it sits on top of the guideline layer.
	chart:tag('div'):addClass('t-falloff__line'):css('--t-falloff-clip', buildStroke(points, domain, yMax))

	-- x-axis row beneath the plot. Gather every labelled distance (markers + reach),
	-- sort by position, then place them so none overlap: one in the right end-zone
	-- right-aligns on its tick (and the scale-max, which it sits beside, is dropped);
	-- one closer than X_CLOSE_GAP to its left neighbour left-aligns on its tick; one
	-- at the left edge anchors there; the rest centre. (0 is implicit at the left.)
	local xaxis = root:tag('div'):addClass('t-falloff__xaxis')
	local labelled = {}
	if type(data.markers) == 'table' then
		for _, marker in ipairs(data.markers) do
			if tonumber(marker.at) and type(marker.label) == 'string' then
				table.insert(labelled, { pos = clampPct(marker.at, domain), text = marker.label })
			end
		end
	end
	if type(data.reach) == 'table' and tonumber(data.reach.at) and type(data.reach.label) == 'string' then
		table.insert(labelled, { pos = clampPct(data.reach.at, domain), text = data.reach.label })
	end
	table.sort(labelled, function(a, b)
		return a.pos < b.pos
	end)

	local rightmost = labelled[#labelled] and labelled[#labelled].pos or 0
	local prevPos = nil
	for _, l in ipairs(labelled) do
		local align
		if l.pos >= X_END_ZONE then
			align = 'tickright'
		elseif prevPos ~= nil and l.pos - prevPos < X_CLOSE_GAP then
			align = 'tickleft'
		elseif l.pos <= X_EDGE_CLAMP then
			align = 'start'
		end
		addXLabel(xaxis, l.pos, l.text, align)
		prevPos = l.pos
	end

	-- Scale-max at the right end, unless a label already sits in the end-zone beside it.
	if type(data.scaleMax) == 'string' and data.scaleMax ~= '' and rightmost < X_END_ZONE then
		xaxis:tag('span'):addClass('t-falloff__xlabel'):addClass('t-falloff__xlabel--end'):wikitext(data.scaleMax)
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
	buildStroke = buildStroke,
}

return p
