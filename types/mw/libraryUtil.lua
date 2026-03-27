--- Scribunto libraryUtil (REL1_43)
--- @meta

--- @class libraryUtil
local libraryUtil = {}

--- Validates an argument's type. Errors on mismatch.
--- @param name string Function name for error messages.
--- @param argIdx number Argument position.
--- @param arg any The argument to validate.
--- @param expectType string Expected type name.
--- @param nilOk boolean|nil If true, nil is accepted.
function libraryUtil.checkType(name, argIdx, arg, expectType, nilOk) end

--- Validates an argument against multiple allowed types. Errors on mismatch.
--- @param name string Function name for error messages.
--- @param argIdx number Argument position.
--- @param arg any The argument to validate.
--- @param expectTypes string[] Allowed type names.
function libraryUtil.checkTypeMulti(name, argIdx, arg, expectTypes) end

--- Validates a value's type for a named index. Errors on mismatch.
--- @param index string Index name for error messages.
--- @param value any The value to validate.
--- @param expectType string Expected type name.
function libraryUtil.checkTypeForIndex(index, value, expectType) end

--- Validates a named argument's type. Errors on mismatch.
--- @param name string Function name for error messages.
--- @param argName string Argument name.
--- @param arg any The argument to validate.
--- @param expectType string Expected type name.
--- @param nilOk boolean|nil If true, nil is accepted.
function libraryUtil.checkTypeForNamedArg(name, argName, arg, expectType, nilOk) end

--- Creates a function that checks self is the expected object (catches dot-vs-colon mistakes).
--- @param libraryName string
--- @param varName string
--- @param selfObj table
--- @param selfObjDesc string
--- @return fun(self: table, method: string)
function libraryUtil.makeCheckSelfFunction(libraryName, varName, selfObj, selfObjDesc) end

return libraryUtil
