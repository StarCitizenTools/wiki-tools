require('strict')

--- @module Entity/Item/Drink
--- Drink subtype. Adds drink-specific data section.
--- Note: The API returns drink data under the 'food' key for both Food and Drink types.

local util = require('Module:Entity/Util')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local food = apiData.food

	local items = {}

	if food then
		if food.nutritional_density_rating then
			table.insert(items, {
				label = 'NDR',
				content = tostring(food.nutritional_density_rating),
			})
		end

		if food.hydration_efficacy_index then
			table.insert(items, {
				label = 'HEI',
				content = tostring(food.hydration_efficacy_index),
			})
		end

		local effectsContent = util.buildHtmlList(food.effects)
		if effectsContent then
			table.insert(items, {
				label = 'Effects',
				content = effectsContent,
			})
		end

		if food.one_shot_consume ~= nil then
			table.insert(items, {
				label = 'Single use',
				content = food.one_shot_consume and 'Yes' or 'No',
			})
		end

		if food.can_be_reclosed ~= nil then
			table.insert(items, {
				label = 'Reclosable',
				content = food.can_be_reclosed and 'Yes' or 'No',
			})
		end
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'drink',
			label = 'Drink',
			collapsible = true,
			items = items,
		},
	}
end

--- Short description for drink: "[<effects>] drink [by <manufacturer>]".
--- All effects are joined with Oxford-comma English (e.g. "A and B", "A, B, and C").
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @return string
function p.getShortDescription(apiData, args, typeInfo)
	local item = require('Module:Entity/Item')
	local effects = apiData.food and apiData.food.effects
	local prefix = effects and util.joinAnd(effects)
	return item.formatShortDescription(typeInfo, apiData, args, prefix)
end

return p
