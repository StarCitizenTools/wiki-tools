require('strict')
local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local WearableSet = require('Module:WearableSet')

--- Installs a faithful `mw.title.new` for the duration of fn. The runner's shim
--- builds a title by copying its current-title stub, so `prefixedText` answers
--- the TEST PAGE's own title whatever text it is given (see
--- Module:Entity/StructuredData/testcases.lua's withTitleNew, which this
--- mirrors); bucketRows' PAGE field (Manufacturer) goes through
--- Module:Entity/StructuredData.shape, which reads `prefixedText`, so a test
--- asserting one needs the real echo. `titles` maps an input to either its
--- resolved `prefixedText`, or a table `{ prefixedText, redirectTarget }` to
--- also stub a redirect; an unlisted input echoes with no redirect. Restored
--- even if fn throws.
--- @param titles table<string, string|table>
--- @param fn fun()
local function withTitleNew(titles, fn)
	local realNew = mw.title.new
	mw.title.new = function(text)
		if type(text) ~= 'string' or text:find('|', 1, true) then
			return nil
		end
		local entry = titles[text]
		if type(entry) == 'table' then
			return { prefixedText = entry.prefixedText or text, redirectTarget = entry.redirectTarget }
		end
		return { prefixedText = entry or text, redirectTarget = false }
	end
	local ok, err = pcall(fn)
	mw.title.new = realNew
	if not ok then
		error(err, 0)
	end
end

function suite:testBucketRowsSplitsEntityAndSet()
	withTitleNew({}, function()
		local rows = WearableSet.bucketRows({ name = 'Bastion', image = 'File:Bastion.png' }, {
			classification = 'Light armor',
			manufacturer = 'Greycat Industrial',
			type = 'Armor set',
			tempMin = -120,
			tempMax = 220,
			radiation = 90,
			radiationScrub = 3.5,
		}, { gResistance = 4.2 })
		self:assertEquals('Bastion', rows.entity.name)
		self:assertEquals('Light armor', rows.entity.subject_type)
		self:assertEquals('Greycat Industrial', rows.entity.manufacturer)
		self:assertEquals('Armor set', rows.wearable_set.type)
		self:assertEquals(-120, rows.wearable_set.min_temperature)
		self:assertEquals(4.2, rows.wearable_set.g_resistance)
	end)
end

function suite:testBucketRowsOmitsMissingValues()
	local rows = WearableSet.bucketRows({ name = 'X' }, {
		classification = 'Undersuit',
		type = 'Undersuit',
		tempMin = 0,
		tempMax = 0,
		radiation = 0,
		radiationScrub = 0,
	}, { gResistance = 0.9 })
	self:assertEquals(nil, rows.entity.manufacturer)
	self:assertEquals(nil, rows.entity.image)
end

return suite
