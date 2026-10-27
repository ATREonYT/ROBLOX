-- (brief 29) Your gun arms (Shared/CharMotion): both arms up holding the gun while you shoot, a kick on every shot,
-- and a ready stance while goons are up in your stage. Shoot.client and Waves.client report the shots.
local RS = game:GetService('ReplicatedStorage')
require(RS.Shared.CharMotion).start()
