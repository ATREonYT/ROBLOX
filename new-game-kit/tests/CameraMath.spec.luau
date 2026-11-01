--!nonstrict
-- New Game Kit spec: CameraMath (vault note 28).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraMath = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("CameraMath"))

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

return function()
	describe("CameraMath", function()
		it("smooths the same at 30 and 240 fps", function()
			local function settle(fps)
				local x = 0
				for _ = 1, fps do -- one second
					x += (1 - x) * CameraMath.Damp(0.2, 1 / fps)
				end
				return x
			end
			expect(near(settle(30), settle(240), 1e-6)).to.equal(true)
			expect(near(CameraMath.Damp(0.2, 0.2), 0.5)).to.equal(false) -- dt is clamped to 0.1
			expect(near(CameraMath.Damp(0.1, 0.1), 0.5)).to.equal(true)
		end)
		it("places a side-on camera to show the wanted height", function()
			local d = CameraMath.SideOnDistance(40, 70)
			expect(near(2 * d * math.tan(math.rad(35)), 40, 1e-6)).to.equal(true)
		end)
		it("keeps one FOV owner inside the caps", function()
			expect(CameraMath.FovStack(70, {})).to.equal(70)
			expect(CameraMath.FovStack(70, { sprint = 8, boost = 9 })).to.equal(82)
			expect(CameraMath.FovStack(70, { punch = -50 })).to.equal(35)
			expect(CameraMath.FovStack(70, { sprint = 5, zoom = -10 })).to.equal(65)
			expect(CameraMath.FovStack(70, { boost = 12 }, { reduced = true })).to.equal(76)
		end)
		it("lets trauma die out in under a second after a rare shot", function()
			expect(CameraMath.Trauma(0.4, nil, 0)).to.equal(0.4)
			expect(CameraMath.Trauma(0.4, nil, 0.4)).to.equal(0)
			expect(CameraMath.Trauma(2, 1, 0.5)).to.equal(0.5)
		end)
		it("turns shake off for Reduced Motion and scales it by zoom and setting", function()
			expect(CameraMath.ShakeScale(70, 1, true)).to.equal(0)
			expect(near(CameraMath.ShakeScale(70, 1, false), 1)).to.equal(true)
			expect(CameraMath.ShakeScale(30, 1) < 1).to.equal(true)
			expect(near(CameraMath.ShakeScale(70, 0.5), 0.5)).to.equal(true)
		end)
		it("gives whole-pixel letterbox bars", function()
			expect(CameraMath.Letterbox(1080)).to.equal(86)
			expect(CameraMath.Letterbox(667)).to.equal(53)
		end)
	end)
end
