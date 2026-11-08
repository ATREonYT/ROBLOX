local NEW=[==[
-- Nov 8 fix: the two glyph sheet images never load in Play (AssetFetchStatus Failure), so every
-- live number (Elo, level, progress, Wins, prices) was invisible. Set now draws a real TextLabel
-- in the kit's rounded font with a dark outline, sized from the same design box (BoxW, BoxH,
-- FitSize), so it can never disappear. The glyph table above is kept for GlyphText.Width.
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local OUTLINE = Color3.fromRGB(28, 24, 44)

local function fit(t: TextLabel, host: GuiObject)
	local boxH = host:GetAttribute("BoxH") or 40
	local size = host:GetAttribute("LiveSize") or 32
	local h = host.AbsoluteSize.Y
	if h <= 0 then
		return
	end
	local px = size * h / boxH -- design size -> screen pixels
	local c = t:FindFirstChild("Max") :: UITextSizeConstraint?
	if c then
		c.MaxTextSize = math.max(1, math.floor(px * 1.05 + 0.5))
	end
	local st = t:FindFirstChildOfClass("UIStroke")
	if st then
		st.Thickness = math.max(1, math.floor(px * 5 / 72 + 0.5))
	end
end

function GlyphText.Set(label: GuiObject, text: string, color: Color3?)
	local key = text .. "|" .. tostring(color)
	local old = label:FindFirstChild("Glyphs")
	if old then
		old:Destroy()
	end
	local t: TextLabel
	if label:IsA("TextLabel") then
		t = label
	else
		local found = label:FindFirstChild("LiveText")
		if found and found:IsA("TextLabel") then
			t = found
		else
			t = Instance.new("TextLabel")
			t.Name = "LiveText"
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.ZIndex = label.ZIndex + 1
			t.Parent = label
		end
	end
	label.Visible = true
	if label:GetAttribute("GlyphKey") == key and t.Text == text then
		return
	end
	label:SetAttribute("GlyphKey", key)
	local boxW = label:GetAttribute("BoxW") or 100
	local size = label:GetAttribute("FitSize") or 32
	local width = GlyphText.Width(text, size)
	if width > boxW * 0.96 then
		size = size * boxW * 0.96 / width
	end
	label:SetAttribute("LiveSize", size)
	t.Text = text
	t.RichText = false
	t.FontFace = FONT
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextTransparency = 0
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextWrapped = false
	t.TextScaled = true
	if not t:FindFirstChild("Max") then
		local c = Instance.new("UITextSizeConstraint")
		c.Name = "Max"
		c.Parent = t
	end
	local st = t:FindFirstChildOfClass("UIStroke")
	if not st then
		st = Instance.new("UIStroke")
		st.Parent = t
	end
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Color = OUTLINE
	st.Transparency = 0
	st.Enabled = true
	if not label:GetAttribute("LiveFitHooked") then
		label:SetAttribute("LiveFitHooked", true)
		label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			fit(t, label)
		end)
	end
	fit(t, label)
end

return GlyphText
]==]
local SES=game:GetService("ScriptEditorService")
local CHS=game:GetService("ChangeHistoryService")
local m=game.ReplicatedStorage.ChessEvolutionUI.GlyphText
local bk=game.ServerStorage:FindFirstChild("UIPolishBackup_Nov8") or Instance.new("Folder",game.ServerStorage)
bk.Name="UIPolishBackup_Nov8"
if not bk:FindFirstChild("GlyphText_beforeTextFix") then local c=m:Clone() c.Name="GlyphText_beforeTextFix" c.Parent=bk end
local src=m.Source
local s=src:find("function GlyphText.Set",1,true)
assert(s,"no Set")
local newSrc=src:sub(1,s-1)..NEW
local h=game.StarterPlayer.StarterPlayerScripts.ChessEvolutionHUD
local hs=h.Source
local OLD=[[			local base = d:GetAttribute("FadeBase")
			if base == nil then]]
local REP=[[			local base = d:GetAttribute("FadeBase")
			local liveHost = if d:IsA("UIStroke") then d.Parent else d
			if liveHost and liveHost:IsA("TextLabel") and (liveHost.Name == "LiveText" or liveHost:GetAttribute("GlyphKey") ~= nil) then
				base = 0 -- live text (GlyphText.Set) is always fully shown
			elseif base == nil then]]
local a,b=hs:find(OLD,1,true)
assert(a,"no fade anchor")
if not bk:FindFirstChild("ChessEvolutionHUD_beforeTextFix") then local c=h:Clone() c.Name="ChessEvolutionHUD_beforeTextFix" c.Parent=bk end
local rec=CHS:TryBeginRecording("TextFix")
SES:UpdateSourceAsync(m,function() return newSrc end)
SES:UpdateSourceAsync(h,function() return hs:sub(1,a-1)..REP..hs:sub(b+1) end)
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return "ok "..#newSrc
