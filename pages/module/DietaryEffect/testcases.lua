require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local DietaryEffect = require('Module:DietaryEffect')

local suite = ScribuntoUnit:new()

-- classify: polarity

function suite:testClassifyPositive()
	local e = DietaryEffect.classify('Energizing')
	self:assertEquals('positive', e.polarity)
	self:assertEquals('Energizing', e.page)
	self:assertEquals('Energizing', e.label)
end

function suite:testClassifyNegative()
	self:assertEquals('negative', DietaryEffect.classify('Toxic').polarity)
end

-- classify: value -> canonical page when they differ

function suite:testClassifyMapsToCanonicalPage()
	self:assertEquals('Cognitive boosting', DietaryEffect.classify('Cognitive Boosting').page)
	self:assertEquals('Cognitive impairing', DietaryEffect.classify('Cognitive Impairment').page)
	self:assertEquals('Immune boosting', DietaryEffect.classify('Immune Boosting').page)
end

-- classify: Healing links to the dietary-effect page, not the Medical redirect

function suite:testClassifyHealingPage()
	local e = DietaryEffect.classify('Healing')
	self:assertEquals('Healing (dietary effect)', e.page)
	self:assertEquals('positive', e.polarity)
end

-- classify: spelling variants collapse to one entry, with correct (and distinct) pages

function suite:testClassifyHyperMetabolicVariants()
	self:assertEquals('Hyper-metabolic', DietaryEffect.classify('Hyper-Metabolic').page)
	self:assertEquals('Hyper-metabolic', DietaryEffect.classify('Hypermetabolic').page)
	self:assertEquals('negative', DietaryEffect.classify('Hypermetabolic').polarity)
end

function suite:testClassifyHypoMetabolicVariants()
	self:assertEquals('Hypo-metabolic', DietaryEffect.classify('Hypo-Metabolic').page)
	self:assertEquals('Hypo-metabolic', DietaryEffect.classify('Hypometabolic').page)
	self:assertEquals('positive', DietaryEffect.classify('Hypometabolic').polarity)
end

-- classify: canonical label regardless of which spelling the API sent

function suite:testClassifyCanonicalLabel()
	self:assertEquals('Hyper-Metabolic', DietaryEffect.classify('Hypermetabolic').label)
	self:assertEquals('Hypo-Metabolic', DietaryEffect.classify('Hypometabolic').label)
end

-- classify: None is neutral and unlinked

function suite:testClassifyNone()
	local e = DietaryEffect.classify('None')
	self:assertEquals('neutral', e.polarity)
	self:assertEquals(nil, e.page)
	self:assertEquals('None', e.label)
end

-- classify: unknown effect returns nil

function suite:testClassifyUnknown()
	self:assertEquals(nil, DietaryEffect.classify('Fabricated Effect'))
end

-- classify: lookup is case- and separator-insensitive

function suite:testClassifyNormalizesInput()
	self:assertEquals('positive', DietaryEffect.classify('energizing').polarity)
	self:assertEquals('positive', DietaryEffect.classify('  Energizing  ').polarity)
end

-- gridClassify: per-effect value for an AG Grid badge cell

function suite:testGridClassifyPositive()
	local b = DietaryEffect.gridClassify('Energizing')
	self:assertEquals('Energizing', b.text)
	self:assertEquals('success', b.variant)
	self:assertEquals('CdxIconArrowUp.svg', b.icon)
	self:assertEquals('Energizing', b.href)
end

function suite:testGridClassifyNegative()
	local b = DietaryEffect.gridClassify('Toxic')
	self:assertEquals('error', b.variant)
	self:assertEquals('CdxIconArrowDown.svg', b.icon)
	self:assertEquals('Toxic', b.href)
end

function suite:testGridClassifyCanonicalPageAndLabel()
	local b = DietaryEffect.gridClassify('Hypermetabolic')
	self:assertEquals('Hyper-Metabolic', b.text)
	self:assertEquals('Hyper-metabolic', b.href)
	self:assertEquals('error', b.variant)
end

function suite:testGridClassifyHealingPage()
	self:assertEquals('Healing (dietary effect)', DietaryEffect.gridClassify('Healing').href)
end

function suite:testGridClassifyNoneNeutralUnlinked()
	local b = DietaryEffect.gridClassify('None')
	self:assertEquals('None', b.text)
	self:assertEquals(nil, b.variant)
	self:assertEquals(nil, b.icon)
	self:assertEquals(nil, b.href)
end

function suite:testGridClassifyUnknownLinksToOwnName()
	local b = DietaryEffect.gridClassify('Fabricated Effect')
	self:assertEquals('Fabricated Effect', b.text)
	self:assertEquals(nil, b.variant)
	self:assertEquals(nil, b.icon)
	self:assertEquals('Fabricated Effect', b.href)
end

return suite
