require('strict')

local Data = require('Module:Entity/Data')
local TableLua = require('Module:TableLua')
local DataStore = require('Module:Entity/StructuredData')

local function renderEmpty(message)
	return tostring(mw.html.create('p'):addClass('t-entity-order-empty'):wikitext(message))
end

local function formatQuantity(item)
	if item.min_scu then
		return tostring(item.min_scu) .. ' SCU', 0, item.min_scu
	end
	if item.min_amount or item.max_amount then
		return tostring(item.min_amount or item.max_amount) .. 'x', item.min_amount or item.max_amount, 0
	end
	return '?', 0, 0
end

local function formatSize(item)
	if not item.max_container_size and not item.max_scu and not item.min_scu then
		return '1 Unit'
	end
	if item.max_container_size == -1 then
		if item.max_scu == 1 then
			return '1 SCU'
		end
		if item.max_scu or item.min_scu then
			return '1 - 32 SCU'
		end
		return '1 Unit'
	end
	if item.max_container_size == 1 then
		return tostring(item.max_container_size) .. ' SCU'
	end
	return '1 - ' .. tostring(item.max_container_size) .. ' SCU'
end

local function processOrders(orders, ordersTable)
	local data = {}
	local total = {
		unique = 0,
		units = 0,
		scu = 0,
	}

	for _, order in ipairs(orders) do
		local x = {}
		local quantity, cargo = '', ''
		local units, scu = 0, 0

		quantity, units, scu = formatQuantity(order)

		if order.kind == 'TagMatch' then
			if order.max_container_size then
				cargo = 'Cargo'
			else
				cargo = 'Package'
			end
		else
			cargo = '[[' .. order.name .. ']]'
		end

		table.insert(x, quantity)
		table.insert(x, cargo)
		table.insert(x, formatSize(order))
		table.insert(data, x)

		table.insert(ordersTable, string.format('%s %s', quantity, cargo))

		total.unique = total.unique + 1
		total.units = total.units + units
		total.scu = total.scu + scu
	end

	return tostring(TableLua.render({
		caption = 'Total amount of orders',
		hideCaption = true,
		class = 'wikitable--fluid t-entity-orders-table',
		columns = {
			{ id = 'uniqueItems', label = 'Unique Items' },
			{ id = 'totalUnits', label = 'Total Units' },
			{ id = 'totalScu', label = 'Total SCU' },
		},
		data = { { total.unique, total.units, total.scu } },
	})) .. tostring(TableLua.render({
		caption = 'Orders',
		hideCaption = true,
		class = 'wikitable--fluid t-entity-orders-table',
		columns = {
			{ id = 'quantity', label = 'Quantity', textAlign = 'start' },
			{ id = 'cargo', label = 'Cargo', textAlign = 'start' },
			{ id = 'size', label = 'Size', textAlign = 'start' },
		},
		data = data,
	}))
end

local p = {}

--- @param apiData table
--- @return string|nil
function p.main(frame)
	local args = Data.parseArgs(frame)
	local result = Data.get(args)

	if not result.apiData or not result.apiData.hauling_orders or type(result.apiData.hauling_orders) ~= 'table' then
		return renderEmpty('No items requested by contract.')
	end

	local root = mw.html.create('div'):addClass('t-entity-order-container')

	local orderTable = {}

	root:wikitext(processOrders(result.apiData.hauling_orders, orderTable))

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Orders/styles.css' },
	})

	DataStore.store({ orders = orderTable })

	return styles .. tostring(root)
end

return p
