--!optimize 2
--!nonstrict

--[=[
	A standard library for debugging. Contains better `error`/`warn` functions,
	an implementation of `TableToString`, and a few more.

	@class Debug
]=]
local Debug = {}
local TAB = "\t"

type GenericDictionary = {[string]: any}
type GenericTable = {[any]: any}

local function GetService(serviceName: string)
	return game:GetService(serviceName)
end

local ServicesMetatable = {}
function ServicesMetatable:__index(index)
	local success, object = pcall(GetService, index)
	local service = success and object
	self[index] = service
	return service
end

local CachedServices = setmetatable({}, ServicesMetatable)
local Debug_Inspect: (...unknown) -> string

--@native
--[=[
	A fixed version of [Instance.GetFullName].

	@param object Instance
	@return string
]=]
function Debug.DirectoryToString(object: Instance): string
	local fullName = {}
	local count = 0

	while object.Parent ~= game and object.Parent ~= nil do
		local objectName = string.gsub(object.Name, "([\\\"])", "\\%1")

		if string.find(objectName, "^[_%a][_%w]*$") then
			fullName[count] = "." .. objectName
		else
			fullName[count] = "[\"" .. objectName .. "\"]"
		end

		count -= 1
		object = object.Parent
	end

	if CachedServices[object.ClassName] == object then
		fullName[count] = "game:GetService(\"" .. object.ClassName .. "\")"
	else
		fullName[count] = "." .. "[\"" .. object.Name .. "\"]" -- A dot at the beginning indicates a rootless Object
	end

	return table.concat(fullName, "", count, 0)
end

local REPLACERS = {
	["Index ?"] = "__index";
	["Newindex ?"] = "__newindex";
}

local function GetErrorData(formatString: string, ...) -- Make sure if you don't intend to format arguments in, you do %%f instead of %f
	if type(formatString) ~= "string" then
		error(GetErrorData("!The first parameter of error formatting must be a string", "Debug"))
	end

	local arguments = {...}
	local traceback = debug.traceback()
	local errorDepth = select(2, string.gsub(traceback, "\n", "")) - 2

	local prefix
	formatString, prefix = string.gsub(formatString, "^!", "", 1)

	local debugInfo = debug.info(errorDepth, "s")
	local moduleName = if not debugInfo
		then prefix == 1 and table.remove(arguments, 1) or "Command bar"
		else prefix == 1 and table.remove(arguments, 1) or table.remove(string.split(debugInfo, ".")) or "Command bar"

	local functionName = ""

	for index = 1, select("#", ...) do
		arguments[index] = Debug_Inspect(arguments[index])
	end

	for matched in string.gmatch(string.sub(traceback, 1, -11), "%- [^\r\n]+[\r\n]") do
		functionName = matched
	end

	functionName =
		string.gsub(string.gsub(string.sub(functionName, 3, -2), "%l+ (%S+)$", "%1"), " ([^\n\r]+)", " %1", 1)

	local index = 0
	for matched in string.gmatch(formatString, "%%%l") do
		index += 1
		if matched == "%q" then
			arguments[index] = string.gsub(arguments[index], " (%S+)$", " \"%1\"", 1)
		end
	end

	local success, errorString = pcall(
		string.format,
		"[%*] {%*} " .. string.gsub(formatString, "%%q", "%%*"),
		moduleName,
		REPLACERS[functionName] or functionName,
		table.unpack(arguments)
	)

	if success then
		return errorString, errorDepth
	end

	error(
		GetErrorData(
			"!Error formatting failed, perhaps try escaping non-formattable tags like so: %%%%f\n(Error Message): "
				.. errorString,
			"Debug"
		)
	)
end

function Debug.InspectFormat(formatString: string, ...)
	if type(formatString) ~= "string" then
		error(GetErrorData("!The first parameter of error formatting must be a string", "Debug"))
	end

	local arguments = {...}
	formatString = string.gsub(formatString, "^!", "", 1)

	for index = 1, select("#", ...) do
		arguments[index] = Debug_Inspect(arguments[index])
	end

	local index = 0
	for matched in string.gmatch(formatString, "%%%l") do
		index += 1
		if matched == "%q" then
			arguments[index] = string.gsub(arguments[index], " (%S+)$", " \"%1\"", 1)
		end
	end

	local success, errorString =
		pcall(string.format, (string.gsub(formatString, "%%q", "%%*")), table.unpack(arguments))

	if success then
		return errorString
	end

	error(
		GetErrorData(
			"!Error formatting failed, perhaps try escaping non-formattable tags like so: %%%%f\n(Error Message): "
				.. errorString,
			"Debug"
		)
	)
