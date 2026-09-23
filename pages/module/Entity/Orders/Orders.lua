require('strict')

local Data = require('Module:Entity/Data')
local TableLua = require('Module:TableLua')
local Lines = require('Module:Entity/Orders/Lines')
local emptyState = require('Module:Entity/EmptyState')

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

local function processOrders(orders)
	local data = {}
	local total = {
		unique = 0,
		units = 0,
		scu = 0,
	}

	for _, order in ipairs(orders) do
		local x = {}
		local quantity, units, scu = Lines.formatQuantity(order)
		local cargo = Lines.cargoLabel(order)

		table.insert(x, quantity)
		table.insert(x, cargo)
		table.insert(x, formatSize(order))
		table.insert(data, x)

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

	local orders = result.apiData and result.apiData.hauling_orders
	if type(orders) ~= 'table' or #orders == 0 then
		if result.hasApiError then
			return emptyState.failed("Couldn't load requested items.")
		end
		return emptyState.none('No items requested.')
	end

	local root = mw.html.create('div'):addClass('t-entity-order-container')

	root:wikitext(processOrders(orders))

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Orders/styles.css' },
	})

	return styles .. tostring(root)
end

return p
