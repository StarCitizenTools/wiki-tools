require('strict')

--- @module Entity/LocationNavigation/Render
--- Panel models → HTML inside Module:CollapsibleCard shells.

local collapsibleCard = require('Module:CollapsibleCard')
local gauge = require('Module:Entity/LocationNavigation/Gauge')
local model = require('Module:Entity/LocationNavigation/Model')

local p = {}

local PREFIX = 't-location-nav__'

--- One gauge element as an absolutely positioned span.
local function element(el, variant)
	local node = mw.html.create('span'):addClass(PREFIX .. el.class):addClass(PREFIX .. 'g--' .. variant)
	if el.modifier then
		node:addClass(PREFIX .. el.class .. '--' .. el.modifier)
	end
	node:css('left', el.left .. 'px'):css('top', el.top .. 'px')
	local width = el.width or el.size
	if width then
		node:css('width', width .. 'px'):css('height', (el.height or el.size) .. 'px')
	end
	if el.height and not el.width then
		node:css('height', el.height .. 'px')
	end
	if el.bottom then
		node:css('bottom', el.bottom .. 'px')
	end
	if el.file then
		node:wikitext(string.format('[[File:%s|%dpx|link=|alt=]]', el.file, el.size))
	end
	if el.text then
		node:wikitext(el.text)
	end
	return node
end

local function gaugeCell(elements)
	local cell = mw.html.create('div'):addClass(PREFIX .. 'gauge'):attr('aria-hidden', 'true')
	for _, variant in ipairs({ 'wide', 'narrow' }) do
		for _, el in ipairs(elements[variant]) do
			cell:node(element(el, variant))
		end
	end
	return cell
end

local function groupsNode(groups)
	local root = mw.html.create('div'):addClass(PREFIX .. 'groups')
	for _, group in ipairs(groups) do
		local node = root:tag('div'):addClass(PREFIX .. 'group')
		node:tag('div'):addClass(PREFIX .. 'group-heading'):wikitext(group.heading)
		local list = node:tag('ul'):addClass(PREFIX .. 'list')
		for _, entry in ipairs(group.entries) do
			local item = list:tag('li')
			if entry.family then
				item:addClass(PREFIX .. 'family')
				item:tag('span'):addClass(PREFIX .. 'family-name'):wikitext(entry.family)
				local codes = item:tag('span'):addClass(PREFIX .. 'codes')
				for _, member in ipairs(entry.members) do
					codes:tag('span'):wikitext(model.link(member.page, member.label))
				end
			else
				item:wikitext(model.link(entry.page, entry.label))
			end
		end
	end
	return root
end

local function cardNode(card)
	local node = mw.html.create('div'):addClass(PREFIX .. 'card')
	if card.image then
		node:tag('span')
			:addClass(PREFIX .. 'card-image')
			:wikitext(string.format('[[File:%s|112px|link=|alt=]]', card.image))
	end
	local body = node:tag('div'):addClass(PREFIX .. 'card-body')
	body:tag('div'):addClass(PREFIX .. 'card-class'):wikitext(card.class)
	body:tag('div'):addClass(PREFIX .. 'card-title'):wikitext(model.link(card.page, card.label))
	if card.meta then
		body:tag('div'):addClass(PREFIX .. 'card-meta'):wikitext(card.meta)
	end
	return node
end

local function pointsLine(items)
	local line = mw.html.create('div'):addClass(PREFIX .. 'line'):addClass(PREFIX .. 'points')
	for _, item in ipairs(items) do
		line:tag('span'):wikitext(model.link(item.page, item.point))
	end
	return line
end

local function rowNode(row, disc, first)
	local node = mw.html.create('div'):addClass(PREFIX .. 'row'):addClass(PREFIX .. 'row--' .. row.key)
	node:node(gaugeCell(gauge.row(row, disc, first)))
	node:tag('div'):addClass(PREFIX .. 'label'):wikitext(row.label or '')
	local content = node:tag('div'):addClass(PREFIX .. 'content')
	if row.cards and row.cards[1] then
		local cards = content:tag('div'):addClass(PREFIX .. 'cards')
		for _, card in ipairs(row.cards) do
			cards:node(cardNode(card))
		end
	end
	if row.groups and row.groups[1] then
		content:node(groupsNode(row.groups))
	end
	for _, moon in ipairs(row.moons or {}) do
		local line = content:tag('div'):addClass(PREFIX .. 'line')
		line:wikitext(model.link(moon.page, moon.label))
		if moon.designation then
			line:tag('span'):addClass(PREFIX .. 'desig'):wikitext(moon.designation)
		end
	end
	if row.near and row.near[1] then
		content:node(pointsLine(row.near))
	end
	if row.far and row.far[1] then
		content:node(pointsLine(row.far))
	end
	return node
end

--- @param panel table Model.bodyPanel result
--- @return string
function p.bodyPanel(panel)
	local rows = mw.html.create('div'):addClass(PREFIX .. 'rows')
	for i, row in ipairs(panel.rows) do
		rows:node(rowNode(row, panel.disc, i == 1))
	end
	return collapsibleCard.render({
		eyebrow = panel.eyebrow,
		title = panel.title,
		content = tostring(rows),
		open = true,
		class = 't-location-nav t-location-nav--body',
	})
end

--- @param panel table Model.insidePanel result
--- @return string
function p.insidePanel(panel)
	local rows = mw.html.create('div'):addClass(PREFIX .. 'inside')
	for _, group in ipairs(panel.groups) do
		local row = rows:tag('div'):addClass(PREFIX .. 'inside-row')
		row:tag('div'):addClass(PREFIX .. 'inside-label'):wikitext(group.heading)
		local list = row:tag('ul'):addClass(PREFIX .. 'inside-list')
		for _, entry in ipairs(group.entries) do
			list:tag('li'):wikitext(model.link(entry.page, entry.label))
		end
	end
	return collapsibleCard.render({
		eyebrow = panel.eyebrow,
		title = panel.title,
		content = tostring(rows),
		open = true,
		class = 't-location-nav t-location-nav--inside',
	})
end

return p
