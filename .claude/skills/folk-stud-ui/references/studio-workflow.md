# Working through the Roblox Studio tools

These traps were all hit while building this kit.

## Installing

Scripts run through `execute_luau` have reduced permissions. They cannot parent a new script into `ReplicatedStorage` or `StarterPlayerScripts`, and they cannot `require` a ModuleScript that lives there.

1. Create the scripts with `multi_edit`, passing `className`, with a short stub for the first edit:
   - `game.ReplicatedStorage.FolkStudUI` as a `ModuleScript`
   - `game.StarterPlayer.StarterPlayerScripts.<Name>Client` as a `LocalScript`
2. Set the real source through `execute_luau` with `module.Source = [==[ ... ]==]`. It avoids escaping a large file.
3. Build into `StarterGui` from `execute_luau` with `loadstring`, which works where `require` does not:

```lua
local M = loadstring(game.ReplicatedStorage.FolkStudUI.Source)()
M.shop(game.StarterGui, cfg)
```

Instances created this way can be parented to `StarterGui`.

The client script:

```lua
local M = require(game:GetService("ReplicatedStorage"):WaitForChild("FolkStudUI"))
local gui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("FolkShop")
M.live(gui, { buy = function(offerId) end, gift = function(offerId) end })
```

Start a window closed by setting its `Enabled` to false in `StarterGui`, then open it with `M.show(gui, true)`.

## Changing things later

- `Edit` is not available during Play, and Play changes are lost. Check with `get_studio_state`. If someone else is in Play, wait rather than stopping it.
- Patch the live GUI and the module together. Use plain text find and replace on `.Source`, check the result parses with `loadstring`, and only then assign it.
- Never name a child after a property of its parent, such as `Name`: `f.Name` finds the property, not the label. The kit's item card uses `ItemName` for this reason.
- A `TextButton` has its own `Text` property, so `button.Text` returns a string, not a child named Text. Use `FindFirstChild`. The kit names button labels `Label` or `Price` for this reason.

- Studio cannot read files on disk, so paste a patch's text into the `execute_luau` call. Check each old text occurs exactly once before replacing it.
- Output lines about `rbxassetid://203785492` come from outside the kit: nothing in the GUI uses that ID. Ignore them unless the place itself uses it.

## Uploading images

`upload_image` only takes http or https URLs. Serve the folder locally and pass the URLs:

```bash
py -m http.server 8770 --bind 127.0.0.1 --directory "<folder>"
```

Run it in the background, always pass `--directory`, and stop it afterwards. Some ports are refused on Windows, so try another if it exits with a permission error. A new upload can take a moment to load, so check `IsLoaded` after a short wait.

## Testing

- `screen_capture` shows the viewport in Edit and in Play. Crop and enlarge the saved image to inspect text.
- `AbsolutePosition` matches `user_mouse_input` coordinates, but a capture is offset by the top inset, so take click targets from `AbsolutePosition`, not from a capture.
- Run mouse actions as separate calls from reads: move, read the `Pop` scale, press, read again, release.
- Send a click and the capture or read that checks it in separate messages. Sent together, they can run out of order: a capture showed the result of a later click, and a click meant for a row landed after the list had scrolled, so it looked as if the button did nothing.
- Take click targets again after anything scrolls. A row's `AbsolutePosition` moves with the list.
- Do not use a long `task.wait` in client code run through `execute_luau`. It can time out and drop the connection. Keep waits to a couple of seconds, and if someone is in Play, ask or wait instead.
- `InputHoldBegin` does not fire prompts from the tools.
- Moving a character with `PivotTo` from the server can snap back. Move it from the client when testing touch triggers.
- Test a real Play start, not code pasted into a running client, or start up bugs stay hidden.
- Keep a measuring script if you are matching a reference: lay the capture beside the reference at 1:1 and compare edges and sampled colours.
