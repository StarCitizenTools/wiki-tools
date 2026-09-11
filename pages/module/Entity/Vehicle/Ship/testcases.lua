require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Ship = require('Module:Entity/Vehicle/Ship')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

function suite:testTypeInfoName()
	local ti = Ship.getTypeInfo(ctx({ is_spacecraft = true }, {}))
	self:assertEquals('Spacecraft', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = Ship.getTypeInfo(ctx({ is_spacecraft = true }, {}))
	self:assertEquals('Ships', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- args.manufacturer resolves via Module:Manufacturers; RSI has short='RSI'.
	-- 'fighter' is in ROLE_SUFFIXES so 'ship' is not appended.
	local apiData = { role = 'Light fighter' }
	local desc = Ship.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'RSI' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('RSI light fighter', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role, no size, no crew → manufacturer + typeNoun only.
	local apiData = {}
	local desc = Ship.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'RSI' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('RSI ship', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'exploration' not in ROLE_SUFFIXES → appends 'ship'.
	local apiData = { role = 'Exploration' }
	local desc = Ship.getShortDescription({ apiData = apiData, args = {}, typeInfo = {}, prefix = nil, resolved = {} })
	self:assertEquals('Exploration ship', desc)
end

function suite:testShortDescriptionMultiRole()
	-- Array role: joined with ' / '; not a role suffix → appends 'ship'.
	local apiData = { role = { 'Combat', 'Exploration' } }
	local desc = Ship.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'RSI' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('RSI combat / exploration ship', desc)
end

function suite:testFamilyTag()
	self:assertEquals('ship', Ship.family)
end

function suite:testPledgeCategory()
	local cats = Ship.getCategories(ctx({ msrp = 100 }, {}, {}))
	self:assertEquals('Pledge ships', cats[#cats])
	self:assertEquals(0, #Ship.getCategories(ctx({}, {}, {})))
end

return suite
