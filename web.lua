
-- web.lua - contains the web handler + things the handler needs.





-- Contains information per webadmin user information like the last executed code.
-- Can be used later to continue polling for logs if the executed code uses async functions like cWorld:QueueTask.
local m_Sessions = {};





-- Lua code which gets prepended to every code that will be executed.
-- Replaces print and all LOGXYZ functions with versions that save the message to a table
-- so they can be returned and displayed to the webadmin user.
local m_LuaScript = [[
local Logs = ...
local Fprint = print
local FLOG = LOG
local FLOGWARN = LOGWARN
local FLOGWARNING = LOGWARNING
local FLOGINFO = LOGINFO
local FLOGERROR = LOGERROR

local function ADD_TO_LOG(a_LogType, a_Message)
	table.insert(Logs, {type = a_LogType, time = os.date("%X ", os.time()), message = tostring(a_Message) })
end


local function print(...)
	local Message = ""
	for I, k in pairs({...}) do
		Message = Message .. tostring(k) .. "\t"
	end
	Fprint(...)
	ADD_TO_LOG("print", Message)
end
local function GetMessageFromArg(...)
	local arg = {...}
	local Message = ""
	if #arg == 1 then
		Message = tostring(arg[1])
	else
		local String = "return "
		for I, k in pairs(arg) do
			if I ~= 1 and I ~= "n" then
				String = String .. tostring(k) .. ", "
			end
		end
		local Function = loadstring(String:sub(1, String:len() - 2))
		assert(Function ~= nil)
		Message = string.format(arg[1], ...)
	end
	return Message
end


local function LOG(...)
	local Message = GetMessageFromArg(...)
	FLOG(Message)
	ADD_TO_LOG("log", Message);
end
local function LOGWARN(...)
	local Message = GetMessageFromArg(...)
	FLOGWARN(Message)
	ADD_TO_LOG("log-warn", Message);
end
local function LOGWARNING(...)
	local Message = GetMessageFromArg(...)
	FLOGWARNING(Message)
	ADD_TO_LOG("log-warn", Message);
end
local function LOGINFO(...)
	local Message = GetMessageFromArg(...)
	FLOGINFO(Message)
	ADD_TO_LOG("log-info", Message);
end
local function LOGERROR(...)
	local Message = GetMessageFromArg(...)
	FLOGERROR(Message)
	ADD_TO_LOG("log-error", Message);
end
]]





-- Pattern to check if a name is valid.
-- A filename is valid when it only has letters and numbers and ends with the .lua extension.
local m_FileNameValidationPattern = "^%w-%.lua$"





local function GetExecuteString(a_Code)
	return m_LuaScript .. a_Code .. [[

	return Logs]]
end




local function GetNumLines(a_String)
	return #StringSplit(a_String, "\n")
end





local m_ResourceFiles = {
	['editor']   = g_Plugin:GetLocalFolder() .. "/ace/ace.js",
	['mode-lua'] = g_Plugin:GetLocalFolder() .. "/ace/mode-lua.js",
	['init']     = g_Plugin:GetLocalFolder() .. "/init.js",
	['style']    = g_Plugin:GetLocalFolder() .. "/style.css"
}





-- Endpoint to retrieve javascript and css files.
local function HandleResourceEndpoint(a_Request, a_Session)
	local requestedFile = a_Request.Params['file']
	local path = m_ResourceFiles[requestedFile]
	if (not path) then
		return "Not found"
	end
	local ext = path:match("%.(.-)$");
	local contentType = cWebAdmin:GetContentTypeFromFileExt(ext);
	return cFile:ReadWholeFile(path), contentType
end





-- Endpoint to retrieve the list of all the files in the script folder.
local function HandleGetFileListEndpoint(a_Request, a_Session)
	local FolderContent = cFile:GetFolderContents(g_Plugin:GetLocalFolder() .. "/Scripts/")
	return cJson:Serialize(FolderContent), "application/json"
end





-- Endpoint to delete a script file.
-- If an error occurs the content-type is "error"
local function HandleDeleteFileEndpoint(a_Request, a_Session)
	local filename = a_Request.PostParams['delete-file'];
	if (not filename:match(m_FileNameValidationPattern)) then
		return "Improper filename", "error"
	end
	local path = g_Plugin:GetLocalFolder() .. "/Scripts/" .. filename;
	if (not cFile:IsFile(path)) then
		return "File not found", "error";
	end
	
	cFile:Delete(path)
	return "ok"
end





