require('strict')

local Data = require('Module:Entity/Data')
local TableLua = require('Module:TableLua')
local Lines = require('Module:Entity/Rewards/Lines')
local emptyState = require('Module:Entity/EmptyState')

local function processBlueprints(groups)
	local data = {}

	for i, group in ipairs(groups) do
		local info = string.format('POOL %d - Drop chance %d%%', i, group.drop_chance_percent)
		local blueprints = {}

		for _, blueprint in ipairs(group.items) do
			table.insert(blueprints, { Lines.blueprintLine(blueprint) })
		end

		table.insert(data, { info = info, values = blueprints })
	end

	return data
end

local function processItems(groups)
	local data = {}

	for _, group in ipairs(groups) do
		local info = 'Awarded to all contract members.'
		if group.award_only_to_mission_owner then
			info = 'Awarded ONLY to contract owner.'
		end

		local items = {}

		for _, item in ipairs(group.items) do
			table.insert(items, { Lines.itemLine(item) })
		end

		table.insert(data, { info = info, values = items })
	end

	return data
end

local function renderSection(data)
	local t = {}

	for _, x in ipairs(data) do
		table.insert(
			t,
			TableLua.render({
				caption = x.info,
				class = 'wikitable--fluid t-entity-rewards-table',
				columns = {
					{ id = 'name', label = 'Name', textAlign = 'start' },
				},
				data = x.values,
			})
		)
	end

	return table.concat(t)
end

local p = {}

--- @param apiData table
--- @return string|nil
function p.main(frame)
	local args = Data.parseArgs(frame)
	local result = Data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Rewards/styles.css' },
	})

	local root = mw.html.create(nil)

	if result.hasApiError then
		root:tag('h3'):wikitext('Items')
		root:wikitext(emptyState.failed("Couldn't load awarded items."))

		root:tag('h3'):wikitext('Blueprints')
		root:wikitext(emptyState.failed("Couldn't load awarded blueprints."))

		return styles .. tostring(root)
	end

	local rewardGroups = result.apiData.reward_groups
	local blueprintGroups = result.apiData.blueprints

	root:tag('h3'):wikitext('Items')
	if not rewardGroups or #rewardGroups == 0 then
		root:wikitext(emptyState.none('No items awarded.'))
	else
		root:wikitext(renderSection(processItems(rewardGroups)))
	end

	root:tag('h3'):wikitext('Blueprints')
	if not blueprintGroups or #blueprintGroups == 0 then
		root:wikitext(emptyState.none('No blueprints awarded.'))
	else
		root:wikitext(renderSection(processBlueprints(blueprintGroups)))
	end

	return styles .. tostring(root)
end

return p
