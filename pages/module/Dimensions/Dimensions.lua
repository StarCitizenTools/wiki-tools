require('strict')

--- Module:Dimensions
--- Renders an isometric CSS-3D diagram of an object's bounding box: measurement
--- lines with end ticks on every axis, and caller-supplied metrics in the
--- box's bottom-right corner.
---
--- Domain-agnostic: the module knows nothing about what it is measuring, and
--- assumes no unit beyond metres for the geometry labels.
---
--- Machine-readable contract: the root element exposes raw SI values via
--- data-length / data-width / data-height (+ data-*-alt when an alternate
--- value renders), and data-gadget-dimensions-size (physical or stowed) for
--- the dimensions gadget.
---
--- Public interface:
--- {
---   length, width, height,           -- required, metres
---   lengthAlt, widthAlt, heightAlt,  -- optional, metres
---   stowed,                          -- optional boolean: the box is the stowed (cargo) size
---   metrics = {                      -- optional, ordered
---     { label = string, value = string },  -- value is a pre-formatted display string
---   },
--- } in, HTML string (or nil on invalid required args) out.

local p = {}

local lang = mw.getContentLanguage()

-- Hidden category the dimensions gadget is gated on (MediaWiki:Gadgets-definition
-- loads it only on pages in it), so pages without a diagram never fetch it.
local GADGET_CATEGORY = 'Pages using dimensions gadget'

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
		stowed = args.stowed == true,
		-- Lua-caller only: a table has no wikitext form
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

--- Build the isometric cuboid: two stacked layers, faces on the top layer
--- spanning down.
---
--- @return mw.html root
--- @return mw.html layerTop
--- @return mw.html layerBottom
local function buildBox()
	local root = mw.html.create('div'):addClass('t-dimensions-box'):css('transform-style', 'preserve-3d')

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
		:attr('data-gadget-dimensions-size', data.stowed and 'stowed' or 'physical')

	if data.lengthAlt then
		container:attr('data-length-alt', tostring(data.lengthAlt))
	end
	if data.widthAlt then
		container:attr('data-width-alt', tostring(data.widthAlt))
	end
	if data.heightAlt then
		container:attr('data-height-alt', tostring(data.heightAlt))
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

	-- Height: line in the right-face plane + billboarded label
	layerTop:node(buildLine('height'))
	layerTop
		:tag('div')
		:addClass('t-dimensions-anchor--height')
		:css('transform-style', 'preserve-3d')
		:node(buildText('height', 'Height', formatValue(data.height, 'm', data.heightAlt)))
		:done()

	-- Ground-plane lines + labels
	layerBottom:node(buildLine('length'))
	layerBottom:node(buildText('length', 'Length', formatValue(data.length, 'm', data.lengthAlt)))
	layerBottom:node(buildLine('width'))
	layerBottom:node(buildText('width', 'Width', formatValue(data.width, 'm', data.widthAlt)))

	-- Metrics in the bottom-right corner; aria-hidden because the summary reads them
	if data.metrics ~= nil and data.metrics[1] ~= nil then
		local list = container:tag('div'):addClass('t-dimensions-metrics'):attr('aria-hidden', 'true')
		for _, metric in ipairs(data.metrics) do
			local item = list:tag('div'):addClass('t-dimensions-metric')
			item:tag('div'):addClass('t-dimensions-text-label'):wikitext(metric.label):done()
			item:tag('div'):addClass('t-dimensions-text-value'):wikitext(metric.value):done()
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
	}) .. tostring(getHtml(data)) .. string.format('[[Category:%s]]', GADGET_CATEGORY)
end

--- Wikitext entry point. Renders a bare box: metrics are a Lua-only,
--- table-valued argument.
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
}

return p
