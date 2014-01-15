function CopyFolder(OldFolderPath, NewFolderPath)
	local Content = cFile:GetFolderContents(OldFolderPath .. "/") -- Get all the content in the given folder.
	if not cFile:Exists(NewFolderPath) then
		cFile:CreateFolder(NewFolderPath)
	end
	
	local a_CurrentPath = NewFolderPath
	local function CopySingleFolder(OldFolderPath, NewFolderPath)
		if not cFile:Exists(NewFolderPath) then
			cFile:CreateFolder(NewFolderPath)
		end
		local Content = cFile:GetFolderContents(OldFolderPath .. "/")
		for Idx, Filename in pairs(Content) do
			if Filename ~= "." and Filename ~= ".." then
				if cFile:IsFile(OldFolderPath .. "/" .. Filename) then
					cFile:Copy(OldFolderPath .. "/" .. Filename, NewFolderPath .. "/" .. Filename)
				else
					CopySingleFolder(OldFolderPath .. "/" .. Filename, NewFolderPath .. "/" .. Filename)
				end
			end
		end
	end
	for Idx, Filename in pairs(Content) do
		if Filename ~= "." and Filename ~= ".." then
			local Path = OldFolderPath .. "/" .. Filename
			if cFile:IsFile(Path) then
				cFile:Copy(Path, NewFolderPath .. "/" .. Filename)
			elseif cFile:IsFolder(Path) then
				a_CurrentPath = NewFolderPath .. "/" .. Filename
				CopySingleFolder(Path, a_CurrentPath)
			end
		end
	end
end

CopyFolder("TestFolder", "TestFolder2")