require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local EMP = require('Module:Entity/Item/EMP')
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

function suite:testEmpStatsRows()
	local sections = EMP.getSections({
		emp = {
			emp_radius = 1100,
			distortion_damage = 3300,
			charge_duration = 22,
			unleash_duration = 1.5,
			cooldown_duration = 16,
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('emp', sections[1].key)
	self:assertEquals('1,100 m', findItem(sections[1].items, 'EMP radius').content)
	self:assertEquals('3,300', findItem(sections[1].items, 'Distortion damage').content)
	self:assertEquals('22 s', findItem(sections[1].items, 'Charge time').content)
	self:assertEquals('1.5 s', findItem(sections[1].items, 'Duration').content)
	self:assertEquals('16 s', findItem(sections[1].items, 'Cooldown').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #EMP.getSections({}, {}))
end

function suite:testStructuredData()
	local data = EMP.getStructuredData({
		emp = {
			emp_radius = 1100,
			distortion_damage = 3300,
			charge_duration = 22,
			unleash_duration = 1.5,
			cooldown_duration = 16,
		},
	})
	self:assertEquals(1100, data.emp_radius)
	self:assertEquals(3300, data.emp_distortion_damage)
	self:assertEquals(22, data.emp_charge_time)
	self:assertEquals(1.5, data.emp_duration)
	self:assertEquals(16, data.emp_cooldown)
end

function suite:testResolveSubtypeReturnsEmp()
	self:assertEquals(EMP, Item.resolveSubtype({ type = 'EMP' }))
end

return suite
