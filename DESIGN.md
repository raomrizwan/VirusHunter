# Virus Hunter 2.0 — Nano Swarm (survivor-style)

Same App Store app (id 6758458388, bundle `com.appspedia.virushunter.VirusHunter`), shipped as version 2.0.
Rebuilt from scratch: SwiftUI shell + SpriteKit arena, no physics engine (manual spatial grid).

## Fantasy
Year 2150. A digital super-virus infected the human body. You are **Nano** — a tiny, brave medical nanobot.
Fly through the body organ by organ, survive the infection waves and destroy the giant mutated strains.

## Core loop (one run = one organ, ~5 min)
1. Drag anywhere = floating joystick. Nano moves; **all weapons fire automatically**.
2. Viruses swarm in from off-screen, growing denser every 30 s.
3. Killed viruses drop **DNA orbs** (XP). Magnet radius pulls them in.
4. Level up → game pauses → **choose 1 of 3 upgrades** (new weapon, weapon level-up, or passive).
5. At 4:00 the **boss** arrives. Kill it → organ cleared → Bio-Coins + next organ unlocked.
6. Die → summary (time, kills, coins). One revive per run (rewarded ad), double coins (rewarded ad).

## First run (new players)
No intro slides: a fresh install drops straight into a Lungs run with a "Drag anywhere to fly" hint.
That first run is tuned to feel strong fast: early levels need half the XP, +25% damage,
and Nano Swarm is the first card on the first level-up. Menus come after the first run.
The result screen shows what the run unlocked and a coin bar towards the next skin or Tech Lab upgrade.

## Hook: Nano Swarm
Signature weapon: **Swarm** — mini nanobots orbit, dart at the nearest virus and return. Each level adds a bot.
At level 5 the swarm is a glowing cloud. It is the thing people screenshot.

## Weapons (max 4 at once, levels 1–5)
| Weapon | Behaviour |
| --- | --- |
| Pulse Laser (start) | bolt at nearest virus; +damage, +bolts, pierce at 5 |
| Nano Swarm | orbiting mini-bots that strike; +1 bot per level |
| Antibody Shield | 2–5 orbs orbit closely, damage + knockback on touch |
| Shock Field | aura around Nano, damages every 0.5 s; radius grows |
| Chain Zap | lightning jumps between 3–7 viruses |
| Cure Bomb | drops pulsing bombs behind you, splash damage |

## Passives (levels 1–5)
Speed, Max HP (+20), Magnet range, Power (+10% damage), Rapid (−8% cooldown), Regen.

## Viruses
- **Spiky** — basic chaser.
- **Blob** — slow, tanky, splits into 2 minis on death.
- **Dart** — pauses, then dashes at you.
- **Spitter** — keeps distance, shoots slime.
- **Mini** — tiny and fast, comes in groups.
Elites (every minute): bigger, glowing ring, drop a chest (free upgrade).

## Organs (stages) — Body Map
1. Lungs (pink alveoli) — boss **Sumo Virus** (slam shockwave)
2. Heart & Blood (red cells) — boss **Cowboy Virus** (dash + bullet ring)
3. Stomach (green acid) — boss **Royal Guard** (summons + shield)
4. Brain (purple neurons) — boss **Mind Leech** (psychic spiral + blink-stomp next to Nano)
5. Bone Marrow — boss **Bone Colossus** (3-wave bone-spear rings, summons blobs, faster under 50%)
   In the final city (Infection Level 10) the Marrow boss is **King Vex**: dashes, 18-shot rings, summons an elite;
   enraged under 50%: triple spiral + teleport stomps. Endless cycles all five regular bosses.

### Weapon evolutions
A weapon at LV 5 plus its partner passive (any level) can be offered as **EVOLVE** (level 6, weighted high):
Laser + Rapid Cooling = Photon Lance, Swarm + Overcharge = Hive Mind, Shield + Nano Armor = Immune Wall,
Field + DNA Magnet = Storm Field, Zap + Turbo Jets = Thunderstorm, Bomb + Self-Repair = Cure Nova.
6. **Endless** (unlocked after stage 2) — survive as long as possible, leaderboard-style best time.
Difficulty scales with stage number.

