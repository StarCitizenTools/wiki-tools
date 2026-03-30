require('strict')

--- @module Entity/Item/Food
--- Food subtype. Adds nutrition, effects, and consumption sections.

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

		if food.effects then
			table.insert(items, {
				label = 'Effects',
				content = table.concat(food.effects, ', '),
			})
		end

		if food.one_shot_consume ~= nil then
			table.insert(items, {
				label = 'Single use',
				content = food.one_shot_consume and 'Yes' or 'No',
			})
		end
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'food',
			label = 'Food',
			collapsible = true,
			items = items,
		},
	}
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local food = apiData.food
	if not food then
		return {}
	end

	return {
		ndr = food.nutritional_density_rating,
		hei = food.hydration_efficacy_index,
		oneShotConsume = food.one_shot_consume,
	}
end

return p
