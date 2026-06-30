require('strict')

--- @module Entity/Vehicle/Overview
--- Vehicle Overview sub-builder: the labelless top identity section
--- (Type / Career / Role / Size / Model). Pure — consumes already-fetched
--- apiData/args, the Editorial.view, and the orchestrator-resolved type name
--- (passed in so this module never re-resolves the subtype → no circular require).

local base = require('Module:Entity/Base')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local vehicleUtil = require('Module:Entity/Vehicle/Util')
local lang = mw.language.getContentLanguage()

local p = {}

--- Size as "<matrix> (S<class>)" — ship-matrix size + the in-game size class.
--- Either part alone when the other is absent; nil when neither.
--- @return string|nil
local function sizeDisplay(apiData, args)
	local size = vehicleUtil.matrixSize(apiData, args)
	local matrix = size and lang:ucfirst(size) or nil
	local cls = tonumber(apiData.size_class)
	local game = cls and ('S' .. math.floor(cls + 0.5)) or nil
	if matrix and game then
		return matrix .. ' (' .. game .. ')'
	end
	return matrix or game
end

--- Career as a link to its browse category ("[[:Category:Combat career|Combat]]").
--- Capitalizes the first letter; "Multi" → "Multi-role". nil when no career.
--- @return string|nil
local function careerLink(career)
	if type(career) ~= 'string' or career == '' then
		return nil
	end
	local c = lang:ucfirst(career)
	if c == 'Multi' then
		c = 'Multi-role'
	end
	return '[[:Category:' .. c .. ' career|' .. c .. ']]'
end

--- "Model" row (legacy label for the series): the editorial series as
--- "<mfr code> <series>" linked to the manufacturer's series browse category,
--- or the plain series when no manufacturer. Appends a generation link when a
--- `generation` field resolves and series is present. nil when no series.
--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return string|nil
local function modelLink(apiData, args, ed)
	local series = ed:value('series')
	if series == nil or series == '' then
		return nil
	end
	local mfr = base.resolveManufacturer(apiData, args)
	local out
	if mfr and mfr.code and mfr.name then
		out = '[[:Category:' .. mfr.name .. ' ' .. series .. '|' .. mfr.code .. ' ' .. series .. ']]'
	else
		out = tostring(series)
	end
	local generation = ed:value('generation')
	if generation ~= nil and generation ~= '' then
		out = out .. ' [[:Category:' .. series .. ' ' .. generation .. '|' .. generation .. ']]'
	end
	return out
end

--- Overview section (labelless top section): type + identity rows under the title.
--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @param typeName string|nil  resolved subtype's getTypeInfo().name (orchestrator-supplied)
--- @return table
function p.build(apiData, args, ed, typeName)
	local overview = {}
	sectionBuilder.push(overview, 'Type', typeName)
	-- Career: wiki `career` param wins over the API (curated taxonomy). Direct arg
	-- read (not an editorial overlap field) — the difference is systematic, so it
	-- must not flag every vehicle into the manual-API-data maintenance category.
	sectionBuilder.push(overview, 'Career', careerLink(vehicleUtil.resolveCareer(apiData, args)))
	local role = vehicleUtil.resolveRole(apiData, args)
	if type(role) == 'table' then
		role = table.concat(role, ' / ')
	end
	sectionBuilder.push(overview, 'Role', role)
	sectionBuilder.push(overview, 'Size', sizeDisplay(apiData, args))
	sectionBuilder.push(overview, 'Model', modelLink(apiData, args, ed))
	return sectionBuilder.section({ key = 'overview', items = overview })
end

return p
