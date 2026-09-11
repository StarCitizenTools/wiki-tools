require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Gravlev = require('Module:Entity/Vehicle/Gravlev')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

function suite:testTypeInfoName()
	local ti = Gravlev.getTypeInfo(ctx({ is_gravlev = true }, {}))
	self:assertEquals('Grav-lev vehicle', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = Gravlev.getTypeInfo(ctx({ is_gravlev = true }, {}))
	self:assertEquals('Grav-lev vehicles', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- DRAK resolves to short='Drake'; size is omitted for gravlevs.
	-- 'racing' not in ROLE_SUFFIXES → appends 'grav-lev vehicle'.
	local apiData = { role = 'Racing' }
	local desc = Gravlev.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'DRAK' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('Drake racing grav-lev vehicle', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role → manufacturer + typeNoun only.
	local apiData = {}
	local desc = Gravlev.getShortDescription({
		apiData = apiData,
		args = { manufacturer = 'DRAK' },
		typeInfo = {},
		prefix = nil,
		resolved = {},
	})
	self:assertEquals('Drake grav-lev vehicle', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'personal transport' not in ROLE_SUFFIXES → appends 'grav-lev vehicle'.
	local apiData = { role = 'Personal transport' }
	local desc =
		Gravlev.getShortDescription({ apiData = apiData, args = {}, typeInfo = {}, prefix = nil, resolved = {} })
	self:assertEquals('Personal transport grav-lev vehicle', desc)
end

function suite:testFamilyTag()
	self:assertEquals('gravlev', Gravlev.family)
end

function suite:testPledgeCategory()
	local cats = Gravlev.getCategories(ctx({ msrp = 100 }, {}, {}))
	self:assertEquals('Pledge vehicles', cats[#cats])
	self:assertEquals(0, #Gravlev.getCategories(ctx({}, {}, {})))
end

return suite
