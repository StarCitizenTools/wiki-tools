require('strict')

--- @module Entity/Ports
--- Renders an entity's ports as a vertical stack of category cards.
--- Thin coordinator: parses args, resolves the chain's getPorts payload,
--- dispatches to Pipeline + Render. All real work lives in those modules.
---
--- Consumes Module:Entity/Data so it shares Apiunto's cache with any
--- other Entity-family template on the page.

local data = require('Module:Entity/Data')
local assembly = require('Module:Entity/Assembly')
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
	-- The chain decides what "ports" means (getPorts, leaf-first; Base
	-- supplies the record's own tree). This renderer never reads apiData.
	local payload = assembly.resolveMostSpecific(result.chain, 'getPorts', nil, result.apiData, args) or {}
	local rawPorts = payload.ports
	if type(rawPorts) ~= 'table' or #rawPorts == 0 then
		return empty('No ports.')
	end

	local groups = pipeline.process(rawPorts, { narrowChildren = payload.narrowChildren == true })
	pipeline.applyResolvedLinks(groups, PageResolver.resolve(pipeline.collectEquippedUuids(groups)))
	return styles .. render.fromGroups(groups)
end

return p
