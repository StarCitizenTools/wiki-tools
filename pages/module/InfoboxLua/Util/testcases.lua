require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local util = require('Module:InfoboxLua/Util')

-- isNonEmptyString

function suite:testIsNonEmptyStringWithString()
	self:assertTrue(util.isNonEmptyString('hello'))
end

function suite:testIsNonEmptyStringWithEmptyString()
	self:assertFalse(util.isNonEmptyString(''))
end

function suite:testIsNonEmptyStringWithNil()
	self:assertFalse(util.isNonEmptyString(nil))
end

function suite:testIsNonEmptyStringWithNumber()
	self:assertFalse(util.isNonEmptyString(42))
end

function suite:testIsNonEmptyStringWithTable()
	self:assertFalse(util.isNonEmptyString({}))
end

-- isNonEmptyTable

function suite:testIsNonEmptyTableWithItems()
	self:assertTrue(util.isNonEmptyTable({ 'a', 'b' }))
end

function suite:testIsNonEmptyTableWithEmptyTable()
	self:assertFalse(util.isNonEmptyTable({}))
end

function suite:testIsNonEmptyTableWithNil()
	self:assertFalse(util.isNonEmptyTable(nil))
end

function suite:testIsNonEmptyTableWithString()
	self:assertFalse(util.isNonEmptyTable('hello'))
end

function suite:testIsNonEmptyTableWithKeyedTable()
	self:assertTrue(util.isNonEmptyTable({ key = 'value' }))
end

-- validateAndConstruct: valid data

function suite:testValidateRequiredFieldPresent()
	local schema = {
		name = { type = 'string', required = true },
	}
	local result = util.validateAndConstruct({ name = 'test' }, schema)
	self:assertEquals('test', result.name)
end

function suite:testValidateOptionalFieldMissing()
	local schema = {
		name = { type = 'string', required = true },
		label = { type = 'string', required = false },
	}
	local result = util.validateAndConstruct({ name = 'test' }, schema)
	self:assertEquals('test', result.name)
	self:assertEquals(nil, result.label)
end

function suite:testValidateDefaultApplied()
	local schema = {
		size = { type = 'number', required = false, default = 400 },
	}
	local result = util.validateAndConstruct({}, schema)
	self:assertEquals(400, result.size)
end

function suite:testValidateDefaultOverridden()
	local schema = {
		size = { type = 'number', required = false, default = 400 },
	}
	local result = util.validateAndConstruct({ size = 200 }, schema)
	self:assertEquals(200, result.size)
end

-- validateAndConstruct: errors

function suite:testValidateRequiredFieldMissing()
	local schema = {
		name = { type = 'string', required = true },
	}
	self:assertThrows(function()
		util.validateAndConstruct({}, schema)
	end, 'Input data missing required key: name')
end

function suite:testValidateExtraneousKey()
	local schema = {
		name = { type = 'string', required = true },
	}
	self:assertThrows(function()
		util.validateAndConstruct({ name = 'test', extra = 'bad' }, schema)
	end, 'Input data contains extraneous key not defined in schema: extra')
end

return suite
