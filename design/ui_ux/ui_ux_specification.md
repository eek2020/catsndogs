# Whisper Crystals — UI/UX Specification

---

## Screen Flow

```
[Title Screen] → [Main Menu]
                    ├── New Game → [Intro Cutscene] → [Navigation]
                    ├── Continue → [Load Slot Select] → [Navigation]
                    ├── Settings → [Settings Panel]
                    └── Quit → [Exit]

[Navigation] (core gameplay)
    ├── Encounter Trigger → [Combat] | [Trade] | [Dialogue] | [Exploration]
    ├── Story Beat → [Cutscene]
    ├── Pause Key → [Pause Menu] (overlay)
    │                 ├── Resume → [Navigation]
    │                 ├── Save → [Save Slot Select]
    │                 ├── Load → [Load Slot Select]
    │                 ├── Settings → [Settings Panel]
    │                 └── Quit to Menu → [Main Menu]
    ├── Ship Key → [Ship Management] (overlay)
    └── Faction Key → [Faction Status] (overlay)

[Combat] → Victory / Defeat / Flee → [Loot/Summary] → [Navigation]
[Trade] → Complete / Cancel → [Navigation]
[Dialogue] → Complete → [Navigation] | chain to [Combat] | [Trade]
[Exploration] → Discovery Summary → [Navigation]
[Cutscene] → Complete → [Navigation]
[Arc Transition] → [Arc Summary] → [Next Arc Navigation]
[Final Decision] → [Ending Cutscene] → [Ending Summary] → [Credits] → [Main Menu]
```

---

## HUD Layout (Navigation State)

```
┌─────────────────────────────────────────────────────┐
│ [Ship Health Bar]              [Crystal Count: 150]  │
│ [Shield Bar]                   [Salvage: 45]         │
│                                                      │
│                                                      │
│                   GAMEPLAY AREA                       │
│                (side-scrolling space)                 │
│                                                      │
│                                                      │
│ [Minimap]                      [Current Mission]     │
│ [Arc: The Squeeze]             [Faction Alert Icon]  │
└─────────────────────────────────────────────────────┘
```

- **Top-left:** Ship health and shield bars (horizontal)
- **Top-right:** Crystal inventory count, salvage count
- **Bottom-left:** Minimap showing nearby points of interest
- **Bottom-left below minimap:** Current arc label
- **Bottom-right:** Current mission/objective text, faction alert icon

---

## Dialogue Interface

