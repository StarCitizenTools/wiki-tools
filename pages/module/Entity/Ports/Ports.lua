require('strict')

--- @module Entity/Ports
--- Renders an entity's ports as a vertical stack of category cards.
--- Thin coordinator: parses args, fetches API data, dispatches to
--- Pipeline + Render. All real work lives in those modules.
---
--- Consumes Module:Entity/Data so it shares Apiunto's cache with any
--- other Entity-family template on the page.

local data = require('Module:Entity/Data')
local Vehicle = require('Module:Entity/Vehicle')
local pipeline = require('Module:Entity/Ports/Pipeline')
local render = require('Module:Entity/Ports/Render')
local PageResolver = require('Module:Entity/PageResolver')

local p = {}

--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Ports/styles.css' },
	})

	local function empty(text)
		local root = mw.html.create('p'):addClass('t-entity-ports-empty'):wikitext(text)
		return styles .. tostring(root)
	end

	if result.hasApiError then
		return empty('Port data unavailable.')
	end
	local rawPorts = result.apiData and result.apiData.ports
	if type(rawPorts) ~= 'table' or #rawPorts == 0 then
		return empty('No ports.')
	end

	local groups = pipeline.process(rawPorts, { isVehicle = Vehicle.matches(result.apiData) })
	pipeline.applyResolvedLinks(groups, PageResolver.resolve(pipeline.collectEquippedUuids(groups)))
	return styles .. render.fromGroups(groups)
end

return p
