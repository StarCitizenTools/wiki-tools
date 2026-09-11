require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local GroundVehicle = require('Module:Entity/Vehicle/GroundVehicle')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

function suite:testTypeInfoName()
	local ti = GroundVehicle.getTypeInfo(ctx({ is_vehicle = true }, {}))
	self:assertEquals('Ground vehicle', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = GroundVehicle.getTypeInfo(ctx({ is_vehicle = true }, {}))
	self:assertEquals('Ground vehicles', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- TMBL resolves to short='Tumbril'; size is omitted for ground vehicles.
	-- 'combat' not in ROLE_SUFFIXES → appends 'ground vehicle'.
	local apiData = { role = 'Combat' }
	local desc = GroundVehicle.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'TMBL' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('Tumbril combat ground vehicle', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role → manufacturer + typeNoun only.
	local apiData = {}
	local desc = GroundVehicle.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'TMBL' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('Tumbril ground vehicle', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'exploration' not in ROLE_SUFFIXES → appends 'ground vehicle'.
	local apiData = { role = 'Exploration' }
	local desc =
		GroundVehicle.getShortDescription({ apiData = apiData, args = {}, typeInfo = {}, prefix = nil, resolved = {} })
	self:assertEquals('Exploration ground vehicle', desc)
end

function suite:testFamilyTag()
	self:assertEquals('ground', GroundVehicle.family)
end

function suite:testPledgeCategory()
	local cats = GroundVehicle.getCategories(ctx({ msrp = 100 }, {}, {}))
	self:assertEquals('Pledge vehicles', cats[#cats])
	self:assertEquals(0, #GroundVehicle.getCategories(ctx({}, {}, {})))
end

return suite
