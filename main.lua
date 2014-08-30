SIZE_TEXT_AREA = 10

function Initialize(Plugin)
	PLUGIN = Plugin
	Plugin:SetName("Execute")
	Plugin:SetVersion(1)
	
	Plugin:AddWebTab("Execute", HandleWebTabExecute)
	
	if not cFile:Exists(PLUGIN:GetLocalFolder() .. "/Scripts") then
		cFile:CreateFolder(PLUGIN:GetLocalFolder() .. "/Scripts")
	end
	
	return true
end

function HandleWebTabExecute(Request)
	if Request.PostParams["SaveToFile"] ~= nil then
		if Request.PostParams["FileName"] ~= "" then
			local File = io.open(PLUGIN:GetLocalFolder() .. "/Scripts/" .. Request.PostParams["FileName"], "w")
			File:write(tostring(Request.PostParams["TextBox"]))
			File:close()
		end
	end
	if Request.PostParams["DeleteScript"] ~= nil then
		if cFile:Exists(PLUGIN:GetLocalFolder() .. "/Scripts/" .. Request.PostParams["DeleteScript"]) then
			cFile:Delete(PLUGIN:GetLocalFolder() .. "/Scripts/" .. Request.PostParams["DeleteScript"])
		end
	end
	local Content = ""
	local FolderContents = cFile:GetFolderContents(PLUGIN:GetLocalFolder() .. "/Scripts")
	local FolderContent = {}
	local Logs = {}
	for I, k in pairs(FolderContents) do
		if k ~= '.' and k ~= '..' then
			table.insert(FolderContent, k)
		end
	end
	local LongestFileName = GetLongestStringInTable(FolderContent)
	local ToExecute = Request.PostParams["TextBox"]
	if Request.PostParams["OpenScript"] ~= nil then
		ToExecute = ""
		local File = io.open(PLUGIN:GetLocalFolder() .. "/Scripts/" .. Request.PostParams["OpenScript"])
		if File then
			ToExecute = File:read("*all")
		end
		File:close()
	end
	if (ToExecute ~= nil) then
		if Request.PostParams["Execute"] ~= nil then
			local ExecuteString = [[
				local Logs = {}
				local Content = ""
				local Fprint = print
				local FLOG = LOG
				local FLOGWARN = LOGWARN
				local FLOGWARNING = LOGWARNING
				local FLOGINFO = LOGINFO
				local FLOGERROR = LOGERROR
				function GetType(Thing)
					return cWebAdmin:GetHTMLEscapedString(tostring(Thing))
				end
				local function print(...)
					local Message = ""
					for I, k in pairs({...}) do
						Message = Message .. tostring(k) .. "\t"
					end
					Fprint(...)
					table.insert(Logs, '<b style="color: #D8D8D8;">' .. GetType(Message) .. "</b>")
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
					table.insert(Logs, '<b style="color: #D8D8D8;">' .. os.date("[%X] ", os.time()) .. GetType(Message) .. "</b>")
				end
				local function LOGWARN(...)
					local Message = GetMessageFromArg(...)
					FLOGWARN(Message)
					table.insert(Logs, '<b style="color: Red;">' .. os.date("[%X] ", os.time()) .. GetType(Message) .. "</b>")
				end
				local function LOGWARNING(...)
					local Message = GetMessageFromArg(...)
					FLOGWARNING(Message)
					table.insert(Logs, '<b style="color: Red;">' .. os.date("[%X] ", os.time()) .. GetType(Message) .. "</b>")
				end
				local function LOGINFO(...)
					local Message = GetMessageFromArg(...)
					FLOGINFO(Message)
					table.insert(Logs, '<b style="color: Yellow;">' .. os.date("[%X] ", os.time()) .. GetType(Message) .. "</b>")
				end
				local function LOGERROR(...)
					local Message = GetMessageFromArg(...)
					FLOGERROR(Message)
					table.insert(Logs, '<b style="color: Black;background-color:red">' .. os.date("[%X] ", os.time()) .. GetType(Message) .. "</b>")
				end
				]] .. ToExecute .. [[
				
				return Logs, Content]]
			f, errmsg = loadstring(ExecuteString)
			if f == nil then
				Content = Content .. '<b style="color: red;">' .. errmsg .. "</b><br />"
			else
				Logs, NewContent = f()
				if type(NewContent) == 'string' then
					Content = Content .. NewContent
				end
			end
		end
	else
		ToExecute = ""
	end
	
	Content = Content .. [[<table>
	<form method="POST" id='Execute'>
		<td>Execute <input type="submit" value="Execute" name="Execute"></td>
		<td><input type="text" name="FileName"><input type="submit" value="Save" name="SaveToFile"></td>
	</form></table>]]
	
	if #FolderContent > 0 then
		Content = Content .. [[
		<a id="show_id" onclick="document.getElementById('spoiler_id').style.display=''; document.getElementById('show_id').style.display='none';" class="link">[Show Scripts]</a><span id="spoiler_id" style="display: none"><a onclick="document.getElementById('spoiler_id').style.display='none'; document.getElementById('show_id').style.display='';" class="link">[Hide Scripts]</a><br>
		<table cellpadding="]] .. LongestFileName .. [[">]]
		for I, k in pairs(FolderContent) do
			Content = Content .. [[
			<tr>
				<td>]] .. k .. [[</td>
				<td><form method="POST"><input type="hidden" value="]] .. k .. [[" name="OpenScript"><input type="submit" value="Open" name="Dummy" size="30"></form></td>
				<td><form method="POST"><input type="hidden" value="]] .. k .. [[" name="DeleteScript"><input type="submit" value="Delete" name="Dummy" size="30"></form></td>
			</tr>]]
		end
		Content = Content .. '</table></span>'
	end
	
	Content = Content .. [[<textarea rows="]] .. SIZE_TEXT_AREA .. [[" cols="80" name='TextBox' id="TITLE" form='Execute'>]] .. ToExecute .. [[</textarea><br />]]
	
	if #Logs > 0 then
		Content = Content .. '<div style="background-color:black"><br />'
		for I, k in pairs(Logs) do
			Content = Content .. k .. "<br />"
		end
		Content = Content .. "<br /></div>"
	end
	return Content
end
	
function GetLongestStringInTable(Table)
	local LongestString = 0
	for Index, Content in pairs(Table) do
		if type(Content) == 'string' then
			if string.len(Content) > LongestString then
				LongestString = string.len(Content)
			end
		end
	end
	return LongestString
end