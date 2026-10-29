---
tags: [roblox, ui, cartoony, juice, video-library]
updated: 2026-10-29
---

# 14 Cartoony UI & Juice

Back to [[00 Start Here]] · AI side: [[07 UI & GUI]] · Checklist: [[16 Cartoony Kid-Appeal Checklist]]

Kids judge a game in seconds, and the UI is half of that. Front-page UI looks like **pressable toys**: thick outlines, a lit top, a darker lip, hard shadows and bounce on every press. The vault's written rules (token sheet, sizes, colors) are in `reports/Cartoony Roblox building UI and animation.md` under "Sticker UI beats template UI".

## Designing the art (Figma)

### ⭐ The Greatest Cartoony UI Tutorial on Roblox (w/ Figma)
- **Creator:** Kek · **Date:** 2026-02-25 · **Views:** 82K
- **Link:** https://www.youtube.com/watch?v=z16zs2v-FNI
- **Why watch:** The best single video for front-page simulator UI.
- **Key takeaways:** Step by step through the main frame, search bar, pet frames, buttons, close button and header, plus a fixes pass.

### How To Make Simulator UI Buttons In Figma
- **Creator:** voidryxUI · **Date:** 2026-09-08
- **Link:** https://www.youtube.com/watch?v=k69tudey-vs
- **Key takeaways:** One reusable simulator button style you can apply everywhere.

### Unverified (page didn't load) but on-topic
- [Simple Tutorial for Cartoony UI using FIGMA (Roblox)](https://www.youtube.com/watch?v=HTkaJZnojuw)
- [ROBLOX GLOSSY Cartoon Style Game UI Buttons](https://www.youtube.com/watch?v=hYflSkt6XYU)
- [How To Make Cartoon Game Store UI Tutorial (Roblox)](https://www.youtube.com/watch?v=qSOJroDmeNo)

## Making it feel alive (tweens, shine, bounce)

### ⭐ How To Make Shiny UI Buttons That Pop!
- **Creator:** Rileybytes · **Date:** 2024-11-03 · **Views:** 67K
- **Link:** https://www.youtube.com/watch?v=8F3oW_Z6ffE
- **Key takeaways:** An animated shine sweep across buttons: a shine image plus a short script.

### Make Your Roblox UI Buttons SUPER Smooth in 8 Minutes!
- **Creator:** PineappleDev · **Date:** 2025-03-03
- **Link:** https://www.youtube.com/watch?v=2z4rebjBnQA
- **Key takeaways:** Grow on hover, shrink back on leave. Code is on Pastebin.

### More (unverified)
- [Make SMOOTH UI Animations in Roblox Studio](https://www.youtube.com/watch?v=pnDkIlTdfPM)
- [Roblox Studio GUI Animation Trick That Gets More Clicks](https://www.youtube.com/watch?v=wjszqzBxMbs)

## Game feel outside the UI
- [Make Game Impacts Feel JUICY (Camera Shake + Sound)](https://www.youtube.com/watch?v=z0-jU6cyYMM), SpeedTutor, 2026-09-04. This is **Unity**, but the principle carries over directly: every hit gets a shake + sound + flash on the same frame.
- The vault's `GAME-FEEL.md` and `VFX-ITEMS.md` hold the Roblox-specific rules.

## Prompt for Claude when building UI
> Build this screen as sticker/toy UI: opaque colored panels (no dark translucent glass), a 3–4 px dark outline (UIStroke) on everything, a lit top / darker bottom lip on buttons, a hard drop shadow, a chunky rounded font, one dominant yellow call-to-action, green = confirm, red = close. Every button scales down on press and bounces back (TweenService, Back easing). No emoji icons.
