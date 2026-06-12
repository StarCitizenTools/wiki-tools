require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local JumpModule = require('Module:Entity/Item/JumpModule')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

function suite:testJumpStatsRows()
	local sections = JumpModule.getSections({
		jump_drive = { alignment_rate = 0.2, tuning_rate = 0.22, fuel_usage_efficiency_multiplier = 1.5 },
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('jump_module', sections[1].key)
	self:assertEquals('0.2', findItem(sections[1].items, 'Alignment rate').content)
	self:assertEquals('0.22', findItem(sections[1].items, 'Tuning rate').content)
	self:assertEquals('1.5×', findItem(sections[1].items, 'Fuel usage multiplier').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #JumpModule.getSections({}, {}))
end

function suite:testStructuredData()
	local data = JumpModule.getStructuredData({
		jump_drive = { alignment_rate = 0.2, tuning_rate = 0.26, fuel_usage_efficiency_multiplier = 8 },
	})
	self:assertEquals(0.2, data.jump_alignment_rate)
	self:assertEquals(0.26, data.jump_tuning_rate)
	self:assertEquals(8, data.jump_fuel_usage_multiplier)
end

function suite:testResolveSubtypeReturnsJumpModule()
	-- API type for jump modules is "JumpDrive".
	self:assertEquals(JumpModule, Item.resolveSubtype({ type = 'JumpDrive' }))
end

return suite
