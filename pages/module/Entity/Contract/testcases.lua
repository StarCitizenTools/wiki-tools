require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Contract = require('Module:Entity/Contract')

local suite = ScribuntoUnit:new()

local function hasError(errors, substr)
	for _, e in ipairs(errors) do
		if e:find(substr, 1, true) then
			return true
		end
	end
	return false
end

function suite:testValidKindPasses()
	local kind = { matches = function() end, getApiConfigs = function() end }
	local ok, errors = Contract.validate(kind, Contract.KIND)
	self:assertTrue(ok)
	self:assertEquals(0, #errors)
end

function suite:testKindMissingRequiredFails()
	local kind = { matches = function() end }
	local ok, errors = Contract.validate(kind, Contract.KIND)
	self:assertFalse(ok)
	self:assertTrue(hasError(errors, 'getApiConfigs'))
end

function suite:testNonFunctionHookFails()
	local kind = { matches = function() end, getApiConfigs = 'nope' }
	local ok, errors = Contract.validate(kind, Contract.KIND)
	self:assertFalse(ok)
	self:assertTrue(hasError(errors, 'getApiConfigs'))
end

function suite:testOptionalHookAbsentPasses()
	local kind = { matches = function() end, getApiConfigs = function() end }
	self:assertTrue((Contract.validate(kind, Contract.KIND)))
end

function suite:testValidFacetPasses()
	local facet = { matches = function() end, getSections = function() end }
	self:assertTrue((Contract.validate(facet, Contract.FACET)))
end

function suite:testFacetMissingGetSectionsFails()
	local facet = { matches = function() end }
	local ok, errors = Contract.validate(facet, Contract.FACET)
	self:assertFalse(ok)
	self:assertTrue(hasError(errors, 'getSections'))
end

function suite:testNonTableComponentFails()
	local ok, errors = Contract.validate(nil, Contract.KIND)
	self:assertFalse(ok)
	self:assertEquals(1, #errors)
end

function suite:testValidateFieldsRequiredPresent()
	self:assertTrue((Contract.validateFields({ name = 'Vehicle' }, Contract.KIND_FIELDS)))
end

function suite:testValidateFieldsMissingRequiredFails()
	local ok, errors = Contract.validateFields({}, Contract.KIND_FIELDS)
	self:assertFalse(ok)
	self:assertTrue(hasError(errors, 'name'))
end

function suite:testValidateFieldsWrongTypeFails()
	local ok, errors = Contract.validateFields({ name = 'V', editorialMode = 'yes' }, Contract.KIND_FIELDS)
	self:assertFalse(ok)
	self:assertTrue(hasError(errors, 'editorialMode'))
end

function suite:testValidateFieldsOptionalAbsentPasses()
	self:assertTrue((Contract.validateFields({ name = 'V' }, Contract.KIND_FIELDS)))
end

function suite:testValidateFieldsNonTableFails()
	local ok, errors = Contract.validateFields(nil, Contract.KIND_FIELDS)
	self:assertFalse(ok)
	self:assertEquals(1, #errors)
end

return suite
