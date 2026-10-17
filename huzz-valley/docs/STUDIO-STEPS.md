# Uploading the pictures and sounds, and recording a test

You don't need to draw or make anything. The pictures and sounds are already made and inside the game file.
Roblox only shows pictures and sounds that you upload from your own account, so these steps do that once.

Each part takes about 2 to 5 minutes. If you see **red text** in Output at any point, take a screenshot and send it
to Claude.

---

## Before you start: get the newest version

1. Open **GitHub Desktop**.
2. At the top, check the middle button, **Current branch**. It should say **HUZZ-VALLEY**. If it doesn't, click it
   and pick HUZZ-VALLEY.
3. Click **Fetch origin** at the top right. If it changes to **Pull origin**, click it again.
4. Download the newest game file:
   [HuzzValley-yours.rbxl](https://github.com/atreonyt/roblox/raw/HUZZ-VALLEY/huzz-valley/places/HuzzValley-yours.rbxl).
   It goes into your **Downloads** folder.
5. Double-click **HuzzValley-yours.rbxl** in Downloads. It opens in Roblox Studio.

**Don't press Play** for parts 1 and 2. They only work while you're editing.

---

## Part 1: upload the pictures

### 1a. Turn on picture uploads (one time only)
1. In Studio, click the **Home** tab at the top.
2. Click **Game Settings**. If the game asks to be published first, click **Publish** and pick your game or make a
   new one.
3. On the left, click **Security**.
4. Turn on **Allow Mesh / Image APIs**.
5. Click **Save** at the bottom right.

### 1b. Open the two windows you need
1. Click the **View** tab at the top. In newer Studio it's called **Window**.
2. Click **Output**. A window opens at the bottom with messages.
3. Click **Command Bar**. A thin bar opens at the very bottom of Studio.

### 1c. Run the uploader
1. Click inside the **Command Bar**.
2. Copy this line and paste it with **Cmd+V**:

   ```
   require(game.ServerStorage.HuzzStudioTools.UploadPictures)()
   ```

3. Press **Enter**.
4. Watch **Output**. You'll see lines like `[Huzz] uploaded Fx/Ring -> rbxassetid://...`.
5. Wait for the line `[Huzz] Done: ...`. This takes about a minute or two.

### 1d. Save and send
1. Press **Cmd+S** to save the place.
2. Take a screenshot of the Output window. Press **Cmd+Shift+4** and drag over it.
3. Send Claude the IDs:
   - On the right, in **Explorer**, open **ReplicatedStorage > Shared > Config**.
   - Double-click **ImageIds**. A script tab opens.
   - Press **Cmd+A**, then **Cmd+C**, and paste it into the chat with Claude.

   Claude needs this text. Otherwise the next game file Claude builds won't have your pictures.

New pictures can stay grey for a few minutes while Roblox checks them. That's normal.

---

## Part 2: upload the sounds

### 2a. Find the sound files on your Mac
1. In **GitHub Desktop**, click **Repository** in the menu bar, then **Show in Finder**.
2. In Finder, open **huzz-valley**, then **assets**, then **sfx**. There are 37 files ending in `.ogg`, such as
   `ui_click.ogg` and `secret_impact.ogg`.

### 2b. Import them into Studio
1. In Studio, click **View** (or **Window**) at the top, then **Asset Manager**.
2. In Asset Manager, click **Bulk Import**. It's the button with an up arrow.
3. In the file window, go to the **sfx** folder from step 2a.
4. Select every file with **Cmd+A** and click **Open**.
5. Wait until they all finish uploading.

### 2c. Put them in the game so the helper can find them
1. In **Asset Manager**, double-click the **Audio** folder.
2. Click one sound, then press **Cmd+A** to select them all.
3. Drag them onto the 3D view. They land in **Workspace**.

### 2d. Run the sound helper
1. Click inside the **Command Bar** again.
2. Paste this line and press **Enter**:

   ```
   require(game.ServerStorage.HuzzStudioTools.CollectSoundIds)()
   ```

3. **Output** prints lines starting with `[HuzzSfx]`.
4. Select those lines in Output (click the first, then Shift+click the last). Copy them with **Cmd+C** and paste
   them to Claude.
5. You can now delete the sounds you dragged into Workspace. Claude puts the IDs into the game.

---

## Part 3: record a test video

### 3a. Make the Secret girl appear (for testing)
1. In **Explorer**, open **ReplicatedStorage > Shared > Config**.
2. Double-click **Round**.
3. Press **Cmd+F** and search for `StudioTestRarity`.
4. Change `StudioTestRarity = ""` to `StudioTestRarity = "Secret"`. Keep the quote marks.

This only works in Studio. Real players still get normal odds.

### 3b. Record
1. Press **Cmd+Shift+5** on your Mac. A small bar appears at the bottom of the screen.
2. Click **Record Entire Screen**, then **Record**.
3. In Studio, click **Play** (top, Home tab).
4. Play one round. Vote, watch the girl get picked (the Secret cutscene plays), and run across.
5. If you can, also win a round wearing **Crown Pose** and an aura from **Shop > Items**.
6. Click the stop button in the Mac's menu bar at the top right. The video appears on your desktop.
7. Send the video to Claude.

When you're done testing, set `StudioTestRarity` back to `""`.

---

## If something goes wrong
- **"ServerStorage.HuzzStudioTools is not a valid member"**: you're in an older game file. Download the newest one
  (see "Before you start").
- **"Allow Mesh / Image APIs" or "EditableImage" in red**: do step 1a again and make sure you clicked **Save**.
- **Anything else in red**: send Claude a screenshot.
