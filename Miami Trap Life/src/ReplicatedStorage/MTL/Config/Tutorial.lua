--!strict
-- The new-player tutorial (TutorialController; Research: Cinematic Cutscenes §9). One small coach card at a time,
-- a pulsing ring around the real thing it talks about, and the step ends when the player actually does it.
-- Steps run in order, only while the story is at one of their `stages`; a step whose stages are already behind the
-- player counts as done (a returning player never sees "open your phone" at Level 9).
-- Progress is saved in Settings.Tutorial (= number of steps done, Skipped = skipped). Order matters: append only.
--
-- Step fields:
--   id, stages = { story stage ids }, title, body = text | { kb, touch, pad } (per input device; kb is the default)
--   keys = { kb = {...}, touch = {...}, pad = {...} }   key chips under the text
--   target = a Targets id (what the ring goes around; nil = no ring) · whileOpen / whileOpenTarget = text + ring while
--   the phone is up (phone steps)
--   done = "phone" (opened, then put away) | "stage" (the story left these stages) | "task" (first job task done)
--        | "menu" (menu opened) | "starterBuy" (bought something at the stand) | "seen"
--        and/or  seconds = auto-advance after this long on screen
--   ok = "Got it" button text (shown for "seen" steps)
local Tutorial = {}

Tutorial.Skipped = 99

-- PlayerGui paths tried in order (the HUD and phone get redesigned; names are the contract, see UI/Build/*).
Tutorial.Targets = {
	Phone = { { "MTL_Phone", "Phone", "Body" }, { "MTL_Phone", "Phone" } },
	Messages = { { "MTL_Phone", "**App_Messages" } }, -- "**Name" = anywhere below (the phone's layout changes)
	Objective = { { "MTL_HUD", "Objective" } },
	Job = { { "MTL_Job", "Panel" } },
	Cash = { { "MTL_HUD", "Top", "Cash" } },
	Level = { { "MTL_HUD", "Top", "Status", "Level" }, { "MTL_HUD", "Top", "Status" } },
	Menu = { { "MTL_HUD", "Menu", "Toggle" } },
}

Tutorial.Steps = {
	{
		id = "Phone",
		stages = { "Arrive" },
		title = "Your phone just buzzed",
		body = { kb = "Press M to check it.", touch = "Tap your phone in the bottom right to check it.", pad = "Press up on the D-pad to check it." },
		keys = { kb = { "M" }, pad = { "D-pad up" } },
		target = "Phone",
		done = "phone",
		whileOpen = { kb = "Tap Messages to read Mr. Patel's text. Press M to put the phone away.", touch = "Tap Messages to read Mr. Patel's text, then swipe the phone down.", pad = "Open Messages to read Mr. Patel's text, then press up on the D-pad." },
		whileOpenTarget = "Messages", -- the ring moves to the Messages app while the phone is up
	},
	{
		id = "Walk",
		stages = { "Arrive" },
		title = "Head to Liberty Food Mart",
		body = "Follow the glowing arrows. Your next goal always sits at the top of the screen.",
		keys = { kb = { "W", "A", "S", "D" }, touch = { "Left thumb to walk" }, pad = { "Left stick" } },
		target = "Objective",
		done = "stage",
	},
	{
		id = "Job",
		stages = { "FirstShift" },
		title = "Clock in, get paid",
		body = { kb = "Your task is on the job panel. Walk to the glowing spot and hold E.", touch = "Your task is on the job panel. Walk to the glowing spot and hold the button.", pad = "Your task is on the job panel. Walk to the glowing spot and hold X." },
		keys = { kb = { "Hold E" }, pad = { "Hold X" } },
		-- the card names the live task from the job panel: "Now: Stock the empty shelf. Follow the glow ..."
		liveTask = { kb = "Follow the glow, then hold E.", touch = "Follow the glow, then hold the button.", pad = "Follow the glow, then hold X." },
		target = "Job",
		done = "task",
	},
	{
		id = "Paid",
		stages = { "FirstShift" },
		title = "Payday",
		body = "Every task pays. Watch your cash stack up right here.",
		target = "Cash",
		done = "seen",
		seconds = 7,
		ok = "Got it",
	},
	{
		id = "Level",
		stages = { "FirstShift" },
		title = "Level up",
		body = "Tasks fill this ring with XP. Hit Level {call} and someone comes calling...", -- {call} = this player's call level (A/B)
		target = "Level",
		done = "seen",
		seconds = 8,
		ok = "Got it",
	},
	{
		id = "Menu",
		stages = { "FirstShift" },
		title = "Your menu",
		body = { kb = "Press G for the store, emotes and settings.", touch = "Tap this button for the store, emotes and settings.", pad = "Press left on the D-pad for the store, emotes and settings." },
		keys = { kb = { "G" }, pad = { "D-pad left" } },
		target = "Menu",
		done = "menu",
		seconds = 12,
	},
	{
		-- something to buy in minute one (research P0-6): the stand inside the door (Config/StarterShop)
		id = "Drip",
		stages = { "FirstShift" },
		title = "Treat yourself",
		body = { kb = "The stand by the door sells caps and a chain. Walk up and press E to buy one.", touch = "The stand by the door sells caps and a chain. Walk up and tap Buy.", pad = "The stand by the door sells caps and a chain. Walk up and press X to buy one." },
		keys = { kb = { "E" }, pad = { "X" } },
		done = "starterBuy",
		seconds = 16,
		ok = "Later",
	},
}

Tutorial.Tuning = {
	FirstDelay = 1.2, -- seconds after a cutscene / join before the first card shows
	BetweenSteps = 0.9, -- pause after a step is done (the tick shows) before the next card
	PhoneReadSeconds = 10, -- "phone" steps also finish if the phone stays open this long
	DoneToast = "That's the basics. The city's yours.",
}

return Tutorial
