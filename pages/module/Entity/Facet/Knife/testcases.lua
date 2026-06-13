require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Knife = require('Module:Entity/Facet/Knife')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- The FSK-8: 30 damage on both slash and stab, takedown-capable.
local function knifeData()
	return {
		melee_weapon = {
			can_be_used_for_take_down = 1,
			can_block = 1,
			attack_modes = {
				{ category = 'BladeSlash', damage = 30 },
				{ category = 'BladeStab', damage = 30 },
			},
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Knife.matches(knifeData()))
	-- Falls back to the identical `knife` block when melee_weapon is absent.
	self:assertEquals(true, Knife.matches({ knife = { attack_modes = {} } }))
	self:assertEquals(false, Knife.matches({}))
	self:assertEquals(false, Knife.matches(nil))
end

function suite:testCollapsesEqualDamage()
	local sections = Knife.getSections(knifeData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('melee', sections[1].key)
	self:assertEquals('Melee', sections[1].label)
	self:assertEquals('30', findItem(sections[1].items, 'Damage').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Slash damage'))
	self:assertEquals('Yes', findItem(sections[1].items, 'Takedown').content)
end

function suite:testSeparateWhenDamageDiffers()
	local sections = Knife.getSections({
		melee_weapon = {
			attack_modes = {
				{ category = 'BladeSlash', damage = 25 },
				{ category = 'BladeStab', damage = 40 },
			},
		},
	}, {})
	self:assertEquals('25', findItem(sections[1].items, 'Slash damage').content)
	self:assertEquals('40', findItem(sections[1].items, 'Stab damage').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Knife.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Knife.getStructuredData(knifeData())
	self:assertEquals(30, data.slash_damage)
	self:assertEquals(30, data.stab_damage)
end

return suite
