--!nonstrict
-- New Game Kit spec: HitCheck (server checks for shots and swings). Vault "Realistic City RP/04".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HitCheck = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("HitCheck"))

local PISTOL = { range = 200, fireInterval = 0.2, spreadDeg = 2, magazine = 12, damage = 20, falloffStart = 50 }

local function shot(over)
	local claim = {
		origin = Vector3.new(1, 5, 0),
		direction = Vector3.new(0, 0, -1),
		targetPos = Vector3.new(0, 5, -100),
	}
	local ctx = {
		headPos = Vector3.new(0, 5, 0),
		now = 10,
		ammo = 5,
		targetAt = Vector3.new(0, 5, -98),
		lineOfSight = true,
	}
	for k, v in over or {} do
		if claim[k] ~= nil or k == "targetPos" then
			claim[k] = v
		else
			ctx[k] = v
		end
	end
	if over and over.noTarget then
		claim.targetPos = nil
	end
	return HitCheck.Shot(PISTOL, claim, ctx)
end

return function()
	describe("HitCheck.Shot", function()
		it("accepts an honest hit", function()
			local ok, why = shot()
			expect(ok).to.equal(true)
			expect(why).to.equal("Hit")
		end)
		it("accepts a miss as a valid shot", function()
			local ok, why = shot({ noTarget = true })
			expect(ok).to.equal(true)
			expect(why).to.equal("Miss")
		end)
		it("refuses fake origins, angles, ranges and rates", function()
			expect(select(2, shot({ origin = Vector3.new(20, 5, 0) }))).to.equal("OriginFar")
			expect(select(2, shot({ direction = Vector3.new(1, 0, 0) }))).to.equal("Angle")
			expect(select(2, shot({ targetPos = Vector3.new(0, 5, -300) }))).to.equal("OutOfRange")
			expect(select(2, shot({ lastShotAt = 9.9 }))).to.equal("TooFast")
			expect((shot({ lastShotAt = 9.82 }))).to.equal(true)
			expect(select(2, shot({ ammo = 0 }))).to.equal("NoAmmo")
		end)
		it("checks the target against the server's rewound position and walls", function()
			expect(select(2, shot({ targetAt = Vector3.new(0, 5, -120) }))).to.equal("TargetFar")
			expect(select(2, shot({ lineOfSight = false }))).to.equal("Blocked")
			expect(select(2, shot({ alive = false }))).to.equal("Dead")
		end)
		it("refuses broken numbers", function()
			expect(select(2, shot({ origin = Vector3.new(0 / 0, 5, 0) }))).to.equal("BadData")
			expect(select(2, shot({ direction = Vector3.new(0, 0, 0) }))).to.equal("BadData")
		end)
	end)
	describe("HitCheck.Damage", function()
		it("falls off to half at max range, head x1.5", function()
			expect(HitCheck.Damage(PISTOL, 40)).to.equal(20)
			expect(HitCheck.Damage(PISTOL, 125)).to.equal(15)
			expect(HitCheck.Damage(PISTOL, 200)).to.equal(10)
			expect(HitCheck.Damage(PISTOL, 40, "Head")).to.equal(30)
		end)
	end)
	describe("HitCheck.Melee", function()
		local FISTS = { range = 5, coneDeg = 90, cooldown = 0.5 }
		local function swing(target, last)
			return HitCheck.Melee(FISTS, {
				attackerPos = Vector3.new(0, 0, 0),
				attackerLook = Vector3.new(0, 0, -1),
				targetPos = target,
				now = 5,
				lastSwingAt = last,
			})
		end
		it("hits in front, in range", function()
			expect((swing(Vector3.new(0, 0, -4)))).to.equal(true)
		end)
		it("refuses behind, too far and too fast", function()
			expect(select(2, swing(Vector3.new(0, 0, 4)))).to.equal("Behind")
			expect(select(2, swing(Vector3.new(0, 0, -9)))).to.equal("OutOfRange")
			expect(select(2, swing(Vector3.new(0, 0, -4), 4.9))).to.equal("TooFast")
		end)
	end)
	describe("HitCheck.History", function()
		it("rewinds a character's position, but not too far back", function()
			local h = HitCheck.History.new(1)
			h:Push(0, Vector3.new(0, 0, 0))
			h:Push(0.1, Vector3.new(10, 0, 0))
			expect(h:At(0.05).X).to.be.near(5)
			expect(h:At(0.2).X).to.equal(10)
			h:Push(1.0, Vector3.new(10, 0, 0))
			expect(h:At(0.5)).to.equal(nil)
			expect(h:At(0.7).X).to.be.near(10)
			expect(HitCheck.History.new(1):At(0)).to.equal(nil)
		end)
	end)
end
