--!strict
-- Shared type definitions. Client and server both require this so the two
-- sides can never drift apart on what the data looks like.

export type GearOwned = {
	Keyboard: number, -- tier index owned, 0 = none
	Chair: number,
	Coffee: number,
}

export type OwnedIntern = {
	Uid: string, -- unique per hire, so duplicates of the same intern can coexist
	Id: string, -- key into Config/Interns
}

-- Everything that persists for one player. Primitives only — this table gets
-- JSON-encoded by ProfileStore, so no Vector3/Color3/Instance may ever enter it.
export type ProfileData = {
	DataVersion: number,
	Productivity: number,
	Wins: number,
	Rank: number, -- index into Config/Ranks
	Restructures: number,
	BestRank: number, -- highest rank ever reached (survives Restructure)
	TotalClicks: number,
	Gear: GearOwned,
	Severance: { string }, -- chosen perk ids, in the order they were picked
	PendingSeverance: { string }, -- the 3 cards offered and not yet picked (empty when none)
	Interns: { OwnedIntern },
	EquippedInterns: { string }, -- uids
	BossesDefeated: { string }, -- floor ids whose boss has been beaten (survives Restructure)
	PurchaseLog: { string }, -- receipt ids already granted, for idempotent dev products
	FirstJoinTime: number,
}

-- The slice of ProfileData the client is allowed to see, plus derived values
-- the server computes so the client never re-implements balance math.
export type ClientState = {
	Productivity: number,
	Wins: number,
	Rank: number,
	Restructures: number,
	Gear: GearOwned,
	Severance: { string },
	PendingSeverance: { string },
	Interns: { OwnedIntern },
	EquippedInterns: { string },
	BossesDefeated: { string },
	-- Derived, server-computed:
	ClickIncome: number, -- productivity gained per click right now
	IdlePerSecond: number, -- chair + intern passive income right now
	RestructureCost: number,
	NextRankAt: number, -- productivity needed for next rank (math.huge at cap)
	InternSlots: number,
	-- Floor ids the player may enter because they bought that floor's skip
	-- gamepass, regardless of the normal Restructure gate.
	OwnedSkips: { [string]: boolean },
}

-- One rival's live state as replicated to clients (compact on purpose).
export type RivalState = {
	Id: string, -- unique per placed rival, e.g. "Mailroom_R3"
	Remaining: number, -- workload left; 0 while defeated/respawning
	RespawnAt: number, -- workspace time when it comes back (0 = alive)
}

-- Fired to all clients for world-visible moments.
export type FxKind =
	"RankUp"
	| "RivalDefeated"
	| "BossDefeated"
	| "Restructure"
	| "InternHired"
	| "Purchase"
	| "Payday"
	| "Overtime"

export type ServerService = {
	Init: (self: any) -> ()?,
	Start: (self: any) -> ()?,
}

return nil
