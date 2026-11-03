---
tags: [miami-trap-life, social, clout, design, research]
updated: 2026-11-03
status: built and installed in Studio Edit; Play test next
---
# CLOUT: the social media hustle (design)

Back to [[00 Master Plan]]. Thread: "Make a social media hustle app". Built Nov 3. Status at the bottom.

## Research (what real creators and other games do)
- **Engagement falls as accounts grow.** Instagram roughly 1.7% (nano) to 0.6-0.7% (macro and mega). TikTok runs about 10% for nano and 7-8% for big accounts. ([Stack Influence](https://stackinfluence.com/the-average-influencer-engagement-rate-in-2025/))
- **Sponsored post pay by tier** (Instagram): $50-250 at 1-10K, $250-1.5K at 10-100K, $1.5-5K at 100-500K, $5-12K at 500K+. The CPM is about $10-30. ([CreatorsJet](https://www.creatorsjet.com/blog/influencer-rates-by-platform-and-follower-count-based-on-12000-campaigns))
- **Courses.** Beginners convert 1-3% of their audience and scaling creators 3-8%. Typical prices are $97-297, with offers going up to $997. ([SamCart](https://www.samcart.com/blog/how-much-money-can-i-make-selling-online-courses-(calculator-real-numbers)))
- **Fake followers** raise the count but never engage. The engagement rate drops, reach doesn't improve, brands treat it as a red flag, and you risk purges. ([Vamp](https://vamp.com/insights/the-real-effects-of-buying-fake-instagram-followers/))
- **The "larp" or hustlebro playbook.** Rent the car, jet or villa, shoot "proof" (sale notifications, edited dashboards) and end every video with "buy my course". ([Marketplace](https://www.marketplace.org/story/2026/07/13/what-is-social-medias-hustlebro-scam), [404 Media](https://www.404media.co/larping-how-influencers-fake-being-rich/))
- **BitLife.** Posting the same thing gets ignored, so variety matters. Followers drop when you stop posting, and buying followers hurts your image. ([Gamer Journalist](https://gamerjournalist.com/how-to-get-a-million-followers-in-bitlife/))

## The loop
1. **Shoot.** Drive your car to one of 15 photo spots on the real map, from the Ends up to the private jet terminal. The phone becomes a viewfinder showing live chips for spot, car in shot, golden hour and trending. Pick a caption (from a fixed list, so nothing needs filtering) and post.
2. **Roll-out.** Views, likes and comments count up over about 75 s. Most posts are normal, about 14% pop (x1.8-3.5), about 3.5-12% go viral (x6-22) and about 12% flop. The server credits followers immediately and the client only animates the counters.
3. **What makes a post good.** Spot score (0.7-2.0), light (golden hour, neon at night), car flex, framing, collab with other players nearby (+15% each), a new spot today, today's trend (x1.6) and verified. Posting too often (fatigue) or repeating a spot cuts reach.
4. **Money ladder.**
   - **Creator Fund** at 1K: $1.2 per 1K views.
   - **Brand deals** at 1K: 3 offers a day. Post at the brand's spot to get paid. Pay is $60 x (followers/1K)^0.7 x mood x engagement, which gives about $60 at 1K, $300 at 10K, $1.5K at 100K and $7.5K at 1M.
   - **Courses** at 10K followers and Level 12. You record them at the desk computer, which needs power. Six topics and four price tiers ($27-$997). Sales ping in through the day, are paid at once, and the platform keeps 10%.
5. **Daily swing.** Each in-game day rolls a new market at Morning:
   - algorithm mood x0.7-1.4
   - a trending spot and format
   - each course niche's demand as a random walk between 0.4 and 1.9
   - course novelty that decays with each day since launch
   - 0.6% churn on days you don't post
   
   So income is different every day and grows with the following.
6. **Bots.** You can buy 1K, 10K or 100K bots. They raise the count and add a little social proof, but they don't buy courses, they drag engagement down, and brands cut pay above a 30% bot share and stop offering above 60%. There's a 30% chance each day of a purge that removes 40-80% of them.
7. **2x.** All cash goes through `EconomyService.addCash` and all XP through `addXP`, so the 2x passes and boosts apply. XP comes from every post, new spots, viral posts, milestones, deals and course launches.
8. **Where it lives.**
   - **Phone app "Clout":** feed, shoot, profile, deals.
   - **Desk computer browser (clout.com):** the same app in a wide layout, plus Creator Studio (courses, analytics charts, bot shop).
   - The feed mixes real players in the server (like, follow; a player's follow is worth 25) with NPC creators.
   - Other players see a post drawn from the spot palette, the car model and the poster's avatar thumbnail. The poster sees their real screenshot.

## Files (built)
- `Config/Social.lua`: every number (spots, formats, captions, deals, courses, bots, NPC creators).
- `Rules/SocialRules.lua`: pure maths (post outcome, quality, market, deal pay, course sales). Tested by `tools/tests/test_social_rules.py` (unit checks + a balance sim, 0 failures).
- `Services/SocialService.lua`: posts, feed (players + NPC creators), deals, courses, daily market, bots, leaderboard, offline sales.
- `UI/CloutArt.lua`: draws a post picture for other players (spot palette, scenery, the real car model, the poster's avatar).
- `Apps/Clout.lua` (phone) and `Controllers/OS/Apps/Clout.lua` (desk computer, wide layout).
- Shared additions: Net `SocialState`/`SocialAction`, save `Social`, Main boot line, `Config/Phone` app entry, Theme glyph and colour, 3 `Config/Earn` hustles, `Config/OS` Clout entry, manifest.

## Balance (from the sim)
- Median player: 1K followers in 0.4 h of posting, 10K in 1.6 h, 100K in 6.5 h, 1M in 20 h.
- About $10K per 28-minute in-game day at about 100K followers once courses are live. Day-to-day income swings about 28%.
- Changed from the first draft: deals $150 -> $60 base (power 0.7), course sales rate 0.0014 -> 0.0003, fatigue starts after 3 posts in 10 minutes.

## Status
Nov 3: all six modules and the shared additions installed in Studio Edit. Next: Play test (unlock, shoot and post, result, feed, deals, desk studio, course sales via `MTL_Debug:Invoke("Social","debug",p,"followers",12000)`), screenshots, fixes.