end

--[=[
	Functions the same as [Debug.Error], but internally calls warn instead of
	error.

	@param ... ...unknown -- The arguments to pass to warn.
]=]
function Debug.Warn(...)
	warn((GetErrorData(...)))
end

function Debug.Error(...)
	error(GetErrorData(...))
end

function Debug.Assert(condition, ...)
	return condition or error(GetErrorData(...))
end

local function AssertNoTypes(condition, ...)
	return condition or error(GetErrorData(...))
end
Debug.AssertNoTypes = AssertNoTypes :: (...unknown) -> any

--@native
local function Alphabetically(a: unknown, b: unknown)
	local typeA = typeof(a)
	local typeB = typeof(b)

	if typeA == typeB then
		return if typeA == "number"
			then (a :: number) < b :: number
			else string.lower(tostring(a)) < string.lower(tostring(b))
	end

	return typeA < typeB
end

--@native
function Debug.AlphabeticalOrder<K, V>(dictionary: {[K]: V}): () -> (K, V)
	local order = {}
	local length = 0

	-- next because of __call
	for key in next, dictionary do
		length += 1
		order[length] = key
	end

	table.sort(order, Alphabetically)

	local index = 0
	-- stylua: ignore
	return function(iteratedTable)
		index += 1
		local key = order[index]
		return key, iteratedTable[key], index
	end, dictionary, nil
end

--[=[
	Unions iterator functions in the order they are passed in, without
	duplicates from overlap.

	```lua
	for i, v in Debug.UnionIteratorFunctions(ipairs, pairs){1,2,3,4, a = 1, b = 2} do
		print(i, v)
	end
	```

	@param ... IteratorFunction
	@return IteratorFunction
]=]
function Debug.UnionIteratorFunctions(...)
	local iteratorFunctions = {...}

	for _, iteratorFunction in iteratorFunctions do
		if type(iteratorFunction) ~= "function" then
			error("Cannot union Iterator functions which aren't functions", 2)
		end
	end

	return function(iterateTable)
		local count = 0
		local order = {[0] = {}}
		local keysSeen = {}

		for index, iteratorFunction in iteratorFunctions do
			local callback, tableToIterateThrough, next = iteratorFunction(iterateTable)

			if type(callback) ~= "function" or type(tableToIterateThrough) ~= "table" then
				error(
					"Iterator function "
						.. index
						.. " must return a stack of types as follows: Function, Table, Variant",
					2
				)
			end

			while true do
				local data = {callback(tableToIterateThrough, next)}
				next = data[1]
				if next == nil then
					break
				end

				if not keysSeen[next] then
					keysSeen[next] = true
					count += 1
					table.insert(data, index)
					order[count] = data
				end
			end
		end

		-- stylua: ignore
		return function(_, previous)
			for index = 0, count do
				if order[index][1] == previous then
					local data = order[index + 1]
					if data then
						return table.unpack(data)
					end
					return nil
				end
			end

			error("invalid key to unioned iterator function: " .. previous, 2)
		end, iterateTable, nil
	end
end

local ConvertTableIntoString: (
	object: {[any]: any},
	tableName: string?,
	multiline: boolean?,
	depth: number,
	encounteredTables: {[any]: any}
) -> string

local function Parse(object: any, multiline: boolean?, depth: number, encounteredTables: {[any]: any})
	local typeOf = typeof(object)

	return typeOf == "table"
			and (encounteredTables[object] and "[table " .. encounteredTables[object] .. "]" or ConvertTableIntoString(
				object,
				nil,
				multiline,
				depth + 1,
				encounteredTables
			))
		or typeOf == "string" and "\"" .. object .. "\""
		or typeOf == "Instance" and "<" .. Debug.DirectoryToString(object) .. ">"
		or (typeOf == "function" or typeOf == "userdata") and typeOf
		or tostring(object)
end

