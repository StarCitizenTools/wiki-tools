require('strict')

--- @module Entity/Blueprints
--- Consumes Module:Entity/Data
--- so it shares Apiunto's cache with any other Entity template on the page.
---
--- NOTE: This is a temporary non interactive implementation.
--- An interactive implementation requires the creation of a MediaWiki extension.

local data = require('Module:Entity/Data')
local collapsibleCard = require('Module:CollapsibleCard')
local tableLua = require('Module:TableLua')

local p = {}

local function formatSCU(val)
	return val .. ' SCU'
end

local function getBlueprints(apiData)
	local blueprints = apiData.blueprint
	if type(blueprints) == 'table' and #blueprints ~= 0 then
		return blueprints
	end
	return nil
end

local function renderAspect(aspect)
	local root = mw.html.create('div'):addClass('t-entity-blueprint-aspect')

	root:tag('div'):addClass('t-entity-blueprint-aspect__name'):wikitext(aspect.name):done()
	root:tag('div')
		:addClass('t-entity-blueprint-material')
		:tag('div')
		:addClass('t-entity-blueprint-material__name')
		:wikitext('[[' .. aspect.input.name .. ']]')
		:done()
		:tag('div')
		:addClass('t-entity-blueprint-material__quantity')
		:wikitext(formatSCU(aspect.input.quantity_scu))
		:done()
		:done()

	local function style(val, betterWhen)
		local higher, lower
		if betterWhen == 'lower' then
			higher = 't-entity-blueprint-aspect-modifier__red'
			lower = 't-entity-blueprint-aspect-modifier__green'
		elseif betterWhen == 'higher' then
			higher = 't-entity-blueprint-aspect-modifier__green'
			lower = 't-entity-blueprint-aspect-modifier__red'
		else
			return val
		end

		if val < 0 then
			return tostring(mw.html.create('span'):addClass(lower):wikitext(val .. ' %'))
		elseif val > 0 then
			return tostring(mw.html.create('span'):addClass(higher):wikitext(val .. ' %'))
		end
	end

	local rows = {}
	for _, entry in ipairs(aspect.modifiers) do
		table.insert(rows, {
			entry.label,
			style(entry.modifier_range.at_min_quality - 1, entry.better_when),
			style(entry.modifier_range.at_max_quality - 1, entry.better_when),
		})
	end

	root:wikitext(tableLua.render({
		caption = aspect.name,
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = {
			{ id = 'modifier', label = 'Modifier', textAlign = 'start' },
			{ id = 'min', label = 'Min', textAlign = 'number' },
			{ id = 'max', label = 'Max', textAlign = 'number' },
		},
		data = rows,
	}))

	return root
end

local function renderBlueprint(blueprint)
	local content = mw.html.create(nil)

	for _, entry in ipairs(blueprint.aspects.aspects) do
		content:node(renderAspect(entry))
	end

	return collapsibleCard.render({
		title = blueprint.output_name,
		description = blueprint.key .. ' | Grade ' .. (blueprint.grade or '1'),
		content = content,
		open = true,
	})
end

local function renderDismantle(blueprint)
	local content = mw.html.create(nil)

	local rows = {}
	for _, entry in ipairs(blueprint.dismantle_returns) do
		table.insert(rows, {
			'[[' .. entry.name .. ']]',
			formatSCU(entry.quantity_scu),
		})
	end

	content:wikitext(tableLua.render({
		caption = 'Returns',
		hideCaption = true,
		class = 'wikitable--fluid',
		columns = {
			{ id = 'material', label = 'Material', textAlign = 'start' },
			{ id = 'return', label = 'Return', textAlign = 'number' },
		},
		data = rows,
	}))

	return collapsibleCard.render({
		title = blueprint.output_name,
		description = blueprint.key .. ' | Grade ' .. (blueprint.grade or '1'),
		content = content,
		open = true,
	})
end

--- @param apiData table
--- @return string|nil
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Blueprints/styles.css' },
	})

	local root = mw.html.create(nil)
	local blueprints = getBlueprints(result.apiData)

	root:tag('h3'):wikitext('Blueprints')
	if blueprints and blueprints[1].aspects then
		for _, blueprint in ipairs(blueprints) do
			root:tag('div'):addClass('t-entity-blueprint'):wikitext(renderBlueprint(blueprint))
		end
	else
		root:tag('div')
			:addClass('t-entity-blueprint')
			:tag('div')
			:addClass('t-entity-blueprint-subtitle')
			:wikitext('No blueprints found for this item.')
	end
	root:tag('h3'):wikitext('Dismantle')
	if blueprints and blueprints[1].dismantle_returns then
		for _, blueprint in ipairs(blueprints) do
			root:tag('div'):addClass('t-entity-dismantle'):wikitext(renderDismantle(blueprint))
		end
	else
		root:tag('div')
			:addClass('t-entity-blueprint')
			:tag('div')
			:addClass('t-entity-blueprint-subtitle')
			:wikitext('No blueprints found for this item.')
	end

	return styles .. tostring(root)
end

return p
