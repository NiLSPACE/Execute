local KillCount = 9
local Root = cRoot:Get()
Root:ForEachWorld(function(World)
 World:ForEachEntity(function(Entity)
  if not Entity:IsPlayer() then
   KillCount = KillCount + 1
   Entity:Destroy(true)
  end
 end)
end)
LOGINFO("You Destroyed " .. KillCount .. " Entities")