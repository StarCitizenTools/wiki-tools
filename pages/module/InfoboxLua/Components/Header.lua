require('strict')

local tabber = mw.ext.tabber
local util = require('Module:InfoboxLua/Util')
local types = require('Module:InfoboxLua/Types')

local p = {}

-- PageImages scores class="pageimage" at +1000 (T91683, MediaWiki 1.44+), which
-- lets the infobox claim the page image instead of leaving it to the extension's
-- position/width/ratio heuristics. Only the first image carries it.
local PAGE_IMAGE_CLASS = 'pageimage'

-- The upload placeholder is not a picture of the subject, so it never stands in
-- as the page image. notpageimage short-circuits scoring at -1000, ahead of the
-- pageimage boost, which leaves the page to fall back to a real image or none.
local NOT_PAGE_IMAGE_CLASS = 'notpageimage'

--- @param image ImageComponentData|string
--- @param isPageImage boolean|nil Whether this image is the page's designated page image.
--- @return mw.html
local function getImageHtml(image, isPageImage)
	if type(image) == 'string' then
		image = { src = image }
	end

	local imageData = util.validateAndConstruct(image, types.ImageComponentDataSchema)

	local isPlaceholder = type(imageData.upload) == 'table' and util.isNonEmptyString(imageData.upload.name)

	local root = mw.html.create('div')
	root:addClass('t-infobox-image-container')

	if isPlaceholder then
		root:addClass('t-infobox-image-container--placeholder')
		root:attr('data-gadget-quantumupload-name', imageData.upload.name)
		if util.isNonEmptyString(imageData.upload.categories) then
			root:attr('data-gadget-quantumupload-categories', imageData.upload.categories)
		end
	end

	local classes = {}
	if util.isNonEmptyString(imageData.class) then
		table.insert(classes, imageData.class)
	end
	if isPlaceholder then
		table.insert(classes, NOT_PAGE_IMAGE_CLASS)
	elseif isPageImage then
		table.insert(classes, PAGE_IMAGE_CLASS)
	end

	root:tag('div')
		:addClass('t-infobox-image')
		:wikitext(string.format('[[File:%s|%dpx|class=%s]]', imageData.src, imageData.size, table.concat(classes, ' ')))
		:done()

	if util.isNonEmptyString(imageData.overlay) then
		root:tag('div')
			:addClass('t-infobox-image-overlay')
			:attr('aria-hidden', 'true')
			:wikitext(imageData.overlay)
			:done()
	end

	return root
end

--- @param images ImageComponentData[]
--- @return mw.html
local function getImagesHtml(images)
	local root = mw.html.create('div')
	root:addClass('t-infobox-images')

	local tabberData = {}

	for i, image in ipairs(images) do
		if util.validateAndConstruct(image, types.ImageComponentDataSchema) then
			table.insert(tabberData, {
				label = image.label or tostring(i),
				content = tostring(getImageHtml(image, i == 1)),
			})
		end
	end

	if #tabberData > 0 then
		root:node(tabber.render(tabberData))
	end

	return root
end

--- @param title string
--- @return mw.html
local function getHeaderTitleHtml(title)
	local root = mw.html.create('div')
	root:addClass('t-infobox-title')
	root:attr('role', 'heading')
	root:attr('aria-level', '2')
	root:wikitext(title)
	return root
end

--- @param subtitle string
--- @return mw.html
local function getHeaderSubtitleHtml(subtitle)
	local root = mw.html.create('div')
	root:addClass('t-infobox-subtitle')
	root:wikitext(subtitle)
	return root
end

--- @param title string
--- @param subtitle string
--- @return mw.html
local function getHeaderContentHtml(title, subtitle)
	local root = mw.html.create('div')
	root:addClass('t-infobox-header-content')

	if util.isNonEmptyString(subtitle) then
		root:node(getHeaderSubtitleHtml(subtitle))
	end

	root:node(getHeaderTitleHtml(title))

	return root
end

--- Returns the mw.html object of the infobox header component.
---
--- @param data table
--- @return mw.html|nil
function p.getHtml(data)
	--- @type HeaderComponentData|nil
	local header = util.validateAndConstruct(data, types.HeaderComponentDataSchema)

	if not header then
		return nil
	end

	local root = mw.html.create('div')
	root:addClass('t-infobox-header')

	if type(header.images) == 'table' then
		root:node(getImagesHtml(header.images))
	elseif type(header.image) == 'table' then
		root:node(getImageHtml(header.image, true))
	end

	root:node(getHeaderContentHtml(header.title, header.subtitle))

	return root
end

return p
