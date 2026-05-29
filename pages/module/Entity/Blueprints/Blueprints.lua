require('strict')

--- @module Entity/Blueprints
--- Consumes Module:Entity/Data
--- so it shares Apiunto's cache with any other Entity template on the page.
---
--- NOTE: This is a temporary non interactive implementation.
--- An interactive implementation requires the creation of a MediaWiki extension.

local data = require('Module:Entity/Data')
local badgeLua = require('Module:BadgeLua')
local collapsibleCard = require('Module:CollapsibleCard')
local cardLua = require('Module:CardLua')
local tableLua = require('Module:TableLua')
local util = require('Module:Entity/Util')

local p = {}

--- Mirrors Module:Entity/Commodity.matches(). Commodities aren't craftable
--- and carry no own `blueprint`; instead they're crafting *ingredients*, so
--- this module renders a "used in crafting" summary for them.
---
--- @param apiData table
--- @return boolean
local function isCommodity(apiData)
	return type(apiData) == 'table' and apiData.box_sizes_scu ~= nil
end

--- How many crafting blueprints use `name` as an ingredient, via the
--- blueprints endpoint's `filter[ingredient]` (matched by name) — a single
--- cheap fetch reading `meta.total` (page size 1). Returns nil on fetch
--- failure. The %s arg is the only format directive; the encoded name is
--- passed as data (its `%XX` escapes are not reinterpreted), so this is safe.
---
--- @param name string
--- @return number|nil
local function usedInBlueprintCount(name)
	local resp = util.fetchApi({
		name = 'StarCitizenWikiAPI',
		endpoint = 'blueprints?filter[ingredient]=%s&page[size]=1',
	}, mw.uri.encode(name, 'QUERY'))
	if type(resp) == 'table' and resp.meta and type(resp.meta.total) == 'number' then
		return resp.meta.total
	end
	return nil
end

--- Formats a blueprint material's quantity. Resource materials are measured
--- in SCU (`quantity_scu`); item materials are discrete and carry a `quantity`
--- count with no SCU value. Returns '' when neither is present so callers
--- never concatenate a nil.
---
--- @param material table A blueprint input/return (has quantity_scu and/or quantity)
--- @return string
local function formatQuantity(material)
	if material.quantity_scu ~= nil then
		return material.quantity_scu .. ' SCU'
	end
	if material.quantity ~= nil then
		return tostring(material.quantity)
	end
	return ''
end

local function buildDescription(blueprint)
	local badge = badgeLua.render({
		text = 'Grade ' .. (blueprint.grade or '1'),
		class = 't-entity-blueprint-grade',
	})
	return blueprint.key .. badge
end

local function getBlueprints(apiData)
	local blueprints = apiData.blueprint
	if type(blueprints) == 'table' and #blueprints ~= 0 then
		return blueprints
	end
	return nil
end

local function renderEmpty(message)
	return tostring(mw.html.create('p'):addClass('t-entity-blueprint-empty'):wikitext(message))
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
		:wikitext(formatQuantity(aspect.input))
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
		description = buildDescription(blueprint),
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
			formatQuantity(entry),
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
		description = buildDescription(blueprint),
		content = content,
		open = true,
	})
end

--- Commodity branch: a static "Used in crafting" card with the count of
--- blueprints that use this commodity as an ingredient + a link to the full
--- filtered list. Commodities are used in hundreds of recipes (Aslarite: 830),
--- so a count + link scales where an enumerated table would not.
---
--- @param apiData table
--- @return string
local function renderCommodityUsedIn(apiData)
	local rec = apiData._refinedRecord or apiData
	local name = rec.name or apiData.name
	if not name then
		return renderEmpty('No crafting data available.')
	end

	local count = usedInBlueprintCount(name)
	if count == nil then
		return renderEmpty('Crafting usage data unavailable.')
	end
	if count == 0 then
		return renderEmpty('Not used as an ingredient in any known crafting recipe.')
	end

	local title = count == 1 and 'Used in 1 recipe' or ('Used in ' .. util.formatNum(count) .. ' recipes')
	-- Brackets in the query are %-encoded so they don't break the link target.
	local url = 'https://api.star-citizen.wiki/blueprints?filter%5Bingredient%5D=' .. mw.uri.encode(name, 'QUERY')
	return cardLua.renderLinkCard({
		title = title,
		button = {
			label = 'Browse recipes',
			url = url,
			icon = 'Star Citizen Wiki API - Logo.svg',
			weight = 'normal',
			class = 't-button--wiki-api',
		},
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

	if isCommodity(result.apiData) then
		return styles .. renderCommodityUsedIn(result.apiData)
	end

	local root = mw.html.create(nil)
	local blueprints = getBlueprints(result.apiData)

	local craftable, dismantlable = {}, {}
	if not result.hasApiError and blueprints then
		for _, bp in ipairs(blueprints) do
			if bp.aspects and bp.aspects.aspects then
				table.insert(craftable, bp)
			end
			if bp.dismantle_returns then
				table.insert(dismantlable, bp)
			end
		end
	end

	root:tag('h3'):wikitext('Blueprints')
	if result.hasApiError then
		root:wikitext(renderEmpty('Blueprint data unavailable.'))
	elseif #craftable == 0 then
		root:wikitext(renderEmpty('No blueprints found for this item.'))
	else
		for _, blueprint in ipairs(craftable) do
			root:tag('div'):addClass('t-entity-blueprint'):wikitext(renderBlueprint(blueprint))
		end
	end

	root:tag('h3'):wikitext('Dismantle')
	if result.hasApiError then
		root:wikitext(renderEmpty('Dismantle data unavailable.'))
	elseif #dismantlable == 0 then
		root:wikitext(renderEmpty('No dismantle returns for this item.'))
	else
		for _, blueprint in ipairs(dismantlable) do
			root:tag('div'):addClass('t-entity-dismantle'):wikitext(renderDismantle(blueprint))
		end
	end

	return styles .. tostring(root)
end

return p
