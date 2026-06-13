require('strict')

--- The keyed registry of column kinds. Adding a kind = one require line here +
--- one Module:AGGridColumns/Kind/X module satisfying Module:AGGridColumns/Contract +
--- one paired renderer in MediaWiki:Gadget-aggridRenderers.js (for scw* types).

return {
	image = require('Module:AGGridColumns/Kind/Image'),
	link = require('Module:AGGridColumns/Kind/Link'),
	linkList = require('Module:AGGridColumns/Kind/LinkList'),
	text = require('Module:AGGridColumns/Kind/Text'),
	smart = require('Module:AGGridColumns/Kind/Smart'),
	number = require('Module:AGGridColumns/Kind/Number'),
	card = require('Module:AGGridColumns/Kind/Card'),
	stackedValue = require('Module:AGGridColumns/Kind/StackedValue'),
	badge = require('Module:AGGridColumns/Kind/Badge'),
}
