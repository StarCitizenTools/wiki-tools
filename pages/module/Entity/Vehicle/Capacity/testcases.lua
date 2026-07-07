require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Capacity = require('Module:Entity/Vehicle/Capacity')
local Editorial = require('Module:Entity/Editorial')

local suite = ScribuntoUnit:new()

--- Build the capacity section for a fixture. An empty Editorial.view means
--- :value(field, fallback) returns the fallback, so build() reads apiData
--- directly (a page with no editorial args).
local function cap(apiData)
	return Capacity.build(apiData, {}, Editorial.view({}))
end

--- Find a subsection (tab) by label within section.sections.
local function tab(section, label)
	for _, sub in ipairs(section.sections or {}) do
		if sub.label == label then
			return sub
		end
	end
	return nil
end

--- Find a row by label within an items list.
local function row(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- Fixtures: only capacity-relevant fields, cut from the real API records.
local CARRACK = {
	crew = { min = 6, max = 12 },
	cargo_capacity = 456,
	vehicle_inventory = 11260000,
	cargo_limits = { min_scu_box = 1, max_scu_box = 16, max_size = { x = 2.5, y = 5, z = 2.5 } },
	seating = { crew_stations = 12, beds = 7, medical_beds = { T2 = 1 }, ejection_seats = 0 },
	weapon_storage = { slots_total = 40, slots_rifle = 16, slots_pistol = 24, lockers = 2 },
	max_medical_tier = 'T2',
	cargo_grids = { { scu = 400, external = false }, { scu = 56, external = false } },
}
local PROSPECTOR = {
	crew = { min = 1, max = 1 },
	cargo_capacity = 0,
	vehicle_inventory = 930000,
	ore_capacity = 32,
	seating = { crew_stations = 1, beds = 1, ejection_seats = 1 },
}
local FIGHTER = {
	crew = { min = 1, max = 1 },
	cargo_capacity = 24,
	vehicle_inventory = 620000,
	seating = { crew_stations = 1 },
}

-- Flat fallback (moved from Vehicle/testcases.lua) --------------------------

function suite:testCrewRangeAndCargoFlat()
	local s = cap({ crew = { min = 1, max = 3 }, cargo_capacity = 96 })
	self:assertEquals(nil, s.sections)
	self:assertEquals('1\226\128\1473', row(s.items, 'Crew').content)
	self:assertEquals('96 SCU', row(s.items, 'Cargo').content)
end

function suite:testInventoryFlat()
	local s = cap({ vehicle_inventory = 1620000 })
	self:assertEquals(nil, s.sections)
	self:assertEquals('1,620,000 µSCU', row(s.items, 'Inventory').content)
end

function suite:testPlainFighterRendersFlat()
	local s = cap(FIGHTER)
	self:assertEquals(nil, s.sections)
	self:assertTrue(s.items ~= nil)
	self:assertEquals('24 SCU', row(s.items, 'Cargo').content)
end

function suite:testEmptyApiReturnsNil()
	self:assertEquals(nil, cap({}))
end

function suite:testFlatDropsZeroCargo()
	-- A plain ship whose cargo is 0 (nothing rich) renders flat with no misleading
	-- "0 SCU" Cargo row.
	local s = cap({ crew = { min = 1, max = 1 }, cargo_capacity = 0, vehicle_inventory = 500000 })
	self:assertEquals(nil, s.sections)
	self:assertEquals(nil, row(s.items, 'Cargo'))
	self:assertEquals('500,000 µSCU', row(s.items, 'Inventory').content)
end

function suite:testLoneTabFallsBackToFlat()
	-- Degenerate data: only beds present (no crew/cargo/inventory/ore/medical), so
	-- the Overview is empty and only the Crew detail is rich. A single tab would be
	-- a lone tab strip; render the rows flat instead.
	local s = cap({ seating = { beds = 3 } })
	self:assertEquals(nil, s.sections)
	self:assertTrue(s.items ~= nil)
	self:assertEquals('3', row(s.items, 'Beds').content)
end

-- Tabbing + Overview -------------------------------------------------------

function suite:testCarrackIsTabbed()
	local s = cap(CARRACK)
	self:assertTrue(s.sections ~= nil)
	self:assertTrue(tab(s, 'Overview') ~= nil)
	self:assertTrue(tab(s, 'Cargo') ~= nil)
	self:assertTrue(tab(s, 'Crew') ~= nil)
end

function suite:testCarrackOverviewHeadline()
	local ov = tab(cap(CARRACK), 'Overview')
	self:assertEquals('6\226\128\14712', row(ov.items, 'Crew').content)
	self:assertEquals('456 SCU', row(ov.items, 'Cargo').content)
	self:assertEquals('11,260,000 µSCU', row(ov.items, 'Inventory').content)
	self:assertEquals('T2', row(ov.items, 'Max medical').content)
	self:assertEquals(nil, row(ov.items, 'Ejection seat'))
	self:assertEquals(nil, row(ov.items, 'Escape pod'))
end

function suite:testCarrackCargoTab()
	local c = tab(cap(CARRACK), 'Cargo')
	self:assertEquals('456 SCU', row(c.items, 'Internal cargo').content) -- all grids internal
	self:assertEquals(nil, row(c.items, 'External cargo'))
	self:assertEquals('16 SCU', row(c.items, 'Max container').content)
	self:assertEquals(nil, row(c.items, 'Smallest container'))
	self:assertEquals(nil, row(c.items, 'Max box size'))
end

function suite:testCargoInternalExternalSplit()
	-- Both internal and external grids (e.g. Ironclad): each total is summed from
	-- cargo_grids and shown on its own row. The unified total lives on Overview.
	local s = cap({
		cargo_capacity = 2200,
		cargo_limits = { max_scu_box = 32 },
		cargo_grids = {
			{ scu = 720, external = true },
			{ scu = 720, external = true },
			{ scu = 720, external = true },
			{ scu = 40, external = false },
		},
	})
	local c = tab(s, 'Cargo')
	self:assertEquals('2,160 SCU', row(c.items, 'External cargo').content)
	self:assertEquals('40 SCU', row(c.items, 'Internal cargo').content)
end

function suite:testCargoExternalOnly()
	-- All-external hauler (e.g. Caterpillar): only the External cargo row shows.
	local s = cap({
		cargo_capacity = 576,
		cargo_limits = { max_scu_box = 32 },
		cargo_grids = { { scu = 288, external = true }, { scu = 288, external = true } },
	})
	local c = tab(s, 'Cargo')
	self:assertEquals('576 SCU', row(c.items, 'External cargo').content)
	self:assertEquals(nil, row(c.items, 'Internal cargo'))
end

function suite:testCargoNullGridsCountAsInternal()
	-- external=nil grids (e.g. the 890 Jump's main bay) count as internal.
	local s = cap({
		cargo_capacity = 388,
		cargo_limits = { max_scu_box = 16 },
		cargo_grids = { { scu = 100, external = false }, { scu = 288 } },
	})
	local c = tab(s, 'Cargo')
	self:assertEquals('388 SCU', row(c.items, 'Internal cargo').content)
	self:assertEquals(nil, row(c.items, 'External cargo'))
end

function suite:testCarrackCrewTab()
	local c = tab(cap(CARRACK), 'Crew')
	self:assertEquals('12', row(c.items, 'Stations').content)
	self:assertEquals('7', row(c.items, 'Beds').content)
	self:assertEquals('1 \195\151 T2', row(c.items, 'Medical bed').content)
	self:assertEquals('16 rifle<br>24 pistol', row(c.items, 'Weapon racks').content)
	self:assertEquals(nil, row(c.items, 'Ejection seats')) -- gated off (EGRESS_ENABLED)
end

function suite:testProspectorMinerTabs()
	local s = cap(PROSPECTOR)
	self:assertTrue(s.sections ~= nil)
	local ov = tab(s, 'Overview')
	self:assertEquals(nil, row(ov.items, 'Cargo')) -- 0 SCU drops
	self:assertEquals('32 SCU', row(ov.items, 'Ore').content)
	self:assertEquals(nil, row(ov.items, 'Max medical')) -- no max_medical_tier
	self:assertEquals(nil, row(ov.items, 'Ejection seat')) -- egress row gated off (EGRESS_ENABLED)
	local c = tab(s, 'Cargo')
	self:assertTrue(c ~= nil)
	self:assertEquals('32 SCU', row(c.items, 'Ore hold').content)
	self:assertEquals(nil, row(c.items, 'Cargo capacity'))
	self:assertEquals(nil, row(tab(s, 'Crew').items, 'Ejection seats')) -- egress gated off
end

function suite:testMedicalTierMultipleAscending()
	local s = cap({ crew = { min = 1, max = 2 }, seating = { medical_beds = { T2 = 1, T1 = 2 } } })
	self:assertEquals('2 \195\151 T1, 1 \195\151 T2', row(tab(s, 'Crew').items, 'Medical bed').content)
end

function suite:testCrewStationsAloneTriggersCrewTab()
	-- crew_stations (5) > crew max (2) is the ONLY rich signal: no beds, medical,
	-- pods, jump seats, weapon racks, cargo limits or ore. It must still tab.
	local s = cap({ crew = { min = 1, max = 2 }, cargo_capacity = 50, seating = { crew_stations = 5 } })
	self:assertTrue(s.sections ~= nil)
	self:assertTrue(tab(s, 'Crew') ~= nil)
	self:assertEquals(nil, tab(s, 'Cargo')) -- no cargo-rich signal
	self:assertEquals('5', row(tab(s, 'Crew').items, 'Stations').content)
end

-- Egress rendering is gated off (EGRESS_ENABLED = false) while the API's
-- ejection/escape data is unreliable: neither row renders even when the ship has
-- an ejection seat or escape pods. The ejection-vs-escape-pod determination logic
-- is retained in the module for an easy re-enable.
function suite:testEgressRowGatedOff()
	local ejectionShip = cap({
		crew = { min = 1, max = 1 },
		seating = { crew_stations = 1, beds = 1, ejection_seats = 1 },
	})
	local escapeShip = cap({
		crew = { min = 2, max = 4 },
		seating = { crew_stations = 4, beds = 3, escape_pods = 2 },
	})
	self:assertEquals(nil, row(tab(ejectionShip, 'Overview').items, 'Ejection seat'))
	self:assertEquals(nil, row(tab(escapeShip, 'Overview').items, 'Escape pod'))
	-- The Crew-tab count rows are gated off too.
	self:assertEquals(nil, row(tab(ejectionShip, 'Crew').items, 'Ejection seats'))
	self:assertEquals(nil, row(tab(escapeShip, 'Crew').items, 'Escape pods'))
end

function suite:testCargoTabMaxContainer()
	-- max_scu_box is the rich signal that triggers the Cargo tab; the removed
	-- Smallest container / Max box size rows never come back.
	local s = cap({ cargo_capacity = 100, cargo_limits = { max_scu_box = 4, max_size = { x = 2, y = 3 } } })
	local c = tab(s, 'Cargo')
	self:assertTrue(c ~= nil)
	self:assertEquals('4 SCU', row(c.items, 'Max container').content)
	self:assertEquals(nil, row(c.items, 'Smallest container'))
	self:assertEquals(nil, row(c.items, 'Max box size'))
end

return suite
