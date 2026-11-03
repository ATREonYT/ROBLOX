# Florida Reference Analysis (other Florida RP games)

The screenshots are in `References/Florida`. They show the "safe Florida suburb / commercial strip" look. Pair this with [[Larp Reference Analysis]] for the hood.

## What makes it read as Florida
- **Grass verges everywhere.** Curb, then a 4–6 stud lawn strip, then the sidewalk, then more lawn. Palms are planted *in* the verge at a steady rhythm.
- **Wide, calm arterials.** Dark clean asphalt with white dashed lane lines, a yellow edge line on the left and painted turn arrows. Very few patches.
- **Twin shoebox lights.** Tall square white poles with two flat box heads, on the street and in every parking lot. Decorative lantern posts are used at community entrances.
- **Parking lots are designed.**
  - Stalls are painted white, with direction arrows.
  - Landscaped islands sit at the end of every row: a concrete curb, red/brown mulch, ornamental grasses, low shrubs and one palm.
  - Some lots are brick-red pavers.
- **Buildings are calm and low.** One or two storeys, cream or salmon stucco, brown hip roofs.
  - Arched entries with stone-clad piers; dark window grids with white trim.
  - Small cupolas and towers on civic and community buildings.
  - Car dealerships have big glass fronts and a coloured entry portal.
- **Gated communities.**
  - Stucco entrance monuments with a stone base and a script name plaque.
  - Planters with palms, a flagpole and uplights.
  - Green street-name blades on the signal mast.
- **Gas stations.** A striped brand canopy on dark columns, pump islands, an LED price pylon (red frame, green and red digits), and a stucco c-store with a hip roof.
- **Trees.** Big broadleaf shade trees mixed with tall coconut and royal palms. Dense hedges.
- **Mood.** Overcast or soft light, desaturated greens, no harsh contrast.

## Applied in Vice Bay
- **Roads (`Roads.lua`):**
  - HAB, HABA and BLVD (and the county RES streets) now have lawn verges with a concrete edge. Verges stop 10 studs short of each corner so the crossings stay paved.
  - Palms sit in the verge.
  - Twin shoebox street lights (`L.streetlight(..., shoebox)`) on those styles.
- **Mangrove Bay and the villa estates (`Villa.lua`, `17_mangrove.lua`):**
  - Lots are open: no side walls or street walls, just scattered shrubs and a curbside mailbox.
  - Mangroves were thinned out so the waterfront is open and boats can reach it easily.
- **Backlog from this set:**
  - Parking-lot kit with mulch islands
  - Gated-community entrance monuments
  - Florida gas station (striped canopy + LED pylon)
  - Stucco commercial strip buildings
  - Curved crescent and cul-de-sac street patterns in the suburbs
  - A diagonal avenue and a roundabout to break up the grid
