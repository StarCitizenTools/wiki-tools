require('strict')

--- @module Entity/Location/JumpPoint
--- PLACEHOLDER — Task 3 of the 2026-08-17 jump-point plan replaces this file
--- with the real leaf (sections, structured data, short description, footer
--- buttons, metadata). It exists now only because Location.resolveSubtype
--- requires its leaf eagerly (via Module:Entity/SubtypeResolver) and the
--- resolved leaf IS the admission token for the declared-kind validity gate in
--- Module:Entity/Data; a missing module would error that gate. Deliberately
--- hook-free: the Entity chain treats every lifecycle hook as optional, so an
--- empty link renders parent-only until Task 3 fills it.

local p = {}

--- @type string
p.parent = 'Entity/Location'

return p
