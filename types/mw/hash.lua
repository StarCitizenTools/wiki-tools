--- Scribunto mw.hash (REL1_43)
--- @meta

--- @class mw.hash
local hash = {}

--- Returns a list of available hash algorithm names.
--- @return string[]
function hash.listAlgorithms() end

--- Hashes a value with the given algorithm.
--- @param algo string
--- @param value string
--- @return string Hex-encoded hash.
function hash.hashValue(algo, value) end