function ConvertTableIntoString(object, tableName, multiline, depth, encounteredTables)
	local n = encounteredTables.n + 1
	encounteredTables[object] = n
	encounteredTables.n = n

	local array: {string} = {}
	local length = 1
	local currentArrayIndex = 1

	if tableName then
		array[1] = tableName
		array[2] = " = {"
		length = 2
	else
		array[1] = "{"
	end

	if not next(object) then
		array[length + 1] = "}"
		return table.concat(array)
	end

	for key, value in Debug.AlphabeticalOrder(object) do
		if not multiline and type(key) == "number" then
			if key == currentArrayIndex then
				currentArrayIndex += 1
			else
				length += 1
				array[length] = "[" .. key .. "] = "
			end

			length += 1
			array[length] = Parse(value, multiline, depth, encounteredTables)

			length += 1
			array[length] = ", "
		else
			if multiline then
				length += 1
				array[length] = "\n"

				length += 1
				array[length] = string.rep(TAB, depth)
			end

			if type(key) == "string" and string.find(key, "^[%a_][%w_]*$") then
				length += 1
				array[length] = key
			else
				length += 1
				array[length] = "["

				length += 1
				array[length] = Parse(key, multiline, depth, encounteredTables)

				length += 1
				array[length] = "]"
			end

			length += 1
			array[length] = " = "

			length += 1
			array[length] = Parse(value, multiline, depth, encounteredTables)

			length += 1
			array[length] = multiline and ";" or ", "
		end
	end

	if multiline then
		length += 1
		array[length] = "\n"

		length += 1
		array[length] = string.rep(TAB, depth - 1)
	else
		array[length] = nil
		length -= 1
	end

	length += 1
	array[length] = "}"

	local metatable = getmetatable(object :: never)

	if metatable then
		length += 1
		array[length] = " <- "

		length += 1
		array[length] = if type(metatable) == "table"
			then ConvertTableIntoString(metatable, nil, multiline, depth, encounteredTables)
			else Debug_Inspect(metatable)
	end

	return table.concat(array)
end

--[=[
	Pretty self-explanatory. `object` is the table to convert into a string.
	`tableName` puts `local tableName =` at the beginning. `multiline` makes
	it multiline.

	Returns a string-readable version of `object`.

	@param object {[any]: any} -- The table to convert into a string.
	@param multiline? boolean -- If the table should be multiline.
	@param tableName? string -- The name of the table.

	@return string
]=]
function Debug.TableToString(object: {[any]: any}, multiline: boolean?, tableName: string?): string
	return ConvertTableIntoString(object, tableName, multiline, 1, {n = 0})
end

local ESCAPED_CHARACTERS = {"%", "^", "$", "(", ")", ".", "[", "]", "*", "+", "-", "?"}
local ESCAPABLE = "([%" .. table.concat(ESCAPED_CHARACTERS, "%") .. "])"

--[=[
	Turns strings into Lua-readable format. Returns Objects location in proper
	Lua format. Useful for when you are doing string-intensive coding. Those
	minus signs are so tricky!

	@param value string -- The string to escape.
	@return string
]=]
function Debug.EscapeString(value: string): string
	return (string.gsub(string.gsub(value, ESCAPABLE, "%%%1"), "([\"'\\])", "\\%1"))
end

--[=[
	Returns a string representation of the objects.

	@function Inspect
	@within Debug

	@param ... ...unknown -- The objects to inspect.
	@return string
]=]
function Debug_Inspect(...: any): string
	local variableArgumentsLength = select("#", ...)
	if variableArgumentsLength == 0 then
		return "NONE"
	end

	local stringBuilder = table.create(variableArgumentsLength * 2)
	local length = 0

	for index = 1, variableArgumentsLength do
		local data = select(index, ...)
		local dataType = typeof(data)
		local dataString

		if dataType == "Instance" then
			dataType = data.ClassName
			dataString = Debug.DirectoryToString(data)
		elseif dataType == "EnumItem" then
			dataType = tostring(data.EnumType)
			dataString = tostring(data)
		else
			dataString = if dataType == "table"
				then Debug.TableToString(data)
				elseif dataType == "string" then "\"" .. data .. "\""
				else tostring(data)
		end

		stringBuilder[length + 1] = ", "
		stringBuilder[length + 2] =
			string.gsub(dataType .. " " .. dataString, "^" .. dataType .. " " .. dataType, dataType, 1)
		length += 2
	end

	return string.sub(table.concat(stringBuilder), 3)
end
Debug.Inspect = Debug_Inspect

return table.freeze(Debug)