```
┌─────────────────────────────────────────────────────┐
│                                                      │
│  ┌──────────┐  ┌─────────────────────────────────┐  │
│  │           │  │ DAVE                             │  │
│  │ Character │  │                                  │  │
│  │ Portrait  │  │ "You know why I'm here,          │  │
│  │           │  │  Aristotle. My people need those  │  │
│  │           │  │  crystals. We can do this the     │  │
│  │           │  │  easy way, or..."                 │  │
│  └──────────┘  └─────────────────────────────────┘  │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ [1] "Name your price, Dave."                  │   │
│  │ [2] "You'll get nothing from me."             │   │
│  │ [3] "Perhaps we can find a middle ground."    │   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

- Character portrait on the left (128x128 minimum)
- NPC name plate above dialogue text
- Dialogue text with typewriter effect (speed configurable)
- Response options at bottom — numbered for keyboard selection, clickable for mouse
- Subtle background dim to focus attention on dialogue

---

## Trade Interface

```
┌─────────────────────────────────────────────────────┐
│                    CRYSTAL TRADE                     │
│                                                      │
│  YOUR INVENTORY        │  THEIR INVENTORY            │
│  ──────────────        │  ───────────────             │
│  Crystals: 150         │  Credits: 5000              │
│  Salvage: 45           │  Ship Parts: 12             │
│  Grade 3 Refined       │  Intel Tokens: 3            │
│                        │                              │
│  ┌── OFFER ──────────────────────────┐               │
│  │ You give: 20 Crystals             │               │
│  │ You get:  1500 Credits + 2 Intel  │               │
│  └───────────────────────────────────┘               │
│                                                      │
│  Price modifier: -15% (Wary standing)                │
│                                                      │
│  [Counter-Offer]    [Accept]    [Reject]             │
└─────────────────────────────────────────────────────┘
```

- Split view: player inventory left, NPC inventory right
- Current offer displayed centrally
- Price modifier shown with faction standing explanation
- Three action buttons: Counter-Offer, Accept, Reject

---

## Faction Status Screen

```
┌─────────────────────────────────────────────────────┐
│                  FACTION RELATIONS                    │
│                                                      │
│  Felid Corsairs    [████████████░░░░] +60 Friendly   │
│  Canis League      [████░░░░░░░░░░░░] -35 Wary      │
│  The Lions         [██████░░░░░░░░░░] -15 Wary      │
│  The Wolves        [███░░░░░░░░░░░░░] -50 Hostile   │
│  Fairies           [████████░░░░░░░░] +25 Neutral   │
│  Knights           [███████░░░░░░░░░] +10 Neutral   │
│  Goblins           [███████░░░░░░░░░] +15 Neutral   │
│  Aliens            [███████░░░░░░░░░]  +5 Neutral   │
│                                                      │
│  [Select faction for details]                        │
│                                                      │
│  ┌── CANIS LEAGUE (Selected) ──────────────────┐    │
│  │ Leader: Dave                                 │    │
│  │ State: Wary — trade at premium pricing       │    │
│  │ Aggression: Escalating (Arc 2)               │    │
│  │ Crystal Reserves: Low                        │    │
│  │ Recent: Blockaded your supply route           │    │
│  └──────────────────────────────────────────────┘    │
│                                                      │
│  [Close]                                             │
└─────────────────────────────────────────────────────┘
```

- Reputation bars colour-coded: red (hostile) → yellow (wary) → grey (neutral) → green (friendly) → blue (allied)
- Selectable rows for detailed faction info
- Detail panel shows leader, trade permissions, recent events

---

## Ship Management Screen

```
┌─────────────────────────────────────────────────────┐
│                 SHIP: THE WHISPER                     │
│              Class: Corsair Raider                    │
│                                                      │
│  STATS            BASE   MODS   TOTAL                │
│  Speed              8     +0      8                  │
│  Armour             3     +1      4                  │
│  Firepower          5     +1      6                  │
│  Crystal Cap.       6     +1      7                  │
│  Crew Cap.          4     +1      5                  │
│                                                      │
│  Hull: [████████████████░░░░] 85/100                 │
│  Crystal Cargo: 25 / 7 capacity                      │
│                                                      │
│  CREW (3/5)                                          │
│  - Whiskers (Pilot, Skill 7) [Cat +manoeuvre]        │
│  - Patches (Gunner, Skill 5)                         │
│  - Sprocket (Engineer, Skill 6) [Goblin +repair]     │
│                                                      │
│  UPGRADES                                            │
│  - Reinforced Hull (+1 Armour)                       │
│  - Crystal Compressor (+1 Crystal Cap.)              │
│                                                      │
│  [Assign Crew]  [Apply Upgrade]  [Fleet View]        │
└─────────────────────────────────────────────────────┘
```

---

## Key UX Principles

- **Clarity over complexity:** Every UI element must be understandable without a tutorial
- **Faction colours everywhere:** UI elements subtly adopt the colours of the relevant faction
- **Non-obstructive HUD:** Gameplay view is never more than 15% occluded by HUD elements
- **Keyboard + mouse:** All UI is navigable by both keyboard shortcuts and mouse clicks
- **Typewriter dialogue:** Default speed is 30 characters/second; player can press CONFIRM to instant-fill
- **Transitions:** 0.3s fade transitions between major state changes (navigation → combat, etc.)
- **Accessibility:** Font size minimum 14px; high contrast mode option; key rebinding support
