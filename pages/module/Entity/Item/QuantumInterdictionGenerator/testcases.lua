require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local QIG = require('Module:Entity/Item/QuantumInterdictionGenerator')
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

-- A QED: snare (radius > 1) + dampener (jamming range).
function suite:testQedRows()
	local sections = QIG.getSections({
		quantum_interdiction_generator = {
			jamming = { range = 12000 },
			pulse = { radius = 20000, charge_time = 90, discharge_time = 30, cooldown_time = 1 },
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('quantum_interdiction_generator', sections[1].key)
	self:assertEquals('Snare + dampener (QED)', findItem(sections[1].items, 'Mode').content)
	self:assertEquals('20,000 m', findItem(sections[1].items, 'Snare range').content)
	self:assertEquals('12,000 m', findItem(sections[1].items, 'Dampener range').content)
	self:assertEquals('90 s', findItem(sections[1].items, 'Charge time').content)
	self:assertEquals('30 s', findItem(sections[1].items, 'Duration').content)
	self:assertEquals('1 s', findItem(sections[1].items, 'Cooldown').content)
end

-- A QDMP: dampener only (snare radius is the placeholder 1).
function suite:testQdmpHasNoSnareRange()
	local sections = QIG.getSections({
		quantum_interdiction_generator = {
			jamming = { range = 4000 },
			pulse = { radius = 1, charge_time = 90, discharge_time = 30, cooldown_time = 1 },
		},
	}, {})
	self:assertEquals('Dampener (QDMP)', findItem(sections[1].items, 'Mode').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Snare range'))
	self:assertEquals('4,000 m', findItem(sections[1].items, 'Dampener range').content)
end

function suite:testDeviceClass()
	self:assertEquals('QED', QIG._internal.deviceClass(true, true))
	self:assertEquals('QDMP', QIG._internal.deviceClass(false, true))
	self:assertEquals('QID', QIG._internal.deviceClass(true, false))
	self:assertEquals(nil, QIG._internal.deviceClass(false, false))
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #QIG.getSections({}, {}))
end

function suite:testStructuredData()
	local data = QIG.getStructuredData({
		quantum_interdiction_generator = {
			jamming = { range = 12000 },
			pulse = { radius = 20000, charge_time = 90, discharge_time = 30, cooldown_time = 1 },
		},
	})
	self:assertEquals('QED', data.qig_mode)
	self:assertEquals(20000, data.qig_snare_range)
	self:assertEquals(12000, data.qig_dampener_range)
	self:assertEquals(90, data.qig_charge_time)
end

function suite:testResolveSubtype()
	self:assertEquals(QIG, Item.resolveSubtype({ type = 'QuantumInterdictionGenerator' }))
end

-- Short description surfaces the subdivision (QED / QDMP / QID), like a gun's
-- specific weapon type, not the umbrella "quantum interdiction generator".
function suite:testShortDescriptionQdmp()
	local desc = QIG.getShortDescription({
		size = 3,
		class = 'Military',
		grade = 'A',
		quantum_interdiction_generator = { jamming = { range = 4500 }, pulse = { radius = 1 } },
	}, { manufacturer = 'Wei-Tek' }, { name = 'Quantum interdiction generator' })
	self:assertEquals('S3 Gr. A military quantum dampener by Wei-Tek', desc)
end

function suite:testShortDescriptionQed()
	local desc = QIG.getShortDescription({
		size = 1,
		class = 'Military',
		grade = 'A',
		quantum_interdiction_generator = { jamming = { range = 12000 }, pulse = { radius = 20000 } },
	}, { manufacturer = 'Wei-Tek' }, { name = 'Quantum interdiction generator' })
	self:assertEquals('S1 Gr. A military quantum enforcement device by Wei-Tek', desc)
end

return suite