### Story + outbreak cities
On reaching the menus the player picks a country (default: device region; 12 countries + "World Tour", `Core/World.swift`).
Each country has 10 main cities; city N = Infection Level N. In each city Nano clears the 5 organs of **Patient Zero**;
each organ cures a fifth of the city's infected count, and all 5 save the city and open the next one.
Cast: Nano, **Dr. Leuko** (white blood cell commander), **King Vex** (virus mastermind) — portraits `dr-leuko`, `king-vex` in `Art/art.py`.
Scenes (`Core/Story.swift`): chapter intro before each organ's first run, outro on first clear, "clear-1" after the first city,
an arrival scene per city 2-10 on the map, a finale after city 10, Endless intro. Seen scenes replay from the map's Story journal.

### City mutations, organ hazards, events, bonus objectives
- Cities 2-10 each get one twist (`Core/Mutations.swift`, order shuffled per country, revealed only on arrival): Splitter, Giant,
  Blackout (light circle around Nano), Toxic Ground (puddles), Twin Bosses, Speed, Ghost (invisible until close), Swarm, Armored.
- Organ hazards (not Endless): Lungs wind gusts, Heart heartbeats (viruses sprint), Stomach acid rain, Brain neuron beams, Marrow bone-spike lines.
- Random events: Golden Virus (flees, 15 s, 30 coins, trophy), supply-drop chest, King Vex ambush from city 3 (survive 20 s, +40).
- One bonus objective per run (+60): no damage 45 s, 250 kills by 3:00, boss in 45 s, open 3 chests.

### Boss lineups and special viruses (`Core/Bosses.swift`)
- City 1 plays the classic lineup. Every boss variant has its own art (`boss-<kind>-<variant>`, 25 images from `boss_variant` in Art/art.py). From city 2 on, each city shuffles which boss guards which organ (seeded by country + city) and gives each a different variant: **Frost** (shots chill and slow Nano, ice rings), **Toxic** (leaves puddles), **Inferno** (double fire rings), **Shadow** (turns invisible and faster), **Mega** (1.5x HP, bigger, calls two elites at half health). The HUD shows e.g. "Toxic Sumo Virus". King Vex stays the final boss.
- Four special viruses: **Bomber** (stops next to Nano, 0.8 s fuse, blast also hurts viruses), **Healer** (keeps away, heals nearby viruses 30% every 3 s), **Sniper** (holds 300-380 away, red aim line, then a fast shot), **Spore** (weaving clusters).
- Each organ has a signature special (Lungs Spore, Heart Bomber, Stomach Healer, Brain Sniper, Bone Marrow two random); city 2+ adds a guest special and city 6+ another, picked per country. Endless uses all four.

### City strains, mini bosses, backgrounds, vaccine reports
- **Strains:** from city 2 the six regular viruses wear a city look (Horned, Crystal, Armored, Punk, Cyclops, Zombie, Gold, Ninja, Pirate; `virus-<kind>-<strain>`), shuffled per country. The arena tiles take the strain's color and Dr. Leuko/King Vex mention it on arrival.
- **Mini bosses** at 125 s (every 150 s in Endless), one per organ+city: Brood Queen (lays minis, bursts into spikies), Turret Tick (four rotating streams), Rhino Charger (three charges in a row), Magnet Mite (pulls Nano in, fires spreads). Chest + 16 coins.
- **Backgrounds:** each organ has its own motif (alveoli, blood cells, villi, neurons, bone lattice) and a second infected palette used on even cities (`bg-<organ>-2`), plus drifting parallax cells.
- **Vaccine report:** after every new organ clear Dr. Leuko says what it added to the vaccine and how many people are recovering ("Vaccine 2 of 5"); the fifth clear announces the vaccine and the saved city.

