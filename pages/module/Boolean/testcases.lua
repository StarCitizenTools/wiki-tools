require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Boolean = require('Module:Boolean')

local suite = ScribuntoUnit:new()

-- classify: tri-state core

function suite:testClassifyTrue()
	local s = Boolean.classify(true)
	self:assertEquals('yes', s.state)
	self:assertEquals('CdxIconSuccess.svg', s.icon)
	self:assertEquals('Yes', s.label)
end

function suite:testClassifyFalse()
	local s = Boolean.classify(false)
	self:assertEquals('no', s.state)
	self:assertEquals('CdxIconClear.svg', s.icon)
	self:assertEquals('No', s.label)
end

function suite:testClassifyNilIsUnknown()
	local s = Boolean.classify(nil)
	self:assertEquals('unknown', s.state)
	self:assertEquals('CdxIconHelpNotice.svg', s.icon)
	self:assertEquals('Unknown', s.label)
end

function suite:testClassifyUnrecognizedIsUnknown()
	self:assertEquals('unknown', Boolean.classify('maybe').state)
end

-- classify: string / numeric variants normalise through Yesno

function suite:testClassifyStringVariants()
	self:assertEquals('yes', Boolean.classify('yes').state)
	self:assertEquals('yes', Boolean.classify('true').state)
	self:assertEquals('yes', Boolean.classify('1').state)
	self:assertEquals('no', Boolean.classify('no').state)
	self:assertEquals('no', Boolean.classify('false').state)
	self:assertEquals('no', Boolean.classify('0').state)
end

-- gridClassify: cell fields for the AG Grid boolean kind

function suite:testGridClassifyTrue()
	local b = Boolean.gridClassify(true)
	self:assertEquals('Yes', b.text)
	self:assertEquals('yes', b.state)
	self:assertEquals('CdxIconSuccess.svg', b.icon)
end

function suite:testGridClassifyFalse()
	local b = Boolean.gridClassify('no')
	self:assertEquals('No', b.text)
	self:assertEquals('no', b.state)
	self:assertEquals('CdxIconClear.svg', b.icon)
end

function suite:testGridClassifyUnknown()
	local b = Boolean.gridClassify(nil)
	self:assertEquals('Unknown', b.text)
	self:assertEquals('unknown', b.state)
end

return suite
