require('strict')

--- @module Entity/Api
--- Apiunto I/O for the Entity system. The single seam that talks to
--- mw.ext.Apiunto; callers pass an EntityApiConfig and a UUID.

local p = {}

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

return p