### Virus-pedia, allies, missions, combos, Boss Rush
- **Virus-pedia** (`Core/Pedia.swift`, `PediaView`): 99 cards (10 viruses, 54 strain looks, 4 mini bosses, 6 bosses, 25 boss variants). A card unlocks the first time the character spawns in a run; +10 coins per new card.
- **Allies** (`Core/Allies.swift`, `AlliesView`): Medic Cell (free after the first city, heals 6% every 5 s), Guardian Cell (2,500: clears nearby shots and pushes viruses every 3 s), Hunter Cell (4,000: zaps the nearest virus every 0.8 s). One flies with Nano.
- **Special missions** (`Core/Modes.swift`): from city 2 one organ per city is **Hospital Defense** (60% of viruses go for Patient Zero's bed; bed at 0% = defeat; boss at 2:30), from city 3 another is **Escape** (exit 2,400 away with an edge arrow; no boss, more viruses). King Vex's fight stays normal.
- **Combos:** kills within 1.5 s chain; x25/50/100/200/400 pay 5/10/20/40/80 coins. Boss kills trigger a slow-motion knockout with a camera punch-in.
- **Weekly Boss Rush** (unlocks after the first city): five variant bosses back to back from an ISO-week seeded lineup, four free upgrades at the start; 400 coins for the week's first win, 100 after. Leaderboard `vh.leaderboard.bossrush` (seconds, **lower is better** — set it that way in App Store Connect).

### City rewards (kept secret until earned)
City 1: 1,250 coins · 2: **Freeze Ray** weapon (frost wave, slows; evolves with DNA Magnet into Absolute Zero) · 3: **Frost Nano** skin ·
4: **Homing Missiles** weapon (steer + explode; evolves with Overcharge into Rocket Storm) · 5: **Plasma Nano** skin ·
6-9: 2,500-3,250 coins · 10: **Royal Nano** skin. City-reward weapons stay out of level-ups until earned.

### Trophies
14 in-game trophies with coin rewards (`Core/Trophies.swift`), screen from the Home trophy button; Game Center mirrors them
as `vh.ach.<trophy rawValue>` and the Leaderboards button shows only when signed in.

### Infection Levels (replay)
City N plays every organ at Infection Level N (the city strip on the map selects it; "Next: organ · city" on the win screen).
Each level above 1: enemy health/damage +40% (of the stage value), speed +3%, spawn rate +7%, elites every 60 s → 30 s min (−3 s/level),
clear reward +60%, run coins +15%. The map dot shows the highest level cleared. Endless is unaffected.

## Daily (`Core/Daily.swift`)
Three missions a day (seeded by date: one easy, one medium, one hard, different kinds), 250-700 coins each,
plus a 500-coin chest for all three. Login streak pays 100/150/200/300/400/500/1000 for days 1-7 (missing a day resets).
Home has a "Daily" button with a badge for unclaimed rewards.

## Game Center (`App/GameCenter.swift`)
Silent sign-in on launch; trophy button on Home opens the dashboard. Leaderboards: `vh.leaderboard.endless` (best Endless seconds),
`vh.leaderboard.cities` (cities saved), `vh.leaderboard.kills` (total kills). Achievements: `vh.ach.first_boss`, `first_city`,
`five_cities`, `country_saved`, `evolved`, `streak7`, `endless10` (10 min Endless), `kills10k`. These IDs must exist in App Store Connect.

## Meta — Tech Lab (Bio-Coins)
Permanent upgrades: Power, Armor (−dmg), Max HP, Speed, Magnet, Coin bonus, Revive (one free).
Each 10 levels, rising cost. After MAX, **Mutation Ranks** (up to 50 per tech, not Revive): each rank is worth 0.4 of a level
(Speed 0.2), costing 2000 + 400 per rank, so coins always have a use. Armor stays capped at 50%.

## Nano skins
Classic (free), Neon 250, Toxic 600, Stealth 1200 Bio-Coins; Golden for clearing the Stomach.
Skins recolour Nano and the swarm mini-bots (`Art/art.py` SKINS palettes). Pick them from Home (tap Nano or "Skins").

## Monetization
Free. Rewarded: revive, double coins. Interstitial between runs (from 3rd run, every 2nd, ≥ 90 s apart).
Banner on home screen only (never during play). Remove-ads later.

## Visual direction
- Dark microscope-view arena; organ-tinted backdrop with soft blurred cells drifting (parallax).
- Viruses: glossy, saturated, cute-menacing faces (angry eyes), spikes; neon glow.
- Nano: white round helmet bot, big cyan visor eyes, red cross badge, cyan thrusters (consistent with v1 mascot robot).
- Juice: hit flash, damage numbers, orb trails, screen shake on boss, level-up burst, haptics.
- UI: rounded bold type, glass panels, cyan/magenta accents.
