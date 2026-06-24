require('strict')

local WearableSet = {}

local Data = require('Module:Entity/Data')
local Environment = require('Module:Entity/Facet/Environment')
local Damage = require('Module:Entity/Facet/Armor')

--- @param categories table Plain text categories in array
local function convertCategories(categories)
	local mapped = {}
	for _, category in pairs(categories) do
		if category then
			if string.sub(category, 1, 2) ~= '[[' then
				category = string.format('[[Category:%s]]', category)
			end

			table.insert(mapped, category)
		end
	end
	return table.concat(mapped)
end

local function sentenceCase(str)
	return (str:gsub('^%l', string.upper))
end

local function formatNumber(num)
	local sep = ' '

	local formatted = string.format('%f', num)
	local integer, fractional = string.match(formatted, '^(%-?%d+)(%.?%d*)$')

	while true do
		local count
		integer, count = string.gsub(integer, '^(%-?%d+)(%d%d%d)', '%1' .. sep .. '%2')
		if count == 0 then
			break
		end
	end

	return integer .. (fractional == '.000000' and '' or fractional)
end

local function processPorts(entity, values)
	local magazine = 0
	local grenade = 0
	local consumable = 0

	if not entity.ports then
		return
	end

	for _, port in pairs(entity.ports) do
		if port.name == 'wep_stocked_3' then
			values.weapon.primary = port.size
		elseif port.name == 'wep_stocked_2' then
			values.weapon.secondary = port.size
		elseif port.name == 'wep_sidearm' then
			values.weapon.sidearm = port.size
		elseif port.name == 'utility_attach_1' then
			values.utility.util1 = port.size
		elseif port.name == 'utility_attach_2' then
			values.utility.util2 = port.size
		elseif port.sub_type == 'Magazine' then
			magazine = magazine + 1
		elseif port.sub_type == 'Grenade' then
			grenade = grenade + 1
		elseif port.type == 'FPS_Consumable' then
			consumable = consumable + 1
		elseif port.type == 'Char_Armor_Backpack' then
			values.backpack = port.size
		end
	end

	table.insert(values.magazine, magazine)
	table.insert(values.grenade, grenade)
	table.insert(values.consumable, consumable)
end

local function processEntity(entity, values)
	local function insertIfNotNil(tbl, value)
		if value ~= nil then
			table.insert(tbl, value)
		end
	end

	if entity.suit_armor then
		local drm = entity.suit_armor.damage_resistance_map

		insertIfNotNil(values.resistance.impact, drm.impact)
		insertIfNotNil(values.resistance.physical, drm.physical)
		insertIfNotNil(values.resistance.energy, drm.energy)
		insertIfNotNil(values.resistance.distortion, drm.distortion)
		insertIfNotNil(values.resistance.thermal, drm.thermal)
		insertIfNotNil(values.resistance.biochemical, drm.biochemical)
		insertIfNotNil(values.resistance.stun, drm.stun)

		insertIfNotNil(values.emissionsEM, entity.suit_armor.signature.electromagnetic)
		insertIfNotNil(values.emissionsIR, entity.suit_armor.signature.infrared)
	end

	if entity.resource_container then
		if
			entity.resource_container.default_composition
			and #entity.resource_container.default_composition > 0
			and entity.resource_container.default_composition[1].commodity.name == 'EVA Fuel'
		then
			values.evaFuel = entity.resource_container.capacity.scu
		end
	end

	values.gResistance = values.gResistance + (entity.gforce_resistance or 0)

	insertIfNotNil(values.radiation, entity.radiation_resistance.maximum_radiation_capacity)
	insertIfNotNil(values.radiationScrub, entity.radiation_resistance.radiation_dissipation_rate)

	insertIfNotNil(values.tempMax, entity.temperature_resistance.max)
	insertIfNotNil(values.tempMin, entity.temperature_resistance.min)

	if entity.inventory and entity.inventory.scu_converted then
		values.inventory = values.inventory + entity.inventory.scu_converted
	end
end

local function processAll(entity, values)
	processPorts(entity, values)
	processEntity(entity, values)
end

