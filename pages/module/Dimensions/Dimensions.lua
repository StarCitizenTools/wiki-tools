require('strict')

--- Module:Dimensions
--- Renders an isometric CSS-3D diagram of an object's bounding box at honest
--- scale: measurement lines with end ticks on every axis, an optional
--- reference object standing on the same ground plane, and a footer bar
--- carrying the mass and the reference legend.
---
--- Machine-readable contract: the root element exposes raw SI values via
--- data-length / data-width / data-height (+ data-*-alt when an alternate
--- value renders), data-mass, data-volume (+ data-volume-unit) and
--- data-reference.
---
--- Public interface:
--- { length, width, height, lengthAlt, widthAlt, heightAlt, mass, volume,
--- volumeUnit, referenceType } in, HTML string (or nil on invalid required
--- args) out. volume + volumeUnit render a footer metric in place of mass
--- (cargo diagrams); volumeUnit defaults to SCU.
--- Consumers: Module:Vehicle, Module:Item.

local p = {}

local lang = mw.getContentLanguage()

--- Reference objects selectable via the referenceType argument.
--- Dimensions are metres. Adding a type is one entry here plus a slot in
--- REFERENCE_LADDER below.
--- @type table<string, { length: number, width: number, height: number, legend: string }>
local REFERENCE_TYPES = {
	human = {
		length = 0.3,
		width = 0.5,
		height = 1.8,
		legend = 'Human · 1.8 m',
	},
	-- Standing upright: the slim footprint keeps it from dominating the
	-- ground plane next to small items, and the 0.2 m height reads directly
	-- against the object's height
	banana = {
		length = 0.05,
		width = 0.05,
		height = 0.2,
		legend = 'Banana · 0.2 m',
	},
	-- The standard CIG 1 SCU cargo container, the unit cube of cargo. Selected
	-- only via an explicit referenceType='scuBox' (cargo diagrams); deliberately
	-- absent from REFERENCE_LADDER so physical-object auto-selection never picks
	-- it.
	scuBox = {
		length = 1.25,
		width = 1.25,
		height = 1.25,
		legend = '1 SCU box · 1.25 m',
	},
}

--- Size ladder for referenceType = 'auto', ordered largest first.
--- @type string[]
local REFERENCE_LADDER = { 'human', 'banana' }

--- Pick the largest reference that does not exceed the object's longest
--- dimension, so the reference informs without dominating. Objects smaller
--- than every reference get the smallest one: being dwarfed by a banana IS
--- the scale story.
---
--- @param longest number the object's longest dimension in metres
--- @return string key into REFERENCE_TYPES
local function resolveAutoReference(longest)
	for _, key in ipairs(REFERENCE_LADDER) do
		local ref = REFERENCE_TYPES[key]
		if math.max(ref.length, ref.width, ref.height) <= longest then
			return key
		end
	end
	return REFERENCE_LADDER[#REFERENCE_LADDER]
end

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
		mass = tonumber(args.mass),
		volume = tonumber(args.volume),
		volumeUnit = args.volumeUnit,
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

	local referenceType = args.referenceType
	if referenceType == 'auto' then
		referenceType = resolveAutoReference(math.max(length, width, height))
	end
	if referenceType and REFERENCE_TYPES[referenceType] then
		data.referenceType = referenceType
		data.reference = REFERENCE_TYPES[referenceType]
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
	if data.mass then
		container:attr('data-mass', tostring(data.mass))
	end
	if data.volume then
		container:attr('data-volume', tostring(data.volume))
		container:attr('data-volume-unit', data.volumeUnit or 'SCU')
	end
	if data.reference then
		container
			:addClass('t-dimensions--has-reference')
			-- Per-type styling hook, e.g. the banana's yellow tint
			:addClass(
				't-dimensions--ref-' .. data.referenceType
			)
			:attr('data-reference', data.referenceType)
			:css({
				['--t-dimensions-reference-length'] = tostring(data.reference.length),
				['--t-dimensions-reference-width'] = tostring(data.reference.width),
				['--t-dimensions-reference-height'] = tostring(data.reference.height),
			})
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
	if data.mass then
		table.insert(summaryParts, string.format('mass %s', formatPlain(data.mass, 'kg')))
	end
	if data.volume then
		table.insert(summaryParts, string.format('volume %s', formatPlain(data.volume, data.volumeUnit or 'SCU')))
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

	-- Footer: primary metric (volume or mass) + reference legend; omitted when
	-- all are absent. Normal use passes exactly one metric per render (cargo
	-- diagrams pass volume, physical diagrams pass mass).
	if data.volume or data.mass or data.reference then
		local footer = container:tag('div'):addClass('t-dimensions-footer')

		local function addMetric(label, valueHtml)
			local item = footer:tag('div'):addClass('t-dimensions-footer-item')
			item:tag('span'):addClass('t-dimensions-footer-label'):wikitext(label):done()
			item:tag('span'):addClass('t-dimensions-footer-value'):wikitext(valueHtml):done()
		end

		if data.volume then
			addMetric('Volume', formatPlain(data.volume, data.volumeUnit or 'SCU'))
		end

		if data.mass then
			addMetric('Mass', formatPlain(data.mass, 'kg'))
		end

		if data.reference then
			local legend = footer:tag('div'):addClass('t-dimensions-legend')
			legend:tag('span'):addClass('t-dimensions-swatch'):done()
			legend:tag('span'):wikitext(data.reference.legend):done()
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

--- Wikitext entry point
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
	REFERENCE_TYPES = REFERENCE_TYPES,
}

return p
