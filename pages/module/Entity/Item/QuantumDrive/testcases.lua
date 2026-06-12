require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local QuantumDrive = require('Module:Entity/Item/QuantumDrive')
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

function suite:testQuantumStatsRows()
	local sections = QuantumDrive.getSections({
		quantum_drive = {
			quantum_fuel_requirement = 0.007546,
			standard_jump = {
				drive_speed = 231000000,
				drive_speed_formatted = '231 Mm/s',
				spool_up_time = 4,
				cooldown_time = 8.7,
			},
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('quantum_drive', sections[1].key)
	self:assertEquals('231 Mm/s', findItem(sections[1].items, 'Quantum speed').content)
	self:assertEquals('4 s', findItem(sections[1].items, 'Spool time').content)
	self:assertEquals('8.7 s', findItem(sections[1].items, 'Cooldown').content)
end

function suite:testSpeedFallbackToMmPerSecond()
	-- No preformatted string: raw m/s drive_speed is converted to Mm/s.
	local sections = QuantumDrive.getSections({
		quantum_drive = { standard_jump = { drive_speed = 150000000 } },
	}, {})
	self:assertEquals('150 Mm/s', findItem(sections[1].items, 'Quantum speed').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #QuantumDrive.getSections({}, {}))
end

function suite:testStructuredData()
	local data = QuantumDrive.getStructuredData({
		quantum_drive = {
			quantum_fuel_requirement = 0.007546,
			standard_jump = { drive_speed = 231000000, spool_up_time = 4, cooldown_time = 8.7 },
		},
	})
	-- Speed stored in Mm/s.
	self:assertEquals(231, data.quantum_speed)
	self:assertEquals(4, data.quantum_spool_time)
	self:assertEquals(8.7, data.quantum_cooldown)
	self:assertEquals(0.007546, data.quantum_fuel_requirement)
end

function suite:testResolveSubtypeReturnsQuantumDrive()
	self:assertEquals(QuantumDrive, Item.resolveSubtype({ type = 'QuantumDrive' }))
end

return suite
