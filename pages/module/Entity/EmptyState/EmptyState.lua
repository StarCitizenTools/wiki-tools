require('strict')

--- @module Entity/EmptyState
--- What an Entity section shows when it has nothing to draw: `none` when the
--- data says the list is empty, `failed` when the data did not load. Both are
--- Module:Mbox boxes.

local mbox = require('Module:Mbox')

local p = {}

local FAILED_ICON = 'WikimediaUI-Alert.svg'

--- @param message string e.g. 'No ports.'
--- @return string
function p.none(message)
	return mbox.render({ title = message, placeholder = true })
end

--- @param message string e.g. "Couldn't load ports."
--- @return string
function p.failed(message)
	return mbox.render({ title = message, type = 'warning', icon = FAILED_ICON })
end

return p
