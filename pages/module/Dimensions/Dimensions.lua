require('strict')

--- Module:Dimensions
--- Renders an isometric CSS-3D diagram of an object's bounding box at honest
--- scale: measurement lines with end ticks on every axis, an optional reference
--- object on the same ground plane, and a footer bar carrying caller-supplied
--- metrics and the reference legend.
---
--- Domain-agnostic: the module knows nothing about what it is measuring. The
--- caller supplies the reference cuboid and any footer metrics; there are no
--- built-in reference objects and no unit assumptions beyond metres for the
--- geometry labels. Reusable outside any particular wiki. Common scale
--- references live in the companion Module:Dimensions/presets.
---
--- Machine-readable contract: the root element exposes raw SI values via
--- data-length / data-width / data-height (+ data-*-alt when an alternate
--- value renders).
---
--- Public interface:
--- {
---   length, width, height,           -- required, metres
---   lengthAlt, widthAlt, heightAlt,  -- optional, metres
---   reference = {                    -- optional, a single resolved reference
---     length, width, height,         -- metres
---     label,                         -- legend text, e.g. 'Human · 1.8 m'
---     color, colorLight, colorDark,  -- optional colour trio; CSS default else
---   },
---   metrics = {                      -- optional, ordered footer metrics
---     { label = string, value = string },  -- value is a pre-formatted display string
---   },
--- } in, HTML string (or nil on invalid required args) out.

local p = {}

local lang = mw.getContentLanguage()

--- Format a number with thousands separators and a unit.
---
--- @param num number
--- @param unit string
--- @return string
local function formatPlain(num, unit)
	return string.format('%s %s', lang:formatNum(num), unit)
end

--- Format a value with an optional subtle alternate (e.g. retracted length).
---
--- @param num number
--- @param unit string
--- @param altNum number|nil
--- @return string
local function formatValue(num, unit, altNum)
	local value = formatPlain(num, unit)
	if not altNum then
		return value
	end
	return string.format('%s <span class="t-dimensions-value-subtle">(%s)</span>', value, formatPlain(altNum, unit))
end

--- True when t is a {length, width, height} table whose three values are all
--- positive numbers (a drawable cuboid). Nil-safe.
---
--- @param t table|nil
--- @return boolean
local function isBox(t)
	if type(t) ~= 'table' then
		return false
	end
	local l, w, h = tonumber(t.length), tonumber(t.width), tonumber(t.height)
	return l ~= nil and w ~= nil and h ~= nil and l > 0 and w > 0 and h > 0
end

--- Parse and validate raw arguments.
---
--- @param args table
--- @return table|nil data nil when a required dimension is missing, non-numeric or not positive
local function parseArgs(args)
	local length = tonumber(args.length)
	local width = tonumber(args.width)
	local height = tonumber(args.height)

	if not length or not width or not height or length <= 0 or width <= 0 or height <= 0 then
		return nil
	end

	local data = {
		length = length,
		width = width,
		height = height,
		lengthAlt = tonumber(args.lengthAlt),
		widthAlt = tonumber(args.widthAlt),
		heightAlt = tonumber(args.heightAlt),
		-- Pass-through, Lua-caller only (no wikitext path): a single resolved
		-- reference cuboid and an ordered list of footer metrics.
		reference = isBox(args.reference) and args.reference or nil,
		metrics = type(args.metrics) == 'table' and args.metrics or nil,
	}

	-- An alternate equal to the main value carries no information
	if data.lengthAlt == data.length then
		data.lengthAlt = nil
	end
	if data.widthAlt == data.width then
		data.widthAlt = nil
	end
	if data.heightAlt == data.height then
		data.heightAlt = nil
	end

	return data
end

--- Append the three visible faces of a cuboid to a layer.
---
--- @param layer mw.html
local function buildFaces(layer)
	local faces = layer
		:tag('div')
		:addClass('t-dimensions-faces')
		-- TemplateStyles rejects transform-style; must be inline
		:css('transform-style', 'preserve-3d')

	for _, side in ipairs({ 'top', 'front', 'right' }) do
		faces:tag('div'):addClass('t-dimensions-face'):addClass('t-dimensions-face--' .. side):done()
	end
end

--- Build a generic isometric cuboid: two stacked layers, faces on the top
--- layer spanning down. Used for the object AND the reference box (the
--- reference re-scopes the size variables in CSS).
---
--- @param modifier string|nil BEM modifier, e.g. 'reference'
--- @return mw.html root
--- @return mw.html layerTop
--- @return mw.html layerBottom
local function buildBox(modifier)
	local root = mw.html.create('div'):addClass('t-dimensions-box'):css('transform-style', 'preserve-3d')

	if modifier then
		root:addClass('t-dimensions-box--' .. modifier)
	end

	local layerTop = root:tag('div')
		:addClass('t-dimensions-layer')
		:addClass('t-dimensions-layer--top')
		:css('transform-style', 'preserve-3d')
	buildFaces(layerTop)

	local layerBottom = root:tag('div')
		:addClass('t-dimensions-layer')
		:addClass('t-dimensions-layer--bottom')
		:css('transform-style', 'preserve-3d')

	return root, layerTop, layerBottom
end

--- Build a measurement line (1px rule with end ticks; geometry in CSS).
---
--- @param axis string 'length'|'width'|'height'
--- @return mw.html
local function buildLine(axis)
	return mw.html.create('div'):addClass('t-dimensions-line'):addClass('t-dimensions-line--' .. axis)
end

--- Build a stacked label-over-value text block.
---
--- @param axis string 'length'|'width'|'height'
--- @param label string
--- @param valueHtml string output of formatValue
--- @return mw.html
local function buildText(axis, label, valueHtml)
	local text = mw.html.create('div'):addClass('t-dimensions-text'):addClass('t-dimensions-text--' .. axis)

	text:tag('div'):addClass('t-dimensions-text-label'):wikitext(label):done()
	text:tag('div'):addClass('t-dimensions-text-value'):wikitext(valueHtml):done()

	return text
