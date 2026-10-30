--!strict
-- World 2 (Business District) enemy crews, picked Oct 27: office workers and bosses, 8 crews of 4 in stage order.
-- Same structure as EnemyRoster.lua (World 1) and dressed the same way by EnemyLooks: real Roblox catalog items
-- (ids below, with the item name and creator as a comment), every id checked against the economy API on Oct 27
-- (it exists, its asset type fits its slot, its name fits the look).
-- head = an official Roblox classic-face head; head parts = its mood / eyebrows (the same heads as World 1).

local Roster = {}

Roster.Crews = {
	{
		Key = "interns",
		Name = "Interns",
		Area = "Business District",
		Stages = { 1, 2 },
		Theme = "First-week interns in crisp white and blue office shirts with khakis, name tags and lanyards, each juggling a coffee or a clipboard; the Head Intern has a little blue blazer, slicked hair and the clipboard.",
		Characters = {
			{
				key = "interns_1",
				crew = "Interns",
				role = "minion",
				name = "Coffee Run Cody",
				shirt = 6647273098, -- office shirt — Aesthetic Vibe
				pants = 732302358, -- Khakis — Robloxian High School Group
				tshirt = 0,
				head = 12939347925, -- Know it All Grin - Head — Roblox
				headParts = {
					{ id = 12939349434, type = "Mood" }, -- Know it All Grin MoodAnimation — Roblox
					{ id = 12939345542, type = "Eyebrow" }, -- Know it All Grin - Brows — Roblox
				},
				accessories = {
					{ id = 7193419595, type = "Hair" }, -- Side Part - Brown — Roblox
					{ id = 15320702991, type = "Face" }, -- Classic Coffee Cup — Tycoon Company
					{ id = 5268932993, type = "Waist" }, -- Lanyard (1.0) — genkroco
				},
				skin = Color3.fromRGB(234, 184, 146),
				scale = 1,
			},
			{
				key = "interns_2",
				crew = "Interns",
				role = "minion",
				name = "Copy Machine Carl",
				shirt = 5534697166, -- Office Worker + — Orλnge Studios
				pants = 732302358, -- Khakis — Robloxian High School Group
				tshirt = 0,
				head = 11308884165, -- Err... - Head — Roblox
				headParts = {
					{ id = 11308848181, type = "Mood" }, -- Err... - Mood — Roblox
					{ id = 11308877966, type = "Eyebrow" }, -- Err... - Eyebrow — Roblox
				},
				accessories = {
					{ id = 15162501267, type = "Hair" }, -- Messy Fluffy Boy Hair Ginger — hughje
					{ id = 11884330, type = "Face" }, -- Nerd Glasses — Roblox
					{ id = 14499473461, type = "Front" }, -- Name Tag — Iskender's Excellent Emporium
				},
				skin = Color3.fromRGB(255, 204, 153),
				scale = 1,
			},
			{
				key = "interns_3",
				crew = "Interns",
				role = "minion",
				name = "Sticky Note Sally",
				shirt = 175997634, -- Intern Shirt — Locke Corp
				pants = 732302358, -- Khakis — Robloxian High School Group
				tshirt = 0,
				head = 108948147871080, -- Up To Something - Head — Roblox
				headParts = {
					{ id = 118240829709234, type = "Mood" }, -- Up To Something - Mood — Roblox
				},
				accessories = {
					{ id = 15269675247, type = "Hair" }, -- Long Wavy High Ponytail Hair (Blonde) — gyansu
					{ id = 8527979605, type = "Face" }, -- Morning Coffee Cup — ICENODE
					{ id = 5268932993, type = "Waist" }, -- Lanyard (1.0) — genkroco
				},
				skin = Color3.fromRGB(160, 113, 90),
				scale = 1,
			},
			{
				key = "interns_boss",
				crew = "Interns",
				role = "boss",
				name = "Head Intern Hunter",
				shirt = 7838106312, -- Blue Business Suit Shirt — Provolone
				pants = 732302358, -- Khakis — Robloxian High School Group
				tshirt = 0,
				head = 111385667345306, -- Smug - Head — Roblox
				headParts = {
					{ id = 91878717569774, type = "Mood" }, -- Smug - Mood — Roblox
				},
				accessories = {
					{ id = 87289314618096, type = "Hair" }, -- Businessman's Slicked Back Brown Hair — DevVinci
					{ id = 14404336948, type = "Front" }, -- Petition Clipboard — cool stuff and things
					{ id = 5268932993, type = "Waist" }, -- Lanyard (1.0) — genkroco
				},
				skin = Color3.fromRGB(217, 164, 122),
				scale = 1.5,
			},
		},
	},
	{
		Key = "mailroom",
		Name = "Mailroom",
		Area = "Business District",
		Stages = { 3, 4 },
		Theme = "The mailroom crew in blue postal shirts and matching mail-carrier trousers, blue caps and messenger bags full of letters; the Mailroom Boss wears the blue mail cap and uniform, a letter backpack and the delivery clipboard.",
		Characters = {
			{
				key = "mailroom_1",
				crew = "Mailroom",
				role = "minion",
				name = "Parcel Pete",
				shirt = 603251185, -- Postman — Blotnik
				pants = 1035334148, -- Mailman- — Classic's RL Clothing
				tshirt = 0,
				head = 117501539542427, -- Hmmm... - Head — Roblox
				headParts = {
					{ id = 127069197012959, type = "Mood" }, -- Hmmm... - Mood — Roblox
				},
				accessories = {
					{ id = 18821919651, type = "Hat" }, -- Navy Blue Fitted Baseball Cap — Rey x Noob
					{ id = 4585211600, type = "Back" }, -- Messenger Bag — WhoToTrus
				},
				skin = Color3.fromRGB(204, 142, 105),
				scale = 1,
			},
			{
				key = "mailroom_2",
				crew = "Mailroom",
				role = "minion",
				name = "Stamp Stomper",
				shirt = 10974158678, -- Courier Short Uniform Shirt — EmesOfficial
				pants = 1035334148, -- Mailman- — Classic's RL Clothing
				tshirt = 0,
				head = 99892364304434, -- Prankster - Head — Roblox
				headParts = {
					{ id = 97714690779642, type = "Mood" }, -- Prankster - Mood — Roblox
				},
				accessories = {
					{ id = 1028728, type = "Hat" }, -- Blue Baseball Cap — Roblox
					{ id = 16232138702, type = "Face" }, -- Letter — iSEANxo
					{ id = 4753657610, type = "Back" }, -- Black Messenger Bag — WhoToTrus
				},
				skin = Color3.fromRGB(105, 64, 40),
				scale = 1,
			},
			{
				key = "mailroom_3",
				crew = "Mailroom",
				role = "minion",
				name = "Envelope Ellie",
				shirt = 1035385550, -- Dark Blue Roblox Polo — orange451
				pants = 1035334148, -- Mailman- — Classic's RL Clothing
				tshirt = 0,
				head = 111481431844333, -- Just Trouble - Head — Roblox
				headParts = {
					{ id = 99421862292859, type = "Mood" }, -- Just Trouble - Mood — Roblox
				},
				accessories = {
					{ id = 16332168569, type = "Hair" }, -- Business Lady Bun in Brown — HEARTL1FE
					{ id = 4585211600, type = "Back" }, -- Messenger Bag — WhoToTrus
				},
				skin = Color3.fromRGB(242, 199, 165),
				scale = 1,
			},
			{
				key = "mailroom_boss",
				crew = "Mailroom",
				role = "boss",
				name = "The Mailroom Boss",
				shirt = 603251185, -- Postman — Blotnik
				pants = 16268758472, -- Valentine's Blue Mail Uniform/Suit — ILuvVideoGamez
				tshirt = 0,
				head = 14525047012, -- It's Go Time - Head — Roblox
				headParts = {
					{ id = 14525058221, type = "Mood" }, -- It's Go Time - Mood — Roblox
					{ id = 14525051805, type = "Eyebrow" }, -- It's Go Time - Brows — Roblox
				},
				accessories = {
					{ id = 16231679471, type = "Hat" }, -- Valentine's Blue Mail Cap — ILuvVideoGamez
					{ id = 8664821560, type = "Back" }, -- Letter backpack — blushannie
					{ id = 14404336948, type = "Front" }, -- Petition Clipboard — cool stuff and things
				},
				skin = Color3.fromRGB(124, 92, 70),
				scale = 1.5,
			},
		},
	},
	{
		Key = "security",
		Name = "Security",
		Area = "Tower Lobby",
		Stages = { 5, 6 },
		Theme = "Tower security guards in navy and black uniforms with guard caps, dark shades, earpieces and radios; the Security Chief wears the black guard jacket, a peaked cap, an earpiece and a gold badge.",
		Characters = {
			{
				key = "security_1",
				crew = "Security",
				role = "minion",
				name = "Door Guard Doug",
				shirt = 6269703448, -- [+] Generic Security Guard Uniform — Pripp
				pants = 7583033165, -- Navy Blue Business Pants — Dualpoint Interactive
				tshirt = 0,
				head = 89187695892355, -- Stink Eye - Head — Roblox
				headParts = {
					{ id = 108254418440729, type = "Mood" }, -- Stink Eye - Mood — Roblox
				},
				accessories = {
					{ id = 16437708112, type = "Hat" }, -- Police Security Guard Cap — GreenPigXD
					{ id = 14400254687, type = "Face" }, -- Black Aviators Sunglasses — The Cat Drip Galaxy
				},
				skin = Color3.fromRGB(217, 164, 126),
				scale = 1,
			},
			{
				key = "security_2",
				crew = "Security",
				role = "minion",
				name = "Badge Check Bea",
				shirt = 7592217489, -- Security — club XOX
				pants = 129459077, -- Black Slacks — Roblox
				tshirt = 0,
				head = 101398692064661, -- I Am Not Amused - Head — Roblox
				headParts = {
					{ id = 112909703913615, type = "Mood" }, -- I Am Not Amused - Mood — Roblox
				},
				accessories = {
					{ id = 79227875756850, type = "Hat" }, -- classic navy police cap — Six4or8!
					{ id = 9361758520, type = "Front" }, -- Clip-on walkie-talkie black — Tactical Enhancements
				},
				skin = Color3.fromRGB(90, 61, 43),
				scale = 1,
			},
			{
				key = "security_3",
				crew = "Security",
				role = "minion",
				name = "Night Watch Nate",
				shirt = 6269703448, -- [+] Generic Security Guard Uniform — Pripp
				pants = 7583033165, -- Navy Blue Business Pants — Dualpoint Interactive
				tshirt = 0,
				head = 136591502467368, -- Commando - Head — Roblox
				headParts = {
					{ id = 103401662308769, type = "Mood" }, -- Commando - Mood — Roblox
				},
				accessories = {
					{ id = 9243992729, type = "Hair" }, -- Short and Sleek - Black — Roblox
					{ id = 4684658997, type = "Hat" }, -- Secret Service Earpiece — Reverse_Polarity
					{ id = 12324267177, type = "Face" }, -- Black Polarized Aviator Sunglasses — Deadsuwu
				},
				skin = Color3.fromRGB(248, 217, 194),
				scale = 1,
			},
			{
				key = "security_boss",
				crew = "Security",
				role = "boss",
				name = "Security Chief Steel",
				shirt = 99921942, -- Security Guard Jacket- Black [Glovless] — Ardwyck
				pants = 99922007, -- Security Guard Jacket- Black [Bottoms] — Ardwyck
				tshirt = 0,
				head = 113711018795336, -- Drill Sergeant - Head — Roblox
				headParts = {
					{ id = 91193890487827, type = "Mood" }, -- Drill Sergeant - Mood — Roblox
				},
				accessories = {
					{ id = 11140062294, type = "Hat" }, -- Black Police Military Navy Army Cap Garda — goldfroggy8
					{ id = 4684658997, type = "Hat" }, -- Secret Service Earpiece — Reverse_Polarity
					{ id = 14400254687, type = "Face" }, -- Black Aviators Sunglasses — The Cat Drip Galaxy
					{ id = 12589361509, type = "Front" }, -- Gold Sheriff (Police) Badge — Iskender's Excellent Emporium
				},
				skin = Color3.fromRGB(160, 95, 53),
				scale = 1.5,
			},
		},
	},
	{
		Key = "it",
		Name = "IT Department",
		Area = "Tower Lobby",
		Stages = { 7, 8 },
		Theme = "The IT crew in blue hoodies, a blue plaid shirt and jeans, every one in a headset or nerd glasses, one with a laptop bag; the IT Wizard wears a grey zip hoodie with a wizard hat, a wizard cape and a laptop on his belt.",
		Characters = {
			{
				key = "it_1",
				crew = "IT Department",
				role = "minion",
				name = "Help Desk Hank",
				shirt = 6825096846, -- Dark Blue Plain Hoodie — Swirls Clothing
				pants = 129458426, -- Jeans — Roblox
				tshirt = 0,
				head = 11308945948, -- Check It - Head — Roblox
				headParts = {
					{ id = 11308935548, type = "Mood" }, -- Check It - Mood — Roblox
					{ id = 11308949065, type = "Eyebrow" }, -- Check It - Eyebrow — Roblox
				},
				accessories = {
					{ id = 6993758617, type = "Hair" }, -- Short and Sleek - Brown — Roblox
					{ id = 15796557819, type = "Face" }, -- fast food worker headset with mic — On Clearance
				},
				skin = Color3.fromRGB(234, 184, 146),
				scale = 1,
			},
			{
				key = "it_2",
				crew = "IT Department",
				role = "minion",
				name = "Cable Tangle Tina",
				shirt = 6825091994, -- Light Blue Plain Hoodie — Swirls Clothing
				pants = 382537569, -- Black Jeans — Roblox
				tshirt = 0,
				head = 11308884165, -- Err... - Head — Roblox
				headParts = {
					{ id = 11308848181, type = "Mood" }, -- Err... - Mood — Roblox
					{ id = 11308877966, type = "Eyebrow" }, -- Err... - Eyebrow — Roblox
				},
				accessories = {
					{ id = 12786347740, type = "Hair" }, -- Trendy Short Curly Hair Brown — paracosms
					{ id = 13280880593, type = "Hat" }, -- Gamer Mic Headphones — DatBrian
					{ id = 11884330, type = "Face" }, -- Nerd Glasses — Roblox
				},
				skin = Color3.fromRGB(124, 92, 70),
				scale = 1,
			},
			{
				key = "it_3",
				crew = "IT Department",
				role = "minion",
				name = "Reboot Ricky",
				shirt = 398635081, -- Blue Plaid Shirt — Roblox
				pants = 129458426, -- Jeans — Roblox
				tshirt = 0,
				head = 82338169245404, -- Sneaky Steve - Head — Roblox
				headParts = {
					{ id = 134732357298188, type = "Mood" }, -- Sneaky Steve - Mood — Roblox
				},
				accessories = {
					{ id = 16302076672, type = "Hair" }, -- Classic Messy Fluffy Boy Hair Black — bankwear
					{ id = 97731614679502, type = "Face" }, -- Headset Mic — qgc
					{ id = 4794889154, type = "Back" }, -- Gaming Laptop — DieSoft
				},
				skin = Color3.fromRGB(217, 164, 122),
				scale = 1,
			},
			{
				key = "it_boss",
				crew = "IT Department",
				role = "boss",
				name = "The IT Wizard",
				shirt = 8197492170, -- Gray Zip Up Hoodie — Glo Еnt
				pants = 382537569, -- Black Jeans — Roblox
				tshirt = 0,
				head = 12939347925, -- Know it All Grin - Head — Roblox
				headParts = {
					{ id = 12939349434, type = "Mood" }, -- Know it All Grin MoodAnimation — Roblox
					{ id = 12939345542, type = "Eyebrow" }, -- Know it All Grin - Brows — Roblox
				},
				accessories = {
					{ id = 1049198, type = "Hat" }, -- ROBLOX Classic: Wizard's Hat — Roblox
					{ id = 10644692873, type = "Back" }, -- Classic Wizard Cape — ICENODE
					{ id = 75987971458769, type = "Waist" }, -- Laptop — XO UGC
					{ id = 11884330, type = "Face" }, -- Nerd Glasses — Roblox
				},
				skin = Color3.fromRGB(255, 204, 153),
				scale = 1.5,
			},
		},
	},
	{
		Key = "sales",
		Name = "Sales Team",
		Area = "Office Floors",
		Stages = { 9, 10 },
		Theme = "Fast-talking sales reps in matching navy suits and trousers with slick hair, ties and a phone or headset at the ear; the Top Seller wears a bright blue suit, the classic slick salesman hair, dark shades and is always on the phone.",
		Characters = {
			{
				key = "sales_1",
				crew = "Sales Team",
				role = "minion",
				name = "Cold Call Cole",
				shirt = 7584182020, -- Navy Blue Business Suit — Dualpoint Interactive
				pants = 7583033165, -- Navy Blue Business Pants — Dualpoint Interactive
				tshirt = 0,
				head = 111385667345306, -- Smug - Head — Roblox
				headParts = {
					{ id = 91878717569774, type = "Mood" }, -- Smug - Mood — Roblox
				},
				accessories = {
					{ id = 7062107080, type = "Hair" }, -- Black Slicked back hair — Willowthedumb
					{ id = 12945478449, type = "Hat" }, -- Phone Call — glowlez
				},
				skin = Color3.fromRGB(204, 142, 105),
				scale = 1,
			},
			{
				key = "sales_2",
				crew = "Sales Team",
				role = "minion",
				name = "Deal Closer Dana",
				shirt = 6837393809, -- Navy Blue Suit [+] — TIX Clothing +
				pants = 516090019, -- LIT Navy Blue Suit PANTS — Eagle™
				tshirt = 0,
				head = 75853796532602, -- Sly Guy Face - Head — Roblox
				headParts = {
					{ id = 129306210206691, type = "Mood" }, -- Sly Guy Face - Mood — Roblox
				},
				accessories = {
					{ id = 9243987340, type = "Hair" }, -- Short and Sleek - Blonde — Roblox
					{ id = 95720835987934, type = "Hat" }, -- microphone headset — RAINBO'S CREATIONS
				},
				skin = Color3.fromRGB(242, 199, 165),
				scale = 1,
			},
			{
				key = "sales_3",
				crew = "Sales Team",
				role = "minion",
				name = "Pitch Perfect Pat",
				shirt = 6837400257, -- Navy Blue Suit | Vest [+] — TIX Clothing +
				pants = 7583033165, -- Navy Blue Business Pants — Dualpoint Interactive
				tshirt = 0,
				head = 140710522436831, -- Fearless - Head — Roblox
				headParts = {
					{ id = 122322924737705, type = "Mood" }, -- Fearless - Mood — Roblox
				},
				accessories = {
					{ id = 13265870189, type = "Hair" }, -- Side Part-Black — hu2an
					{ id = 28554622, type = "Neck" }, -- Red Striped Tie — Roblox
				},
				skin = Color3.fromRGB(105, 64, 40),
				scale = 1,
			},
			{
				key = "sales_boss",
				crew = "Sales Team",
				role = "boss",
				name = "Top Seller Sterling",
				shirt = 11613925464, -- Blue Suit with Blue Tie — FileSaved
				pants = 516090019, -- LIT Navy Blue Suit PANTS — Eagle™
				tshirt = 0,
				head = 99138878800007, -- The Big Dog - Head — Roblox
				headParts = {
					{ id = 107063727266904, type = "Mood" }, -- The Big Dog - Mood — Roblox
				},
				accessories = {
					{ id = 880450257, type = "Hair" }, -- Slick Salesman Hair — Roblox
					{ id = 12945478449, type = "Hat" }, -- Phone Call — glowlez
					{ id = 14400254687, type = "Face" }, -- Black Aviators Sunglasses — The Cat Drip Galaxy
				},
				skin = Color3.fromRGB(232, 180, 143),
				scale = 1.5,
			},
		},
	},
	{
		Key = "lawyers",
		Name = "Lawyers",
		Area = "Office Floors",
		Stages = { 11, 12 },
		Theme = "Serious lawyers in black suits and black trousers, every one carrying the same black briefcase; the Big Shot Lawyer wears a black suit with a grey vest, slick white hair, dark shades and a business tie.",
		Characters = {
			{
				key = "lawyers_1",
				crew = "Lawyers",
				role = "minion",
				name = "Fine Print Fiona",
				shirt = 7584202092, -- Black Business Suit — Dualpoint Interactive
				pants = 7583105393, -- Black Business Pants — Dualpoint Interactive
				tshirt = 0,
				head = 101398692064661, -- I Am Not Amused - Head — Roblox
				headParts = {
					{ id = 112909703913615, type = "Mood" }, -- I Am Not Amused - Mood — Roblox
				},
				accessories = {
					{ id = 16332168569, type = "Hair" }, -- Business Lady Bun in Brown — HEARTL1FE
					{ id = 10648587889, type = "Back" }, -- Briefcase — Roblox
				},
				skin = Color3.fromRGB(234, 184, 146),
				scale = 1,
			},
			{
				key = "lawyers_2",
				crew = "Lawyers",
				role = "minion",
				name = "Objection Otto",
				shirt = 7272228337, -- Black Suit ‘n’ Grey Shirt [+] — TIX Clothing +
				pants = 1210858279, -- Black Suit Pants — The Iron Cafe™
				tshirt = 0,
				head = 117501539542427, -- Hmmm... - Head — Roblox
				headParts = {
					{ id = 127069197012959, type = "Mood" }, -- Hmmm... - Mood — Roblox
				},
				accessories = {
					{ id = 6207528478, type = "Hair" }, -- Short Style Black Hair — MIANNNGAMER
					{ id = 11884330, type = "Face" }, -- Nerd Glasses — Roblox
					{ id = 10648587889, type = "Back" }, -- Briefcase — Roblox
				},
				skin = Color3.fromRGB(160, 95, 53),
				scale = 1,
			},
			{
				key = "lawyers_3",
				crew = "Lawyers",
				role = "minion",
				name = "Paperwork Percy",
				shirt = 5081876535, -- Formal Men's Business Suit w/ Red Tie — Wolf Clothing®
				pants = 70770596631449, -- Black Suit [-] — idea.exe
				tshirt = 0,
				head = 89187695892355, -- Stink Eye - Head — Roblox
				headParts = {
					{ id = 108254418440729, type = "Mood" }, -- Stink Eye - Mood — Roblox
				},
				accessories = {
					{ id = 9243995099, type = "Hair" }, -- Short and Sleek - Red — Roblox
					{ id = 10648587889, type = "Back" }, -- Briefcase — Roblox
				},
				skin = Color3.fromRGB(248, 217, 194),
				scale = 1,
			},
			{
				key = "lawyers_boss",
				crew = "Lawyers",
				role = "boss",
				name = "Big Shot Lawyer",
				shirt = 7152029219, -- Black Suit w/ Grey Vest [+] — TIX Clothing +
				pants = 7583105393, -- Black Business Pants — Dualpoint Interactive
				tshirt = 0,
				head = 140710522436831, -- Fearless - Head — Roblox
				headParts = {
					{ id = 122322924737705, type = "Mood" }, -- Fearless - Mood — Roblox
				},
				accessories = {
					{ id = 7062104408, type = "Hair" }, -- White Slicked back hair — Willowthedumb
					{ id = 12324267177, type = "Face" }, -- Black Polarized Aviator Sunglasses — Deadsuwu
					{ id = 30111567, type = "Neck" }, -- BC Business Tie — Roblox
					{ id = 10648587889, type = "Back" }, -- Briefcase — Roblox
				},
				skin = Color3.fromRGB(107, 74, 53),
				scale = 1.5,
			},
		},
	},
	{
		Key = "managers",
		Name = "Managers",
		Area = "Rooftop Offices",
		Stages = { 13, 14 },
		Theme = "Middle managers in grey and white: sweater vests, shirts and ties and vest suits over black slacks, with clipboards and coffee mugs; the Regional Manager wears a dark grey suit with a blue tie, grey styled hair, a coffee mug and the clipboard.",
		Characters = {
			{
				key = "managers_1",
				crew = "Managers",
				role = "minion",
				name = "Memo Mike",
				shirt = 6192314280, -- Gray Sweater Vest w/ Tie — Kisila Collections
				pants = 129459077, -- Black Slacks — Roblox
				tshirt = 0,
				head = 84930555025211, -- Meanie - Head — Roblox
				headParts = {
					{ id = 136358026305838, type = "Mood" }, -- Meanie - Mood — Roblox
				},
				accessories = {
					{ id = 5364461475, type = "Hair" }, -- Classic Black Hair — MainGag
					{ id = 14404336948, type = "Front" }, -- Petition Clipboard — cool stuff and things
				},
				skin = Color3.fromRGB(198, 142, 94),
				scale = 1,
			},
			{
				key = "managers_2",
				crew = "Managers",
				role = "minion",
				name = "Overtime Olga",
				shirt = 6501120361, -- White Dress Shirt W Undone Tie — Tiger ®
				pants = 129459077, -- Black Slacks — Roblox
				tshirt = 0,
				head = 13702615195, -- Grr! - Head — Roblox
				headParts = {
					{ id = 13702615304, type = "Mood" }, -- Grr! - Mood — Roblox
					{ id = 13702615393, type = "Eyebrow" }, -- Grr! - Eyebrow Accessory — Roblox
				},
				accessories = {
					{ id = 15269675247, type = "Hair" }, -- Long Wavy High Ponytail Hair (Blonde) — gyansu
					{ id = 104135426915173, type = "Face" }, -- Coffee Mug — DuckXander
				},
				skin = Color3.fromRGB(255, 204, 153),
				scale = 1,
			},
			{
				key = "managers_3",
				crew = "Managers",
				role = "minion",
				name = "Deadline Dave",
				shirt = 6554200369, -- Grey Suit w/ Black Vest [+] — TIX Clothing +
				pants = 1210858279, -- Black Suit Pants — The Iron Cafe™
				tshirt = 0,
				head = 108948147871080, -- Up To Something - Head — Roblox
				headParts = {
					{ id = 118240829709234, type = "Mood" }, -- Up To Something - Mood — Roblox
				},
				accessories = {
					{ id = 7193419595, type = "Hair" }, -- Side Part - Brown — Roblox
					{ id = 28554622, type = "Neck" }, -- Red Striped Tie — Roblox
					{ id = 16032111450, type = "Waist" }, -- Waist Petition Clipboard — cool stuff and things
				},
				skin = Color3.fromRGB(124, 92, 70),
				scale = 1,
			},
			{
				key = "managers_boss",
				crew = "Managers",
				role = "boss",
				name = "The Regional Manager",
				shirt = 2589330210, -- Dark Grey Suit with Blue Tie — Lollganz' Abode
				pants = 1210858279, -- Black Suit Pants — The Iron Cafe™
				tshirt = 0,
				head = 85263717490387, -- Furious George - Head — Roblox
				headParts = {
					{ id = 101408286852172, type = "Mood" }, -- Furious George - Mood — Roblox
				},
				accessories = {
					{ id = 6995526268, type = "Hair" }, -- Men's Gray Styled Hair — DawsonDelRey
					{ id = 104135426915173, type = "Face" }, -- Coffee Mug — DuckXander
					{ id = 14404336948, type = "Front" }, -- Petition Clipboard — cool stuff and things
				},
				skin = Color3.fromRGB(234, 184, 146),
				scale = 1.5,
			},
		},
	},
	{
		Key = "board",
		Name = "The Board",
		Area = "Rooftop Offices",
		Stages = { 15, 16 },
		Theme = "The board members in the most expensive suits in the city (black, green and gold) with grey hair, monocles and gold ties; boss The CEO, the world's final boss, wears the sharpest white suit, slicked black hair, gold aviators, a gold tie and a gold diamond watch.",
		Characters = {
			{
				key = "board_1",
				crew = "The Board",
				role = "minion",
				name = "Chairman Chester",
				shirt = 7979110508, -- Fancy Black Suit — FileSaved
				pants = 7979113138, -- Fancy Black Suit Pants — FileSaved
				tshirt = 0,
				head = 117501539542427, -- Hmmm... - Head — Roblox
				headParts = {
					{ id = 127069197012959, type = "Mood" }, -- Hmmm... - Mood — Roblox
				},
				accessories = {
					{ id = 12864800, type = "Hair" }, -- Old Man Hair — Roblox
					{ id = 30390853, type = "Face" }, -- Monocle — Roblox
					{ id = 96430996341063, type = "Neck" }, -- Gold Stylish Tie — Zlosu
				},
				skin = Color3.fromRGB(248, 217, 194),
				scale = 1,
			},
			{
				key = "board_2",
				crew = "The Board",
				role = "minion",
				name = "Stock Ticker Stan",
				shirt = 6512512538, -- Dark Green Suit — FileSaved
				pants = 7979113138, -- Fancy Black Suit Pants — FileSaved
				tshirt = 0,
				head = 97709344552035, -- Daring Beard - Head — Roblox
				headParts = {
					{ id = 79917079340265, type = "Mood" }, -- Daring Beard - Mood — Roblox
				},
				accessories = {
					{ id = 13743113117, type = "Hair" }, -- Slicked Back Gray Hair Realistic Hairline — DawsonDelRey
					{ id = 12270889568, type = "Face" }, -- Gold Coin Monocle — Roblox
					{ id = 96430996341063, type = "Neck" }, -- Gold Stylish Tie — Zlosu
				},
				skin = Color3.fromRGB(217, 164, 122),
				scale = 1,
			},
			{
				key = "board_3",
				crew = "The Board",
				role = "minion",
				name = "Dividend Diane",
				shirt = 7186499558, -- gold rich suit — CrazyPotato268
				pants = 7979113138, -- Fancy Black Suit Pants — FileSaved
				tshirt = 0,
				head = 75853796532602, -- Sly Guy Face - Head — Roblox
				headParts = {
					{ id = 129306210206691, type = "Mood" }, -- Sly Guy Face - Mood — Roblox
				},
				accessories = {
					{ id = 9243987340, type = "Hair" }, -- Short and Sleek - Blonde — Roblox
					{ id = 96430996341063, type = "Neck" }, -- Gold Stylish Tie — Zlosu
				},
				skin = Color3.fromRGB(160, 113, 90),
				scale = 1,
			},
			{
				key = "board_boss",
				crew = "The Board",
				role = "boss",
				name = "The CEO",
				shirt = 7142678950, -- Fancy White Suit — FileSaved
				pants = 7142679679, -- Fancy White Suit Pants — FileSaved
				tshirt = 0,
				head = 13822758815, -- Sinister - Head — Roblox
				headParts = {
					{ id = 13822758884, type = "Mood" }, -- Sinister - Mood — Roblox
				},
				accessories = {
					{ id = 13631044043, type = "Hair" }, -- Black Slicked Back Suave Hair — The Barber Shoppe
					{ id = 13887107983, type = "Face" }, -- Gold and Black Aviators Sunglasses — The Cat Drip Galaxy
					{ id = 96430996341063, type = "Neck" }, -- Gold Stylish Tie — Zlosu
					{ id = 106354307510500, type = "Shoulder" }, -- Luxury Gold & Diamond Watch — Glo Еnt
				},
				skin = Color3.fromRGB(232, 180, 143),
				scale = 1.6,
			},
		},
	},
}

return Roster
