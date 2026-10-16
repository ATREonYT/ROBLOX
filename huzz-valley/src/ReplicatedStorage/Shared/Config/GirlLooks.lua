--[[
	Each anime girl's look for her effects (Shared/AuraLook): an element and two colours (bright, deep), by
	her model's name in the ANIME GIRLS folder. Picked by hand from who she is (her accessory names give it
	away: Megumin's staff and eyepatch, Rukia's katana, Aqua...), because her real colours are in her
	clothing pictures, which the game can't read.
	Elements: Flame, Frost, Sakura, Night, Holy, Storm, Nature, Water.
	A girl missing here gets her rarity's colour and Sparkle (soft stars). Change any line freely.
]]
local rgb = Color3.fromRGB

return {
	-- Common
	["CAC_R6_Nikaccount41_E52B4E"] = { Who = "Darkness", Element = "Holy", Colors = { rgb(255, 226, 140), rgb(196, 160, 60) } },
	["CAC_R6_IdontLikeSand312_C3D54E"] = { Element = "Sakura", Colors = { rgb(255, 170, 205), rgb(220, 90, 150) } },
	["CAC_R6_SH0RTAE_C36E59"] = { Who = "Saya", Element = "Night", Colors = { rgb(170, 130, 255), rgb(70, 40, 140) } },
	["CAC_R6_Zero57334_E99DC9"] = { Who = "Taiga", Element = "Flame", Colors = { rgb(255, 190, 110), rgb(210, 90, 40) } },
	["CAC_R6_Zero57334_E2B7CE"] = { Who = "Ryo", Element = "Water", Colors = { rgb(120, 190, 255), rgb(40, 80, 190) } },
	["CAC_R6_PlaymanhBR_B17B40"] = { Element = "Sakura", Colors = { rgb(255, 190, 220), rgb(200, 110, 170) } },
	["CAC_R6_zzAvalon_E8A31F"] = { Who = "Reze", Element = "Flame", Colors = { rgb(255, 150, 80), rgb(150, 30, 60) } },
	["CAC_R6_ED_Lizhi_DC0EB6"] = { Who = "Nino", Element = "Sakura", Colors = { rgb(255, 150, 200), rgb(180, 60, 140) } },
	["CAC_R6_SH0RTAE_E4CE1D"] = { Who = "Yotsuba", Element = "Nature", Colors = { rgb(170, 255, 140), rgb(255, 150, 60) } },
	["CAC_R6_sd32432432_E033F5"] = { Who = "Ichika", Element = "Sakura", Colors = { rgb(255, 200, 220), rgb(220, 120, 160) } },
	["CAC_R6_necluse_854C19"] = { Element = "Water", Colors = { rgb(150, 220, 255), rgb(60, 120, 200) } },
	["CAC_R6_loganuwugg_BE42BA"] = { Element = "Flame", Colors = { rgb(255, 110, 100), rgb(120, 20, 30) } },
	-- Rare
	["CAC_R6_CunHazzy_AE3211"] = { Who = "Kita", Element = "Flame", Colors = { rgb(255, 140, 120), rgb(200, 40, 60) } },
	["CAC_R6_killerklIi_E2DA45"] = { Element = "Frost", Colors = { rgb(235, 245, 255), rgb(120, 150, 210) } },
	["CAC_R6_Kairvexa_EA0023"] = { Who = "Aqua", Element = "Water", Colors = { rgb(120, 230, 255), rgb(30, 110, 220) } },
	["CAC_R6_MoneyInTr_946B10"] = { Who = "Bocchi", Element = "Sakura", Colors = { rgb(255, 160, 210), rgb(120, 70, 160) } },
	["CAC_R6_roblox118909_6B96D9"] = { Who = "Mai", Element = "Night", Colors = { rgb(200, 150, 255), rgb(40, 20, 80) } },
	["CAC_R6_c509zz_E2B52D"] = { Element = "Storm", Colors = { rgb(255, 240, 140), rgb(90, 80, 200) } },
	["CAC_R6_c509zz_EA042E"] = { Who = "Ram", Element = "Sakura", Colors = { rgb(255, 180, 210), rgb(150, 60, 120) } },
	["CAC_R6_kaguma_Kun17_A1F4E8"] = { Element = "Frost", Colors = { rgb(180, 240, 255), rgb(70, 140, 220) } },
	-- Epic
	["CAC_R6_Master_Cheif4444_BB5C2C"] = { Who = "Anko", Element = "Night", Colors = { rgb(190, 120, 255), rgb(60, 10, 90) } },
	["CAC_R6_witchoofgreed_C14D27"] = { Who = "Echidna", Element = "Night", Colors = { rgb(240, 240, 255), rgb(30, 20, 50) } },
	["CAC_R6_enchanities_3066FF"] = { Element = "Storm", Colors = { rgb(140, 220, 255), rgb(60, 40, 160) } },
	["CAC_R6_futuremelancholy_CB2AD3"] = { Who = "Orihime", Element = "Holy", Colors = { rgb(255, 210, 150), rgb(240, 120, 60) } },
	["CAC_R6_YiagoQino_E7FCFD"] = { Element = "Nature", Colors = { rgb(190, 255, 170), rgb(40, 140, 90) } },
	["CAC_R6_Xzgamer70_DB7CB4"] = { Who = "Nino", Element = "Sakura", Colors = { rgb(255, 140, 190), rgb(150, 40, 110) } },
	["CAC_R6_XxamberXx12328_DBAFA4"] = { Who = "Nami", Element = "Storm", Colors = { rgb(255, 220, 110), rgb(255, 130, 40) } },
	["CAC_R6_GoodwinDakota422_AA2072"] = { Who = "Rukia", Element = "Frost", Colors = { rgb(230, 250, 255), rgb(90, 160, 255) } },
	-- Legendary
	["CAC_R6_SH0RTAE_D23E64"] = { Element = "Night", Colors = { rgb(120, 220, 255), rgb(20, 30, 70) } },
	["CAC_R6_Raptus578_E86CB0"] = { Who = "Yuno", Element = "Sakura", Colors = { rgb(255, 130, 180), rgb(170, 20, 60) } },
	["CAC_R6_fivehomics_788B0C"] = { Who = "Nazuna", Element = "Night", Colors = { rgb(200, 140, 255), rgb(30, 10, 60) } },
	["CAC_R6_reznuyy_E964BE"] = { Element = "Holy", Colors = { rgb(255, 245, 210), rgb(220, 170, 90) } },
	-- Mythic
	["CAC_R6_ixKatsu_358858"] = { Who = "Megumin", Element = "Flame", Colors = { rgb(255, 120, 70), rgb(130, 0, 30) } },
	["CAC_R6_kingnotmeantobe_DAB086"] = { Who = "Zero Two", Element = "Flame", Colors = { rgb(255, 120, 170), rgb(170, 0, 40) } },
	-- Secret
	["CAC_R15_TransportViewer_DDEE6E"] = { Who = "C.C.", Element = "Nature", Colors = { rgb(150, 255, 150), rgb(10, 90, 40) } },
	["CAC_R6_EditFami_8815C6"] = { Element = "Night", Colors = { rgb(120, 255, 240), rgb(10, 20, 30) } },
}
