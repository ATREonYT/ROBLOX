# Hood Jobs: card swiping, the cook-up, the chop list (design, Nov 3 2026)

Back to [[00 Master Plan]]. Owner: the crime loop thread. Alex (Nov 2): "add different jobs to the game such as card swiping, making drugs (obv. make it not say drugs in the game)... hot wiring cars and stealing them, bringing them to a location and getting cash for it... search other games for these jobs... research what even are these jobs in real life... make it good, like really good."

These three sit on top of the crime loop that already exists (Config/Crime.lua, CrimeService, CrimeJobs, PoliceService). They use the same building blocks: dirty cash, 1-3 star heat, Marcus's shop, JobMinigames, ActionPose loops, WaypointService. Every job is split into **stages in different parts of the map**, so a full cycle makes the player cross the city (Alex: "making people move around so its not boring").

## What the references do (and what we take)

| Source | What it does | What we take |
|---|---|---|
| Tha Bronx 3 / South Bronx (Roblox hood RP) | Card "swiping": buy a card reader + blank cards, swipe at ATMs or stores for random cash; robbing and cooking are the top earners. Very fast, mostly one prompt per step. | The fantasy players already know and search for. We make each step a real minigame instead of a single prompt. |
| GTA Online, Exotic Exports (Los Santos Tuners) | A **daily board** of 10 wanted cars. Cars spawn around the map, get marked when you are near, deliver to the docks for a fixed fee, bonus for the full list. [gtabase](https://www.gtabase.com/gta-online/jobs/exotic-exports) | Smoke's daily chop list at A1 Tires, marked when close, full-list bonus. |
| GTA V hot-wire / GTA IV hotwire | Break in, a short "hotwiring" pause under the dash, then drive. | The under-dash moment, but as a real wire-matching minigame with sparks. |
| FiveM "labs" (cfx.re forum scripts such as KVL Chemicals, Ultimate Moonshining, meth labs) | Multi-step production: gather inputs, keep temperature in a band, events (smoke, boil-over, explosions), quality from the minigames sets the price. [forum.cfx.re](https://forum.cfx.re/t/ultimate-moonshining-multi-recipes-smoke-explosions-minigame-based-rewards-saved-objects/5008793) | Supplies run, a heat-band cook with events, quality % to price, then street sales. |
| Real life, skimming (public consumer-protection info) | An overlay reader is fitted over a card slot on an ATM or pump; data is copied onto blank cards; the clones are used to buy resellable goods like gift cards and electronics. | The three stages: plant, clone, cash out. Shown at a high level only, no real technique. |
| Real life, car theft | Older cars: forced lock + column; newer: relay/key tricks; stolen cars go to chop shops for parts or out by container. | Old/new car tiers with different tools, chop shop vs. port container drop. |

## Rules for all three
- **Story bible:** the victims are Royce's operation (his ATM route, his collector's lots, his corners) or faceless big-box stores at Bayside Mall. Never Patel, never a mom-and-pop shop.
- **No drug words in game.** The product is a made-up banned candy, "Glo" (glowing blue rock candy). It looks like the real thing in the genre (crystals, trays, baggies, a scale) but every label, text and NPC line says candy/Glo/"the blue". Keeps Roblox moderation safe.
- **Dirty cash** from every stage, washed at Benny's laundromat. Half drops on death.
- **2x XP** applies (EconomyService.addXP already doubles).
- **Unlock order:** Card swiping L8, Cook-up L10, Chop list L7 (after Car boost).

---

## 1. Card swiping ("Plastic")
Tools from Marcus: **Skimmer** ($600, fits over a card slot), **Encoder kit** ($900, laptop + reader), **Blank cards** ($15 each, pack of 10).

**Stage A: plant it (map: Royce's ATM route: Sunshine Gas, Sudz Car Wash, Liberty Park).**
- Walk up to an ATM with the Skimmer. Minigame **"Fit the overlay"**: the slot outline is shown close-up; move the overlay to line up (mouse/stick), then hold to press it home. A **Watch** meter fills while NPCs or players look at you; full = someone calls it in (1 star).
- Then leave. NPC customers use the ATM over 3-4 real minutes; your phone shows "Reads: 4…5…6".
- Come back to pull it. Late (over 8 min) = Royce's tech finds it: skimmer lost.
- Animation: crouch + Pry loop while fitting, Grab to pull.

**Stage B: clone (map: your apartment desk computer, or the Encoder laptop in your car).**
- Minigame **"Swipe speed"**: swipe each blank through the reader at the right speed (a band on a bar, like a real card reader that rejects too fast or too slow). Good swipe = one clone with a random limit ($80-$400). Bad = "BAD READ" beep, retry costs time.
- Number of clones = reads from Stage A.

**Stage C: cash out (map: Bayside Mall, big-box electronics + gift-card rack).**
- At the register, pick an item (gift cards, earbuds, a game console). Minigame **"Keep your cool"**: the clerk looks up; a nerve meter wobbles and you hold it in the middle while the card "processes". Declined cards happen (25%). After a decline you can **Try again** or **Walk**. A third decline in one store = the clerk calls (1 star).
- Goods go in a bag on your back (carry), then to Marcus's fence for dirty cash (70% of value).

Pay: about $1,800-3,500 per full cycle (8-10 min). Heat low but stacks.

## 2. The cook-up ("Glo")
Tools from Marcus: **Respirator** ($250) and the key to the **trap kitchen** (abandoned house, HoodWest, $1,500 one-time).

**Stage A: supplies run (three stops, each legal on its own, so anyone can buy them):**
- Sugar base: Liberty Food Mart (Patel sells it like any shopper, no crime here).
- Blue colour + "fizz" powder: the beauty supply in Wynwood.
- Pots and trays: the hardware aisle at Bayside Mall.
- Carry box pose (Hug) between stops. Hold too much in the car = a traffic stop can find it.

**Stage B: cook (trap kitchen).** Interior: boarded windows, stained stove, box fan, foil on the windows, blue-stained counters. Respirator goes on (face accessory).
1. **Melt** - a heat dial; keep the needle inside the green band for 20 s while stirring (hold + circle). Too hot = boil-over (smoke fills the room, lose quality); too cold = it seizes.
2. **Colour** - pour the blue at the right moment (timing ring).
3. **Pour + set** - pour into trays (hold), wait 30 s; meanwhile a random event: **smoke** (open the window: prompt), **neighbour knocks** (stay quiet: hold still), **pot catches** (fire extinguisher prompt).
4. **Break + bag** - Hammer loop to break the slab, then Count loop at the scale to bag it. Quality % (0-100) from all steps sets price per bag (Low/Clean/"Pure Glo").

**Stage C: sell (corners at night across the map: Wynwood walls, Habana park, PortSol strip).**
- Phone orders from NPC buyers with a pin; walk up, hand-to-hand (both play Grab). Some are **undercover** (tell: brand-new shoes, earpiece glint); selling to one = 2 stars.
- Or sell the whole batch to Royce's guy at a discount (no risk, 55%).

Pay: about $2,500-6,000 per batch (12-15 min with sales). Biggest earner before heists.

## 3. Hot-wire + chop list ("Smoke's list")
Builds on Car boost. Tools: **Slim Jim** (already sold), **Wire kit** ($350: strippers, tape), **Relay box** ($2,500, L14: for new cars).

**The board:** a chalkboard at A1 Tires lists 5 wanted cars each in-game day (make, colour, tier). The full list pays a $3,000 bonus.

**Find:** list cars spawn parked around the whole map (street parking, lots, mansions on the islands). Within 60 studs your phone pings "That's one on the list".

**Get in:**
- Old cars: slim jim minigame (exists: lock timing).
- New cars (L14): relay box, hold near the owner's house door for 10 s while a signal bar fills.
- Alarm chance 40%: 1 star unless you get the engine going within 8 s.

**Hot-wire (old cars):** camera drops under the dash. Minigame **"Column"**:
1. Pry the column cover (Pry loop, 2 hits).
2. A wire bundle shows 6 wires; the board card says which colours are battery / ignition / starter for this make. Click the battery and ignition wires to strip and twist them (hold).
3. Touch the starter wire: timing ring, spark sound; hit it in the green window to crank (Crank loop). Miss = sparks + a small shock (screen shake), try again.

**Deliver:** drive to A1 Tires (chop: fixed pay minus damage) or, for exotics, the Port container (more pay, longer drive, and some carry a **GPS tracker**: police follow until you stop at Liberty Auto Body to pull it, 20 s).

Pay: $600-2,200 per car by tier, minus damage (existing CarBoost damage rule).

---

## Map spread (one full loop of each crosses at least two districts)
| Job | Stage A | Stage B | Stage C |
|---|---|---|---|
| Card swiping | Hood ATMs (Gas, Car wash, Park) | Your apartment (Ends) | Bayside Mall |
| Cook-up | Food Mart, Wynwood, Bayside Mall | Trap kitchen (HoodWest) | Corners: Wynwood, Habana, PortSol |
| Chop list | Anywhere on the map | Under the dash | A1 Tires or the Port |

## Build order
1. Chop list (smallest step from Car boost, most TikTok-able: under-dash sparks + police chase).
2. Card swiping (needs the mall store + apartment computer hook from the computer thread).
3. Cook-up (needs the trap kitchen interior + new ActionPose loops: Stir, Pour; ask the quality thread).
