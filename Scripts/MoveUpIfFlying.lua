function OnPlayerMoving(Player)
 if Player:IsFlying() then
  Player:SetFlying(false)
  local Vector = Player:GetLookVector() * 3
  Vector.y = 15
  Player:ShootTo(Vector)
 end
end
cPluginManager.AddHook(cPluginManager.HOOK_PLAYER_MOVING, OnPlayerMoving)