-- Endpoint to open a file from the Script folder.
-- If an error occured the content-type is "error"
local function HandleOpenFileEndpoint(a_Request, a_Session)
	local filename = a_Request.Params['file']
	if (not filename:match(m_FileNameValidationPattern)) then
		return "Improper filename", "error"
	end
	local path = g_Plugin:GetLocalFolder() .. "/Scripts/" .. filename;
	if (cFile:IsFile(path)) then
		local code = cFile:ReadWholeFile(path)
		a_Session.LuaScript = code;
		return code, "text/plain"
	else
		return "File does not exist.", "error"
	end
end





-- Endpoint that saves the provided Lua code to a file in the Script folder.
-- Anything other than 'ok' is an error.
local function HandleSaveFileEndpoint(a_Request, a_Session)
	local filename = a_Request.PostParams['file']
	if (not filename:match(m_FileNameValidationPattern)) then
		return "Improper filename", "error"
	end
	local code = a_Request.PostParams['code'];
	local f = io.open(g_Plugin:GetLocalFolder() .. "/Scripts/" .. filename, "w")
	f:write(code);
	f:close();
	
	return "ok"
end





-- Endpoint that executes the provided Lua code. 
-- If the code uses the print or LOGXYZ functions the results will be returned as a JSON array.
local function HandleExecuteEndpoint(a_Request, a_Session)
	if (a_Request.PostParams["LuaScript"] == nil) then
		return "No code provided"
	end
	
	local code = a_Request.PostParams["LuaScript"]
	a_Session.LuaScript = code;
	local logs = {}
	local executeCode = GetExecuteString(code)
	local compiledFunction, errorMessage = loadstring(executeCode)
	if (not compiledFunction) then
		errorMessage = errorMessage:gsub(":.-:", 
			function(a_Str)
				return ":" .. (tonumber(a_Str:sub(2, a_Str:len() - 1)) or 0) - GetNumLines(m_LuaScript) .. ":"
			end
		)
		errorMessage = " Line " .. errorMessage:sub(errorMessage:find(":"), errorMessage:len()) -- Remove the first part of the error, because it would only be confusing.
		errorMessage = errorMessage:gsub("\n", "<br />")
		table.insert(logs, {type = "log-error", message = errorMessage, time = os.date("%X ", os.time()) })
	else
		local success, result = pcall(compiledFunction, logs)
		if (not success) then
			result = result:gsub(":.-:", 
				function(a_Str)
					return ":" .. (tonumber(a_Str:sub(2, a_Str:len() - 1)) or 0) - GetNumLines(m_LuaScript) .. ":"
				end
			)
			result = " Line " .. result:sub(result:find(":"), result:len()) -- Remove the first part of the error, because it would only be confusing.
			result = result:gsub("\n", "<br />")
			table.insert(logs, {type = "log-error", message = result, time = os.date("%X ", os.time()) })
		end
	end
	return cJson:Serialize(logs), "application/json";
end





local m_Endpoints = {
	['resource']      = HandleResourceEndpoint,
	['get-file-list'] = HandleGetFileListEndpoint,
	['delete-file']   = HandleDeleteFileEndpoint,
	['get-file']      = HandleOpenFileEndpoint,
	['save-file']     = HandleSaveFileEndpoint,
	['execute']       = HandleExecuteEndpoint
}





-- Web Tab endpoint.
-- If no get parameter to specify an endpoint is provided it returns the html page.
function HandleExecuteTab(a_Request)
	m_Sessions[a_Request.Username] = m_Sessions[a_Request.Username] or {}
	
	if (a_Request.Params['endpoint'] ~= nil) then
		local handler = m_Endpoints[a_Request.Params['endpoint']];
		if (not handler) then
			error("Requested endpoint not found");
		end
		return handler(a_Request, m_Sessions[a_Request.Username]);
	end
	
	local code = m_Sessions[a_Request.Username].LuaScript
	
	local Content = [[
<script src="/~webadmin/Executor/Execute+Lua?endpoint=resource&file=editor"></script>
<script src="/~webadmin/Executor/Execute+Lua?endpoint=resource&file=mode-lua"></script>
<link rel="stylesheet" type="text/css" href="/~webadmin/Executor/Execute+Lua?endpoint=resource&file=style" />

<div id="buttons">
	<button onclick="execute(event)">Execute</button>
	<button onclick="listFilesDropDown(event)">Show Files</button>
	<button onclick="saveFileDropDown(event)">Save File</button>
</div>

<div id="logs">
</div>

<div id="drop-down" data-status="closed">
</div>

<pre id="editor">]] .. cWebAdmin:GetHTMLEscapedString(code) .. [[</pre>

<div id="output">
</div>

<script src="/~webadmin/Executor/Execute+Lua?endpoint=resource&file=init"></script>
]]	

	return Content
end




