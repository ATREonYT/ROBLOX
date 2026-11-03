--!strict
-- Something to buy in the first minute (research P0-6: "$50 with nothing to spend it on teaches money doesn't matter").
-- A small hat-and-chain stand just inside Liberty Food Mart's door. Cheap, and you see it on yourself straight away.
-- Items are Creator Marketplace accessories (same verified ids as Config/Outfits). Bought once, saved, worn on every
-- spawn; press the prompt again to take it off / put it back on. One hat at a time.
local StarterShop = {}

-- world position of the stand (floor point) and the way its front faces (into the store = +Z)
StarterShop.Stand = { At = Vector3.new(-1450, 3, -321.6), Face = Vector3.new(0, 0, 1) }

StarterShop.Items = {
	{ id = "Durag", title = "Black Durag", price = 15, slot = "Hat", asset = 136235011069192 },
	{ id = "Cap", title = "Liberty Cap", price = 25, slot = "Hat", asset = 129057054940664 },
	{ id = "Chain", title = "Gold Chain", price = 40, slot = "Neck", asset = 100390764800210 },
}

return StarterShop
