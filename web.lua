
-- web.lua - contains the web handler + things the handler needs.





local m_LuaScript = [[
local Logs = {}
local Fprint = print
local FLOG = LOG
local FLOGWARN = LOGWARN
local FLOGWARNING = LOGWARNING
local FLOGINFO = LOGINFO
local FLOGERROR = LOGERROR
local function print(...)
	local Message = ""
	for I, k in pairs({...}) do
		Message = Message .. tostring(k) .. "\t"
	end
	Fprint(...)
	table.insert(Logs, '<b style="color: #D8D8D8;">' .. tostring(Message) .. "</b>")
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
	table.insert(Logs, '<b style="color: #D8D8D8;">' .. os.date("[%X] ", os.time()) .. tostring(Message) .. "</b>")
end
local function LOGWARN(...)
	local Message = GetMessageFromArg(...)
	FLOGWARN(Message)
	table.insert(Logs, '<b style="color: Red;">' .. os.date("[%X] ", os.time()) .. tostring(Message) .. "</b>")
end
local function LOGWARNING(...)
	local Message = GetMessageFromArg(...)
	FLOGWARNING(Message)
	table.insert(Logs, '<b style="color: Red;">' .. os.date("[%X] ", os.time()) .. tostring(Message) .. "</b>")
end
local function LOGINFO(...)
	local Message = GetMessageFromArg(...)
	FLOGINFO(Message)
	table.insert(Logs, '<b style="color: Yellow;">' .. os.date("[%X] ", os.time()) .. tostring(Message) .. "</b>")
end
local function LOGERROR(...)
	local Message = GetMessageFromArg(...)
	FLOGERROR(Message)
	table.insert(Logs, '<b style="color: Black; background-color: red">' .. os.date("[%X] ", os.time()) .. tostring(Message) .. "</b>")
end
]]





function GetExecuteString(a_TextAreaContent)
	return m_LuaScript .. a_TextAreaContent .. [[

	return Logs]]
end




function GetNumLines(a_String)
	return #StringSplit(a_String, "\n")
end