end

--- Assemble the full component.
---
--- @param data table validated output of parseArgs
--- @return mw.html
local function getHtml(data)
	local container = mw.html
		.create('div')
		:addClass('t-dimensions')
		:css({
			['--t-dimensions-object-length'] = tostring(data.length),
			['--t-dimensions-object-width'] = tostring(data.width),
			['--t-dimensions-object-height'] = tostring(data.height),
		})
		:attr('data-length', tostring(data.length))
		:attr('data-width', tostring(data.width))
		:attr('data-height', tostring(data.height))

	if data.lengthAlt then
		container:attr('data-length-alt', tostring(data.lengthAlt))
	end
	if data.widthAlt then
		container:attr('data-width-alt', tostring(data.widthAlt))
	end
	if data.heightAlt then
		container:attr('data-height-alt', tostring(data.heightAlt))
	end
	if data.reference then
		container:addClass('t-dimensions--has-reference'):css({
			['--t-dimensions-reference-length'] = tostring(data.reference.length),
			['--t-dimensions-reference-width'] = tostring(data.reference.width),
			['--t-dimensions-reference-height'] = tostring(data.reference.height),
		})
		-- Optional per-reference colour trio, applied inline so the stylesheet
		-- stays free of any specific reference. Each falls back to the CSS
		-- default when the caller omits it.
		if data.reference.color then
			container:css('--t-dimensions-ref-color', data.reference.color)
		end
		if data.reference.colorLight then
			container:css('--t-dimensions-ref-color-light', data.reference.colorLight)
		end
		if data.reference.colorDark then
			container:css('--t-dimensions-ref-color-dark', data.reference.colorDark)
		end
	end

	-- Screen-reader summary; the visual scene is aria-hidden
	local function summaryPart(label, num, altNum)
		local part = string.format('%s %s', label, formatPlain(num, 'm'))
		if altNum then
			part = string.format('%s (%s)', part, formatPlain(altNum, 'm'))
		end
		return part
	end

	local summaryParts = {
		summaryPart('length', data.length, data.lengthAlt),
		summaryPart('width', data.width, data.widthAlt),
		summaryPart('height', data.height, data.heightAlt),
	}
	for _, metric in ipairs(data.metrics or {}) do
		table.insert(summaryParts, string.format('%s %s', lang:lc(metric.label), metric.value))
	end
	container
		:tag('span')
		:addClass('t-dimensions-sr')
		:wikitext('Dimensions: ' .. table.concat(summaryParts, ', ') .. '.')
		:done()

	local stage = container:tag('div'):addClass('t-dimensions-stage'):attr('aria-hidden', 'true')

	local scene = stage:tag('div'):addClass('t-dimensions-scene'):css('transform-style', 'preserve-3d')

	local box, layerTop, layerBottom = buildBox()
	scene:node(box)

	-- Height: line in the right-face plane (rotation-proof) + billboarded label
	layerTop:node(buildLine('height'))
	layerTop
		:tag('div')
		:addClass('t-dimensions-anchor--height')
		:css('transform-style', 'preserve-3d')
		:node(buildText('height', 'Height', formatValue(data.height, 'm', data.heightAlt)))
		:done()

	-- Reference cuboid on the ground plane
	if data.reference then
		-- Root only; the faces are already wired up inside buildBox
		local refBox = buildBox('reference')
		layerBottom:node(refBox)
	end

	-- Ground-plane lines + labels
	layerBottom:node(buildLine('length'))
	layerBottom:node(buildText('length', 'Length', formatValue(data.length, 'm', data.lengthAlt)))
	layerBottom:node(buildLine('width'))
	layerBottom:node(buildText('width', 'Width', formatValue(data.width, 'm', data.widthAlt)))

	-- Footer: caller-supplied metrics + reference legend (omitted when both are
	-- absent). Each metric is a { label, value } pair with a pre-formatted value.
	local hasMetrics = data.metrics ~= nil and data.metrics[1] ~= nil
	if hasMetrics or data.reference then
		local footer = container:tag('div'):addClass('t-dimensions-footer')

		for _, metric in ipairs(data.metrics or {}) do
			local item = footer:tag('div'):addClass('t-dimensions-footer-item')
			item:tag('span'):addClass('t-dimensions-footer-label'):wikitext(metric.label):done()
			item:tag('span'):addClass('t-dimensions-footer-value'):wikitext(metric.value):done()
		end

		if data.reference then
			local legend = footer:tag('div'):addClass('t-dimensions-legend')
			legend:tag('span'):addClass('t-dimensions-swatch'):done()
			legend:tag('span'):wikitext(data.reference.label):done()
		end
	end

	return container
end

--- Lua entry point
---
--- @param args table
--- @param frame mw.frame|nil optional; falls back to mw.getCurrentFrame()
--- @return string|nil
function p._main(args, frame)
	if type(args) ~= 'table' then
		return nil
	end
	frame = frame or mw.getCurrentFrame()

	local data = parseArgs(args)
	if not data then
		return nil
	end

	return frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Dimensions/styles.css' },
	}) .. tostring(getHtml(data))
end

--- Wikitext entry point. Renders a bare box (reference and metrics are
--- Lua-only, table-valued arguments).
---
--- @param frame mw.frame
--- @return string|nil
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)
	return p._main(args, frame)
end

--- Exposed for Module:Dimensions/testcases only; not a public interface.
p._internal = {
	parseArgs = parseArgs,
	formatValue = formatValue,
	formatPlain = formatPlain,
	isBox = isBox,
}

return p
