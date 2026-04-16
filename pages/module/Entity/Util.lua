require('strict')

local p = {}

--- Merges a list of ordered section lists into a single ordered list of sections.
--- For matching keys, items are appended. First definition's metadata (label, collapsible, etc.) wins.
--- Display order is determined by the order entries appear across the input lists.
---
--- Each entry in the input lists is a table with a 'key' field and section data fields.
--- Example: { key = 'general', label = 'General', items = { ... } }
---
--- @param sectionsList table[][] List of ordered section lists from each module in the chain
--- @return table[] Ordered list of merged sections
function p.mergeSections(sectionsList)
	local order = {}
	local seen = {}
	local merged = {}

	for _, sections in ipairs(sectionsList) do
		for _, section in ipairs(sections) do
			local key = section.key

			if not seen[key] then
				seen[key] = true
				table.insert(order, key)
				merged[key] = {
					label = section.label,
					collapsible = section.collapsible,
					collapsed = section.collapsed,
					columns = section.columns,
					class = section.class,
					content = section.content,
					sections = section.sections,
					items = {},
				}
			end

			if section.items then
				for _, item in ipairs(section.items) do
					table.insert(merged[key].items, item)
				end
			end
		end
	end

	local result = {}
	for _, key in ipairs(order) do
		local section = merged[key]
		if #section.items == 0 then
			section.items = nil
		end
		table.insert(result, section)
	end

	return result
end

--- Merges a list of flat key-value tables. Later tables override earlier ones on key collision.
---
--- @param dataList table[] List of structured data tables from each module in the chain
--- @return table Merged key-value table
function p.mergeStructuredData(dataList)
	local result = {}
	for _, data in ipairs(dataList) do
		for k, v in pairs(data) do
			result[k] = v
		end
	end
	return result
end

--- Walks p.parent from a leaf module up to the root, returns the chain in root-first order.
---
--- @param leafModule table The leaf type module (e.g. WeaponGun)
--- @return table[] List of modules from root (Base) to leaf (WeaponGun)
function p.buildChain(leafModule)
	local chain = { leafModule }
	local current = leafModule

	while current.parent do
		current = require('Module:' .. current.parent)
		table.insert(chain, current)
	end

	-- Reverse to get root-first order
	local reversed = {}
	for i = #chain, 1, -1 do
		table.insert(reversed, chain[i])
	end

	return reversed
end

--- Fetches data from an API endpoint using mw.ext.Apiunto.
--- Returns the decoded and unwrapped response, or nil + error message on failure.
---
--- @param config table API config with name, endpoint, params, and optional responseDataPath
--- @param uuid string The entity UUID to substitute into the endpoint
--- @return table|nil data The API response data
--- @return string|nil error Error message if fetch failed
function p.fetchApi(config, uuid)
	local endpoint = string.format(config.endpoint, uuid)
	local success, response = pcall(mw.ext.Apiunto.fetch, config.name, endpoint, config.params)

	if not success then
		return nil, 'API fetch failed: ' .. tostring(response)
	end

	local ok, data = pcall(mw.text.jsonDecode, response)
	if not ok then
		return nil, 'JSON decode failed: ' .. tostring(data)
	end

	if config.responseDataPath then
		data = data[config.responseDataPath]
	end

	return data or {}
end

--- Collects API configs from all modules in the chain.
---
--- @param chain table[] The module chain (root to leaf)
--- @return table[] List of API configs
function p.collectApiConfigs(chain)
	local configs = {}
	for _, mod in ipairs(chain) do
		if mod.getApiConfigs then
			for _, config in ipairs(mod.getApiConfigs()) do
				table.insert(configs, config)
			end
		end
	end
	return configs
end

--- Fetches all API configs and merges results into a single table.
--- Returns the merged data and a boolean indicating if any fetch failed.
---
--- @param configs table[] List of API configs
--- @param uuid string The entity UUID
--- @return table apiData Merged API response data
--- @return boolean hasError True if any API fetch failed
function p.fetchAllApis(configs, uuid)
	local apiData = {}
	local hasError = false

	for _, config in ipairs(configs) do
		local data, err = p.fetchApi(config, uuid)
		if err then
			hasError = true
		elseif data then
			for k, v in pairs(data) do
				apiData[k] = v
			end
		end
	end

	return apiData, hasError
end

--- Builds a joined wikitext string of external links from site definitions.
--- Each definition is either { label, format, data } or { label, arg }.
--- Returns nil if no links can be built.
---
--- @param siteDefs table[] List of site link definitions
--- @param dataLookup table<string, string> Lookup table mapping data/arg keys to values
--- @return string|nil Joined wikitext (' · ' separated) or nil when empty
function p.buildSiteLinks(siteDefs, dataLookup)
	local links = {}

	for _, def in ipairs(siteDefs) do
		local url

		if def.arg then
			url = dataLookup[def.arg]
		elseif def.format and def.data then
			local value = dataLookup[def.data]
			if value then
				url = string.format(def.format, mw.uri.encode(value, 'QUERY'))
			end
		end

		if url then
			table.insert(links, '[' .. url .. ' ' .. def.label .. ']')
		end
	end

	if #links == 0 then
		return nil
	end

	return table.concat(links, ' · ')
end

return p
