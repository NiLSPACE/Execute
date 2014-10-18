
-- init.lua - contains Initialize and OnDisable





-- Global plugin object
g_Plugin = nil





function Initialize(a_Plugin)
	g_Plugin = a_Plugin
	
	a_Plugin:SetName("Executor")
	a_Plugin:SetVersion(2)
	
	cFile:CreateFolder(a_Plugin:GetLocalFolder() .. "/Scripts")
	
	a_Plugin:AddWebTab("Execute Lua", HandleExecuteTab)
	
	LOG("Initialized Execute")
	return true
end





function OnDisable()
	LOG("Execute is disabled")
end



