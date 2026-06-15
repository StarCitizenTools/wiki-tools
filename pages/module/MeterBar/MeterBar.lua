require('strict')

--- @module MeterBar
--- A single labeled horizontal meter bar: a label/value header above a fill track
--- scaled against a max. The single-bar, fill sibling of Module:RangeBar (which
--- highlights a band on a gradient axis); both share the same header style, so
--- compose several as separate infobox items and let the item list own the spacing.
---
--- Domain-agnostic: the caller passes the label, value, max, display text, and
--- (optionally) the fill colour. The fill colour defaults to a single accent; the
--- value text is always --color-base. The fill width and colour are passed as CSS
--- custom properties the stylesheet consumes, so all visuals stay in the sheet and
--- the output is theme-aware.

local p = {}

local DEFAULT_MAX = 100
local DEFAULT_COLOR = 'var(--color-progressive)'
local STYLES = 'Module:MeterBar/styles.css'

--- @class MeterBarData
--- @field label string|nil Header label, shown top-left.
--- @field value number The numeric value (drives the fill and, by default, the displayed text).
--- @field max number|nil Fill denominator. Defaults to 100.
--- @field text string|nil Header value text, shown top-right (e.g. "52,800 REM"). Defaults to the value.
--- @field color string|nil CSS colour for the fill (a token string). Defaults to a neutral accent.
--- @field title string|nil Full name surfaced as a hover tooltip on the bar. Optional.

--- Clamp a value/max ratio to a 0-100 fill percentage. A non-positive max yields 0.
---
--- @param value number
--- @param max number
--- @return number percentage in [0, 100]
local function clampPct(value, max)
	if max <= 0 then
		return 0
	end
	local pct = value / max * 100
	if pct < 0 then
		return 0
	end
	if pct > 100 then
		return 100
	end
	return pct
end

--- Render one labeled meter bar. Returns the TemplateStyles tag plus the HTML,
--- ready to drop into any wikitext or infobox section content.
---
--- @param data MeterBarData
--- @return string
function p.render(data)
	data = data or {}
	local value = tonumber(data.value) or 0
	local max = tonumber(data.max) or DEFAULT_MAX
	local pct = clampPct(value, max)

	local root = mw.html.create('div'):addClass('t-meter-bar')
	local head = root:tag('div'):addClass('t-meter-bar__head')
	head:tag('span'):addClass('t-meter-bar__label'):wikitext(data.label or '')
	head:tag('span'):addClass('t-meter-bar__value'):wikitext(data.text or tostring(value))
	local track = root:tag('div'):addClass('t-meter-bar__track')
	if data.title then
		track:attr('title', data.title)
	end
	track
		:tag('div')
		:addClass('t-meter-bar__fill')
		:css('--t-meter-bar-fill-width', pct .. '%')
		:css('--t-meter-bar-fill-color', data.color or DEFAULT_COLOR)

	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. tostring(root)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	clampPct = clampPct,
}

return p
