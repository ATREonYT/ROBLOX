-- ArtWindows (brief 30, MOCKUP): where the user's artboard panels (Shared/ShoeScreens) open, shared by every client script
-- that shows one (Shoes.client: the box browser, the drops, the reveal, Inventory Full; Inventory.client: the inventory,
-- the pair's detail, the collection, the confirmations; Store.client: the bundle, the gift picker, Bundle received). Client
-- only. One ScreenGui ('HoodArt', DisplayOrder 11: over the Store, the HUD's windows and the unboxing's words) with two layers:
--   window   one at a time across every script: PlayerGui's HoodWindow names it (the Store, the inventory and the HUD's
--            windows set it too, and a window whose name it no longer holds closes); the world blurs, the HUD steps aside
--   dialog   over whatever is open (a window here, the Store, nothing) without touching HoodWindow: confirmations,
--            reviews, the reveal card; a full-screen dim under it stops taps reaching what is behind
--   ArtWindows.open(name, build) -> handle      build(root) returns a ShoeScreens handle ({ P = panel, refresh })
--   ArtWindows.dialog(name, build, opts) -> handle   opts.dim (0.45), opts.tapOut (a tap beside it closes it)
--   ArtWindows.close() / closeDialog(name?) / current() -> name, handle / dialogName() -> name
--   ArtWindows.refresh()                        repaints the open window and dialog (after a state change)
-- Each panel is fitted to the screen (ArtKit.fit: the phone floor scrolls rather than shrinks text) and pops in.
local Players = game:GetService('Players')
local Shared = script.Parent
local A = require(Shared.ArtKit)
local Motion = require(Shared.UIMotion)
local Kit = require(Shared.UIKit)

local ArtWindows = {}
local player = Players.LocalPlayer
local playerGui = player and player:WaitForChild('PlayerGui')
local gui, root, winLayer, dlgLayer
local win, dlg -- { Name, Handle, Holder }

local InventoryKit
do
	local node = Shared:FindFirstChild('InventoryKit')
	local ok, m = pcall(function() return node and require(node) end)
	InventoryKit = ok and type(m) == 'table' and m or nil
end
local function cover(on) if InventoryKit and InventoryKit.coverPlayerList then pcall(InventoryKit.coverPlayerList, 'Art', on) end end

local function fitOne(entry)
	if not entry or not gui then return end
	local abs = gui.AbsoluteSize
	local P = entry.Handle and entry.Handle.P
	if P and P.Fit then A.fit(P, abs) end
end
local function relayout()
	fitOne(win)
	fitOne(dlg)
end
function ArtWindows.root()
	if not gui then
		gui = Kit.new('ScreenGui', { Name = 'HoodArt', ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, DisplayOrder = 11 })
		root = A.frame(gui, { Name = 'ArtRoot', Box = UDim2.fromScale(1, 1), Z = 1 })
		winLayer = A.frame(root, { Name = 'Window', Box = UDim2.fromScale(1, 1), Z = 10 })
		dlgLayer = A.frame(root, { Name = 'Dialog', Box = UDim2.fromScale(1, 1), Z = 50 })
		gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
		gui.Parent = playerGui
	end
	return root, gui
end

-- (Oct 27, round 7, OUR_UI_AUDIT C1: no picture pops in after a window opens) a new panel waits, scaled to nothing,
-- until the pictures it shows are drawn (Shared/ImageLoader.prepare, at most 0.35 s), then pops in.
local function reveal(entry)
	local P = entry.Handle and entry.Handle.P
	if not P then return end
	local s = Motion.scaleOf(P.Panel)
	local held = false
	local ready = Kit.ImageLoader.prepare(entry.Holder, 0.35, function()
		if held and entry.Holder.Parent then A.popIn(P) end
	end)
	if ready then
		A.popIn(P)
	else
		held = true
		s.Scale = 0
	end
end
local function build(layer, name, builder, dim, tapOut, onTap)
	local holder = A.frame(layer, { Name = name, Box = UDim2.fromScale(1, 1), Z = layer.ZIndex })
	-- (brief 30) the dim sits under everything the builder puts in the holder (siblings order by ZIndex), so a window
	-- built at a lower Z than its layer never ends up behind its own dim
	A.dim(holder, 0, tapOut and onTap or nil, dim or 0.45)
	local ok, handle = pcall(builder, holder)
	if not ok then
		warn('[ArtWindows] ' .. name .. ': ' .. tostring(handle))
		holder:Destroy()
		return nil
	end
	return { Name = name, Handle = handle, Holder = holder }
end

function ArtWindows.close()
	if not win then return end
	local w = win
	win = nil
	w.Holder:Destroy()
	Motion.blur('Art', false)
	cover(false)
	if w.Handle and w.Handle.Closed then pcall(w.Handle.Closed) end
	if playerGui and playerGui:GetAttribute('HoodWindow') == w.Name then playerGui:SetAttribute('HoodWindow', '') end
end
function ArtWindows.closeDialog(name)
	if not dlg or (name and dlg.Name ~= name) then return end
	local d = dlg
	dlg = nil
	d.Holder:Destroy()
	if d.Handle and d.Handle.Closed then pcall(d.Handle.Closed) end
	if not win then Motion.blur('ArtDialog', false) end
end
function ArtWindows.open(name, builder)
	ArtWindows.root()
	ArtWindows.closeDialog()
	if win then
		local old = win
		win = nil
		old.Holder:Destroy()
	end
	local entry = build(winLayer, name, builder, 0.35, true, function() ArtWindows.close() end)
	if not entry then return nil end
	win = entry
	if playerGui then playerGui:SetAttribute('HoodWindow', name) end
	Motion.blur('Art', true)
	cover(true)
	fitOne(entry)
	reveal(entry)
	return entry.Handle
end
function ArtWindows.dialog(name, builder, opts)
	opts = opts or {}
	ArtWindows.root()
	ArtWindows.closeDialog()
	local entry = build(dlgLayer, name, builder, opts.dim, opts.tapOut, function() ArtWindows.closeDialog(name) end)
	if not entry then return nil end
	dlg = entry
	if not win then Motion.blur('ArtDialog', opts.blur ~= false) end
	fitOne(entry)
	reveal(entry)
	return entry.Handle
end
function ArtWindows.current() return win and win.Name, win and win.Handle end
function ArtWindows.dialogName() return dlg and dlg.Name end
function ArtWindows.refresh()
	for _, e in { win, dlg } do
		if e and e.Handle and e.Handle.refresh then
			local ok, err = pcall(e.Handle.refresh)
			if not ok then warn('[ArtWindows] refresh ' .. e.Name .. ': ' .. tostring(err)) end
		end
	end
end
-- (the HUD's buttons and the other windows: another window took HoodWindow, so this one goes)
if playerGui then
	playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
		if win and playerGui:GetAttribute('HoodWindow') ~= win.Name then ArtWindows.close() end
	end)
end

return ArtWindows
