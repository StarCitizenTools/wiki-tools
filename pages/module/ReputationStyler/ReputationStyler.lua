require('strict')

local IconText = require('Module:IconText')

local ReputationStyler = {}

local DEFS = mw.loadJsonData('Module:ReputationStyler/config.json')

function ReputationStyler.getIcon(rank, scope)
	if rank and scope and DEFS.mapping[scope] and DEFS.mapping[scope].ranks[rank] then
		return DEFS.icon_sets[DEFS.mapping[scope].icon_set][DEFS.mapping[scope].ranks[rank]]
	end
	return nil
end

function ReputationStyler.style(rank, scope)
	if not rank or rank == '' then
		return 'Unspecified'
	end
	if scope then
		local icon = ReputationStyler.getIcon(rank, scope)
		if icon then
			local root = mw.html.create('span'):addClass('t-reputation-styler__container')

			root:wikitext(IconText._main({
				icon = icon,
				text = rank,
				mask = true,
			}))

			local styles = mw.getCurrentFrame():extensionTag({
				name = 'templatestyles',
				args = { src = 'Module:ReputationStyler/styles.css' },
			})

			return styles .. tostring(root)
		end
	end
	return rank
end

--- @param frame table https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#Frame_object
function ReputationStyler.main(frame)
	local args = require('Module:Arguments').getArgs(frame)

	return ReputationStyler.style(args.rank, args.scope)
end

return ReputationStyler
