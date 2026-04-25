require('strict')

--- @module Entity/Ports
--- Consumes Module:Entity/Data
--- so it shares Apiunto's cache with any other Entity template on the page.

local data = require('Module:Entity/Data')

local p = {}

local function getPorts(apiData)
	local ports = apiData.ports
	if type(ports) == 'table' and #ports ~= 0 then
		return ports
	end
	return nil
end

--- @param apiData table
--- @return string|nil
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Ports/styles.css' },
	})

	local root = mw.html.create('div'):addClass('t-entity-ports')
	local ports = getPorts(result.apiData)

	if ports then
		for _, port in ipairs(ports) do
			if port.compatible_types and #port.compatible_types ~= 0 then
				local portDiv = root:tag('div'):addClass('t-entity-port')

				local sizeDiv = portDiv:tag('div'):addClass('t-entity-port-size')
				local sizeTitle = sizeDiv:tag('div'):addClass('t-entity-port-title')

				if port.sizes and port.sizes.min and port.sizes.max then
					if port.sizes.min ~= port.sizes.max then
						sizeTitle:wikitext(string.format('S%s-%s', port.sizes.min, port.sizes.max))
					else
						sizeTitle:wikitext('S' .. tostring(port.sizes.min))
					end
				else
					sizeTitle:wikitext('S' .. tostring(port.size or 0))
				end

				local itemDiv = portDiv:tag('div'):addClass('t-entity-port-item')

				itemDiv:tag('div'):addClass('t-entity-port-subtitle'):wikitext(port.name or '')

				local itemTitle = itemDiv:tag('div'):addClass('t-entity-port-title')

				if port.equipped_item then
					itemTitle:wikitext('[[' .. port.equipped_item.name .. ']]')
					itemDiv:addClass('t-entity-port-item--hasItem')
				else
					itemTitle:wikitext('No item equipped')
				end
			end
		end
	else
		root:tag('div')
			:addClass('t-entity-port')
			:tag('div')
			:addClass('t-entity-port-subtitle')
			:wikitext('No item ports found.')
	end

	return styles .. tostring(root)
end

return p
