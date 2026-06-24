require('strict')

local Data = require('Module:Entity/Data')
local DataStore = require('Module:Entity/StructuredData')
local TableLua = require('Module:TableLua')

local function renderEmpty(message)
	return tostring(mw.html.create('p'):addClass('t-entity-order-empty'):wikitext(message))
end

local function processBlueprints(groups, rewardsTable)
	local data = {}

	for i, group in ipairs(groups) do
		local info = string.format('POOL %d - Drop chance %d%%', i, group.drop_chance_percent)
		local blueprints = {}

		for _, blueprint in ipairs(group.items) do
			local str = string.format('[[%s]] blueprint', blueprint.name)
			table.insert(blueprints, { str })
			table.insert(rewardsTable, str)
		end

		table.insert(data, { info = info, values = blueprints })
	end

	return data
end

local function processItems(groups, rewardsTable)
	local data = {}

	for _, group in ipairs(groups) do
		local info = 'Awarded to all contract members.'
		if group.award_only_to_mission_owner then
			info = 'Awarded ONLY to contract owner.'
		end

		local items = {}

		for _, item in ipairs(group.items) do
			local str = string.format('%dx [[%s]]', item.amount, item.name)
			table.insert(items, { str })
			table.insert(rewardsTable, str)
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
		root:wikitext(renderEmpty('Item data unavailable.'))

		root:tag('h3'):wikitext('Blueprints')
		root:wikitext(renderEmpty('Blueprint data unavailable.'))

		return styles .. tostring(root)
	end

	local rewardGroups = result.apiData.reward_groups
	local blueprintGroups = result.apiData.blueprints

	local rewardsTable = {}

	root:tag('h3'):wikitext('Items')
	if result.hasApiError then
		root:wikitext(renderEmpty('Item data unavailable.'))
	elseif not rewardGroups or #rewardGroups == 0 then
		root:wikitext(renderEmpty('No items awarded for this contract.'))
	else
		root:wikitext(renderSection(processItems(rewardGroups, rewardsTable)))
	end

	root:tag('h3'):wikitext('Blueprints')
	if result.hasApiError then
		root:wikitext(renderEmpty('Blueprint data unavailable.'))
	elseif not blueprintGroups or #blueprintGroups == 0 then
		root:wikitext(renderEmpty('No blueprints awarded for this contract.'))
	else
		root:wikitext(renderSection(processBlueprints(blueprintGroups, rewardsTable)))
	end

	DataStore.store({ rewards = rewardsTable })

	return styles .. tostring(root)
end

return p