--- @param frame table https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
function WearableSet.main(frame)
	local args = require('Module:Arguments').getArgs(frame)

	local categories = {}
	local values = {
		inventory = 0,
		weapon = { primary = 0, secondary = 0, sidearm = 0 },
		consumable = {},
		magazine = {},
		grenade = {},
		utility = { util1 = 0, util2 = 0 },
		tempMax = {},
		tempMin = {},
		radiation = {},
		radiationScrub = {},
		resistance = {
			physical = {},
			energy = {},
			distortion = {},
			thermal = {},
			biochemical = {},
			stun = {},
			impact = {},
		},
		evaFuel = 0,
		emissionsEM = {},
		emissionsIR = {},
		gResistance = 0,
		backpack = 0,
	}

	if args['undersuit'] then
		local response = Data.get({ uuid = args['undersuit'] })
		local entity = response.apiData
		local hasError = response.hasApiError

		if not hasError then
			processPorts(entity, values)

			if not args['arms'] and not args['legs'] then
				processEntity(entity, values)
			else
				values.gResistance = values.gResistance + (entity.gforce_resistance or 0)
			end
		end
	else
		values.gResistance = 0.9
	end
	if args['helmet'] then
		local response = Data.get({ uuid = args['helmet'] })
		local entity = response.apiData
		local hasError = response.hasApiError

		if not hasError then
			processAll(entity, values)
		end
	end
	if args['core'] then
		local response = Data.get({ uuid = args['core'] })
		local entity = response.apiData
		local hasError = response.hasApiError

		if not hasError then
			processAll(entity, values)
		end
	end
	--[[if args['backpack'] then
        local response = Data.get({ uuid = args['backpack'] })
        local entity = response.apiData
        local hasError = response.hasApiError

        if not hasError then
            values.inventory = values.inventory + entity.inventory.scu_converted

            processPorts(entity, values)
        end
    end]]
	if args['arms'] then
		local response = Data.get({ uuid = args['arms'] })
		local entity = response.apiData
		local hasError = response.hasApiError

		if not hasError then
			processAll(entity, values)
		end
	end
	if args['legs'] then
		local response = Data.get({ uuid = args['legs'] })
		local entity = response.apiData
		local hasError = response.hasApiError

		if not hasError then
			processAll(entity, values)
		end
	end

	local formatted = {
		weapon = '',
		utility = '',
		type = nil,
		manufacturer = 'Unknown manufacturer',
		classification = nil,
	}

	local function formatWeapon(x)
		if x > 0 then
			formatted.weapon = formatted.weapon .. 'S' .. x .. ', '
		end
	end
	if values.weapon.primary == values.weapon.secondary then
		if values.weapon.primary == 0 then
			formatted.weapon = 'None'
		else
			formatted.weapon = '2x S' .. values.weapon.primary .. ', '
		end
	else
		formatWeapon(values.weapon.primary)
		formatWeapon(values.weapon.secondary)
	end
	formatWeapon(values.weapon.sidearm)
	formatted.weapon = formatted.weapon:sub(1, -3)

	local function formatUtility(x)
		if x > 0 then
			formatted.utility = formatted.utility .. 'S' .. x .. ', '
		end
	end
	if values.utility.util1 == values.utility.util2 then
		formatted.utility = '2x S' .. values.utility.util1 .. ', '
	else
		formatUtility(values.utility.util1)
		formatUtility(values.utility.util2)
	end
	formatted.utility = formatted.utility:sub(1, -3)

	local processed = { resistance = {} }

	processed.tempMin = (#values.tempMin > 0 and math.max(unpack(values.tempMin)) or 0)
	processed.tempMax = (#values.tempMax > 0 and math.min(unpack(values.tempMax)) or 0)

	processed.radiation = (#values.radiation > 0 and math.min(unpack(values.radiation)) or 0)
	processed.radiationScrub = (#values.radiationScrub > 0 and math.min(unpack(values.radiationScrub)) or 0)

	processed.consumable = (#values.consumable > 0 and math.max(unpack(values.consumable)) or 0)
	processed.magazine = (#values.magazine > 0 and math.max(unpack(values.magazine)) or 0)
	processed.grenade = (#values.grenade > 0 and math.max(unpack(values.grenade)) or 0)

	processed.emissionsEM = (#values.emissionsEM > 0 and math.max(unpack(values.emissionsEM)) or 0)
	processed.emissionsIR = (#values.emissionsIR > 0 and math.max(unpack(values.emissionsIR)) or 0)

	formatted.inventory = formatNumber(values.inventory) .. ' µSCU'
	formatted.backpack = (values.backpack > 0 and 'S' .. values.backpack or 'None')
	formatted.evaFuel = tostring(values.evaFuel * 1000000) .. ' µSCU'

	for i, val in pairs(values.resistance) do
		if #val > 0 then
			processed.resistance[i] = math.min(unpack(val))
		else
			processed.resistance[i] = 0
		end
	end

	if args['type'] then
		processed.type = sentenceCase(args['type'])
		formatted.type = '[[' .. processed.type .. ']]'
		table.insert(categories, processed.type .. 's')

		if processed.type == 'Armor set' then
			table.insert(categories, 'Personal armor')
		end
	end

	if type(args['manufacturer']) == 'string' then
		if args['manufacturer'] == 'UNKN' then
			processed.manufacturer = nil
			table.insert(categories, 'Unknown manufacturer')
		elseif args['manufacturer'] == 'NONE' then
			processed.manufacturer = nil
			table.insert(categories, 'No manufacturer')
		else
			local man = require('Module:Manufacturer'):new():get(args['manufacturer'])
			local manText = args['manufacturer']

			if man then
				manText = man.name
			end

			processed.manufacturer = manText
			formatted.manufacturer = string.format('[[%s]]', processed.manufacturer)
			table.insert(categories, processed.manufacturer)
		end
	end

	if args['classification'] then
		processed.classification = sentenceCase(args['classification'])
		formatted.classification = '[[' .. processed.classification .. ']]'

		if processed.classification == 'Racing suit' or processed.classification == 'Armored flight suit' then
			table.insert(categories, 'Flight suit')
		else
			table.insert(categories, processed.classification)
		end
	end

	local environment = Environment.getSections({
		temperature_resistance = { min = processed.tempMin, max = processed.tempMax },
		radiation_resistance = {
			maximum_radiation_capacity = processed.radiation,
			radiation_dissipation_rate = processed.radiationScrub,
		},
		gforce_resistance = values.gResistance,
	})

	local damage = Damage.getSections({ suit_armor = { damage_resistance_map = processed.resistance } })

	if #environment > 0 then
		environment = environment[1]
		table.insert(environment.items, { label = 'Pressurized', content = args['pressurized'] })
	end

	if #damage > 0 then
		damage = damage[1]
	end

	local infobox = {
		title = args['name'] or mw.title.getCurrentTitle().subpageText,
		subtitle = formatted.manufacturer,
		image = args['image'],
		sections = {
			{
				items = {
					{ label = 'Type', content = formatted.type },
					{ label = 'Classification', content = formatted.classification },
					{ label = 'Sex', content = args['sex'] or 'Unisex' },
				},
			},
			{
				label = 'Capacity',
				collapsible = true,
				collapsed = false,
				items = {
					{ label = 'Inventory', content = formatted.inventory },
					{ label = 'Weapon', content = formatted.weapon },
					{ label = 'Utility Item', content = formatted.utility },
					{ label = 'Consumable', content = tostring(processed.consumable) },
					{ label = 'Magazine', content = tostring(processed.magazine) },
					{ label = 'Grenade', content = tostring(processed.grenade) },
					{ label = 'Backpack', content = formatted.backpack },
					{ label = 'EVA Fuel', content = formatted.evaFuel },
				},
			},
			{
				label = 'Environmental protection',
				collapsible = true,
				collapsed = false,
				class = 't-infobox-item--block',
				items = environment.items,
			},
			{
				label = 'Damage resistance',
				collapsible = true,
				collapsed = false,
				class = 't-infobox-item--block',
				items = damage.items,
			},
			{
				label = 'Emissions',
				collapsible = true,
				collapsed = true,
				items = {
					{ label = 'EM', content = tostring(processed.emissionsEM) },
					{ label = 'IR', content = tostring(processed.emissionsIR) },
				},
			},
		},
	}

	-- Set Semantic MediaWiki properties
	mw.smw.set({
		['Title'] = args['name'],
		['Type'] = processed.type,
		['Classification'] = processed.classification,
		['Image'] = args['image'],
		['Manufacturer'] = processed.manufacturer,
		['Minimum temperature'] = processed.tempMin,
		['Maximum temperature'] = processed.tempMax,
		['Radiation'] = processed.radiation,
		['Radiation scrub rate'] = processed.radiationScrub,
		['G Resistance'] = values.gResistance,
		['Subject type'] = processed.classification,
	})

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/styles.css' },
	})

	return styles .. tostring(require('Module:InfoboxLua').render(infobox)) .. convertCategories(categories)
end

return WearableSet
