require('strict')

--- @module Entity/Facet/Consumable
--- Consumable facet. Data-driven: matches any entity carrying `apiData.food`
--- (Food items, Drink items, and — once Commodity.enrich attaches it — edible
--- commodities). Replaces the former Item/Food and Item/Drink subtype modules,
--- which were the same facet split under single inheritance. The only real
--- difference between them was Drink's `can_be_reclosed` row, now rendered
--- data-driven below.

local format = require('Module:Entity/Format')

local p = {}

--- Data-driven match: presence of the `food` payload. Nil-safe; never reads
--- kind identity. Returns a strict boolean.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.food ~= nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local food = apiData.food
	if not food then
		return {}
	end

	local items = {}

	if food.nutritional_density_rating then
		table.insert(items, { label = 'NDR', content = tostring(food.nutritional_density_rating) })
	end

	if food.hydration_efficacy_index then
		table.insert(items, { label = 'HEI', content = tostring(food.hydration_efficacy_index) })
	end

	local effectsContent = format.buildHtmlList(food.effects)
	if effectsContent then
		table.insert(items, { label = 'Effects', content = effectsContent })
	end

	if food.one_shot_consume ~= nil then
		table.insert(items, { label = 'Single use', content = food.one_shot_consume and 'Yes' or 'No' })
	end

	-- Reclosable was Drink-only under the old subtypes. Gate on presence so it
	-- collapses for food and appears for drink, without branching on kind.
	if food.can_be_reclosed ~= nil then
		table.insert(items, { label = 'Reclosable', content = food.can_be_reclosed and 'Yes' or 'No' })
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'consumable',
			label = 'Consumable',
			collapsible = true,
			items = items,
		},
	}
end

--- Optional short-description adjective: the consumable's effects joined with
--- Oxford-comma English (e.g. "Stimulant", "Stimulant and Healing"). The kind
--- composes this into its noun ("Stimulant food by Aopoa"). Returns nil when no
--- effects are present so the kind's plain description stands.
---
--- @param apiData table
--- @param args table
--- @return string|nil
function p.getShortDescriptionPrefix(apiData, args)
	local effects = apiData.food and apiData.food.effects
	return effects and format.joinAnd(effects) or nil
end

return p