function HandleExecuteTab(a_Request)
	local Content = ""
	local TextAreaContent = a_Request.PostParams["LuaScript"] or ""
	local LogResults = {}
	
	-- Execute the TextArea content if it's not nothing.
	if ((TextAreaContent ~= "") and (a_Request.PostParams["Execute"] ~= nil)) then
		local ExecuteString = GetExecuteString(TextAreaContent)
		local ExecuteFunction, ErrorMessage = loadstring(ExecuteString)
		if (not ExecuteFunction) then
			ErrorMessage = ErrorMessage:gsub(":.-:", 
				function(a_Str)
					return ":" .. (tonumber(a_Str:sub(2, a_Str:len() - 1)) or 0) - GetNumLines(m_LuaScript) .. ":"
				end
			)
			ErrorMessage = " Line " .. ErrorMessage:sub(ErrorMessage:find(":"), ErrorMessage:len()) -- Remove the first part of the error, because it would only be confusing.
			ErrorMessage = ErrorMessage:gsub("\n", "<br />")
			table.insert(LogResults, '<b style="color: Black; background-color: red">' .. os.date("[%X] ", os.time()) .. ErrorMessage .. '</b>')
		else
			local Succes, Result, T = pcall(ExecuteFunction)
			if (not Succes) then
				Result = Result:gsub(":.-:", 
					function(a_Str)
						return ":" .. (tonumber(a_Str:sub(2, a_Str:len() - 1)) or 0) - GetNumLines(m_LuaScript) .. ":"
					end
				)
				Result = " Line " .. Result:sub(Result:find(":"), Result:len()) -- Remove the first part of the error, because it would only be confusing.
				Result = Result:gsub("\n", "<br />")
				table.insert(LogResults, '<b style="color: Black; background-color: red">' .. os.date("[%X] ", os.time()) .. Result .. '</b>')
			else
				LogResults = Result
			end
		end
	end
	
	-- Check if the user wants to save his script to a file
	if (a_Request.PostParams["SaveFile"] ~= nil) then
		if (a_Request.PostParams["FileName"] == "") then
			Content = Content .. '<b style="color: red;">You must enter a filename</b>\n'
		else
			local FileName = a_Request.PostParams["FileName"]:gsub("%..", ""):gsub("/", "")
			local File = io.open(g_Plugin:GetLocalFolder() .. "/Scripts/" .. FileName, "w")
			File:write(tostring(TextAreaContent))
			File:close()
			Content = Content .. '<b style="color: green;">File saved</b>\n'
		end
	end
	
	-- Check if the user wants to delete a file
	if (a_Request.PostParams["DeleteFile"] ~= nil) then
		cFile:Delete(g_Plugin:GetLocalFolder() .. "/Scripts/" .. a_Request.PostParams["DeleteFile"])
		Content = Content .. '<b style="color: red;">You removed "' .. a_Request.PostParams["DeleteFile"] .. '"</b><br />'
	end
	
	-- Open a file if the user wants it. If the file doesn't exist we simply show all the known files.
	if (a_Request.PostParams["OpenFile"] ~= nil) then
		if (cFile:Exists(g_Plugin:GetLocalFolder() .. "/Scripts/" .. a_Request.PostParams["OpenFile"])) then
			TextAreaContent = cFile:ReadWholeFile(g_Plugin:GetLocalFolder() .. "/Scripts/" .. a_Request.PostParams["OpenFile"])
		else
			local FolderContent = cFile:GetFolderContents(g_Plugin:GetLocalFolder() .. "/Scripts/")
			Content = Content .. '<table>\n'
			for Idx, FileName in ipairs(FolderContent) do
				Content = Content .. '	<tr>\n'
				Content = Content .. '		<td>' .. FileName .. '</td>'
				Content = Content .. '		<td><form method="POST"><input type="hidden" name="DeleteFile" value="' .. FileName .. '" /><input type="submit" value="Delete" name="Delete" /></form></td>'
				Content = Content .. '		<td><form method="POST"><input type="hidden" name="OpenFile" value="' .. FileName .. '" /><input type="submit" value="Open" name="Open" /></form></td>'
				Content = Content .. '	</tr>'
			end
			Content = Content .. '</table>'
			return Content
		end
	end
	
	-- Add the javascript to the content
	Content = Content .. '<script type="text/javascript">' .. cFile:ReadWholeFile(g_Plugin:GetLocalFolder() .. "/editor.js") .. '</script>\n'
	
	Content = Content .. '<form method="POST">\n'
	Content = Content .. '	<table>\n'
	Content = Content .. '		<tr>\n'
	Content = Content .. '			<td><input type="submit" value="Execute" name="Execute" /></td>'
	Content = Content .. '			<td>&ensp;</td>\n' -- Placeholder
	Content = Content .. '			<td>&ensp;</td>\n' -- Placeholder
	Content = Content .. '			<td><input type="submit" value="Script List" name="OpenFile" /></td>\n'
	Content = Content .. '			<td><input type="text" onclick="if (this.value == \'filename\') {this.value = \'\'}" value="filename" name="FileName" /><input type="submit" value="Save File" name="SaveFile"/></td>'
	Content = Content .. '		</tr>\n'
	Content = Content .. '	</table>'
	Content = Content .. '	<textarea style="width: 100%; height: 500px;" name="LuaScript" id="TextArea" onclick="CheckCurrentLine();" onkeypress="return HandleOnKeyPress(event);">' .. TextAreaContent .. '</textarea>\n'
	Content = Content .. '</form>\n'
	
	Content = Content .. '<div style="width: 100%; height: 20px;">\n'
	Content = Content .. '	<table style="width: 100%; height: 100%;">\n'
	Content = Content .. '		<tr>\n'
	Content = Content .. '			<td id="CurrentLineCounter">CurrentLine: 1</td>\n'
	Content = Content .. '			<td id="LineCounter">Num lines: </td>\n'
	Content = Content .. '		</tr>\n'
	Content = Content .. '	</table>\n'
	Content = Content .. '</div> <br />\n'
	
	-- Add the results from the executed script.
	if (#LogResults > 0) then
		Content = Content .. '<div style="background-color: black;"><br />\n'
		for I, LogLine in pairs(LogResults) do
			Content = Content .. LogLine .. "<br />\n"
		end
		Content = Content .. "<br /></div>"
	end
	
	-- Make sure the data about the textarea is update on startup.
	Content = Content .. '<script type="text/javascript">CheckCurrentLine("test");</script>';
	return Content
end




