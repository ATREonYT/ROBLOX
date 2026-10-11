-- (brief 29, P3b) What HoodClient/WorldBoss tells HoodClient/Waves (whose gun code fires at it): while you are on the
-- World Boss pier and it is up, Active is true and aim(from) gives the point to shoot at (nil out of reach); hit(damage,
-- at) is called for each shot you fire at it (its red number, your share).
return { Active = false, aim = function(_) return nil end, hit = function(_, _) end }
