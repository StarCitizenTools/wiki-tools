require('strict')

local PLACEHOLDER_IMAGE = 'Placeholderv2.png'
local PLACEHOLDER_IMAGE_SIZE = 400
local INFOBOX_WIDTH = 400

local headerComponent = require('Module:InfoboxLua/Components/Header')
local sectionComponent = require('Module:InfoboxLua/Components/Section')
local imageResolver = require('Module:InfoboxLua/ImageResolver')

--- @class InfoboxLuaData
--- @field class string|nil An additional HTML class for the infobox's container. Optional.
--- @field css table<string, string>|nil Additional CSS rules for the infobox. Optional.
--- @field title string The title of the infobox.
--- @field subtitle string|nil The subtitle of the infobox. Optional.
--- @field image ImageComponentData|string|nil The main image of the infobox. Optional.
--- @field imageUploadName string|nil Override for the auto-discovery / upload convention base. Optional.
--- @field images table<ImageComponentData>|nil The images of the infobox. Optional.
--- @field sections table<SectionComponentData>|nil The sections of the infobox. Optional.

local p = {}

--- Get the image data, auto-discovering the conventional quick-upload image and,
--- failing that, marking the placeholder for the QuantumUpload gadget.
---
--- @param image string|ImageComponentData|nil
--- @param uploadNameOverride string|nil Convention base override; defaults to '<page title> - infobox'.
--- @return ImageComponentData
local function getImageData(image, uploadNameOverride)
	local imageData = {}

	if type(image) == 'string' then
		imageData.src = image
	end

	if type(image) == 'table' then
		imageData = image
	end

	if type(imageData.size) ~= 'number' then
		imageData.size = INFOBOX_WIDTH
	end

	-- No explicit image source: try to auto-discover the conventionally-named
	-- quick-upload image; otherwise use the placeholder and attach the upload
	-- contract so the QuantumUpload gadget can offer an upload control.
	if type(imageData.src) ~= 'string' then
		local base = uploadNameOverride or imageResolver.conventionBase(mw.title.getCurrentTitle().text)
		local discovered = imageResolver.resolveDiscoveredSrc(base)
		if type(discovered) == 'string' then
			imageData.src = discovered
		else
			imageData.src = PLACEHOLDER_IMAGE
			imageData.size = PLACEHOLDER_IMAGE_SIZE
			imageData.upload = { name = base }
		end
	end

	return imageData
end

--- @param data InfoboxLuaData
--- @return mw.html
local function getContentHtml(data)
	local contentHtml = mw.html.create('div'):addClass('t-infobox-content')

	contentHtml:node(headerComponent.getHtml({
		title = data.title,
		subtitle = data.subtitle or nil,
		image = getImageData(data.image, data.imageUploadName),
		images = data.images or nil,
	}))

	for _, section in ipairs(data.sections) do
		local sectionHtml = sectionComponent.getHtml(section)
		if sectionHtml then
			contentHtml:node(sectionHtml)
		end
	end

	return contentHtml
end

--- @param data InfoboxLuaData
--- @return mw.html
local function getInfoboxHtml(data)
	local root = mw.html.create('div')
	root:addClass('t-infobox floatright')
		:addClass(data.class)
		:attr('role', 'complementary')
		:attr('aria-label', data.title)
		:css('max-width', INFOBOX_WIDTH .. 'px')
		:node(getContentHtml(data))

	if type(data.css) == 'table' then
		for cssProperty, cssValue in pairs(data.css) do
			root:css(cssProperty, cssValue)
		end
	end

	return root
end

--- @param data InfoboxLuaData
--- @return string
function p.render(data)
	local html = getInfoboxHtml(data)
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:InfoboxLua/styles.css' },
	})

	return styles .. tostring(html)
end

function p.test()
	local data = mw.loadJsonData('Module:InfoboxLua/testData.json')
	local html = p.render(data)

	mw.logObject(data)
	mw.logObject(html)

	return html
end

return p
