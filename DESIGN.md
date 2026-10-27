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
4. Brain (purple neurons) — boss **Sumo** v2
5. Bone Marrow — boss **Cowboy** v2
6. **Endless** (unlocked after stage 2) — survive as long as possible, leaderboard-style best time.
Difficulty scales with stage number.

## Meta — Tech Lab (Bio-Coins)
Permanent upgrades: Power, Armor (−dmg), Max HP, Speed, Magnet, Coin bonus, Revive (one free).
Each 10 levels, rising cost.

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
