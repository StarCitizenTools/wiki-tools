require('strict')

local libraryUtil = require('libraryUtil')
local checkType = libraryUtil.checkType
local checkTypeForNamedArg = libraryUtil.checkTypeForNamedArg

local p = {}

--- Checks if a value is a string and is not empty.
---
--- @param value any The value to check.
--- @return boolean True if the value is a non-empty string, false otherwise.
function p.isNonEmptyString(value)
	return type(value) == 'string' and value ~= ''
end

--- Checks if a value is a table and is not empty.
---
--- Uses `pairs` rather than `next` so it sees through the read-only proxy
--- returned by `mw.loadJsonData`, whose underlying table is empty and whose
--- entries are exposed via `__index`/`__pairs`.
---
--- @param value any The value to check.
--- @return boolean True if the value is a non-empty table, false otherwise.
function p.isNonEmptyTable(value)
	if type(value) ~= 'table' then
		return false
	end
	for _ in pairs(value) do
		return true
	end
	return false
end

--- Validates input data against a provided schema and constructs a new object.
--- Returns nil if validation fails.
---
--- @param rawData table
--- @param schema DataSchemaDefinition
--- @return table|nil
function p.validateAndConstruct(rawData, schema)
	checkType('Util.validateAndConstruct', 1, rawData, 'table')
	checkType('Util.validateAndConstruct', 2, schema, 'table')

	local newObject = {}

	for key, def in pairs(schema) do
		local value = rawData[key]

		if value ~= nil then
			checkTypeForNamedArg('Util.validateAndConstruct', tostring(key), value, def.type, false)
			newObject[key] = value
		elseif def.required then
			error('Input data missing required key: ' .. tostring(key))
		elseif def.default ~= nil then
			newObject[key] = def.default
		end
	end

	for key, _ in pairs(rawData) do
		if not schema[key] then
			error('Input data contains extraneous key not defined in schema: ' .. tostring(key))
		end
	end

	return newObject
end

--- Helper function to fix arrays from a JSON loaded with mw.loadJsonData.
---
--- @param array table The array to fix.
--- @return table The fixed array.
function p.fixJsonArray(array)
	if array == nil then
		return {}
	end

	checkType('Util.fixJsonArray', 1, array, 'table')

	local parts = {}
	for _, value in ipairs(array) do
		table.insert(parts, value)
	end
	return parts
end

return p
