# Whisper Crystals — Complete Game Summary

A comprehensive guide to the world, story, mechanics, and systems of Whisper Crystals.

> **Implementation Note (2026-04-05):** This document describes both implemented and planned content. Arcs 1-4 are fully implemented and playable. Arcs 5-10, the 6 expansion regions, and 4th ending (Reunite) are **design targets** — encounter data exists in JSON but these arcs have not been integration-tested or polished to the same level as Arcs 1-4. The 7 original regions, 3 endings, and all core systems are production-ready. See `docs/MASTER_PLAN.md` for current development status.

---

## What Is Whisper Crystals?

Whisper Crystals is a **narrative-driven 2D side-scrolling space pirate game** set in a multiverse where cats, dogs, fairies, goblins, knights, and aliens sail between realms aboard crystal-powered starships. The game is built in Godot 4.6 and draws heavy inspiration from the Spelljammer D&D setting — serious stakes, colourful factions, and a cast of anthropomorphic characters navigating politics, piracy, and war.

The player commands a starship captain caught at the centre of a multiverse-wide power struggle over the only known source of starship fuel: **Whisper Crystals**. Every faction needs them. Only one faction can produce them. The game explores what happens when a single individual controls the resource that everyone else depends on.

---

## The Core Premise

In a multiverse of interconnected realms, starships are powered by Whisper Crystals — rare, humming stones that resonate with unearthly energy. Without them, no ship flies. No fleet moves. No empire functions.

The player discovers (or is sent to secure) these crystals and must navigate a **10-arc story** that escalates from small-scale discovery to a full multiverse war, journeying through ancient graveyards, reality-bending frontiers, and the mythical source of all crystals. Along the way, they recruit crew, manage a ship, trade and fight across **13 regions**, build faction relationships, meet **22 unique special characters**, and make decisions that determine one of **four distinct endings** (including one hidden).

---

## How the Game Is Played

### Dual Protagonist System

At the start of the game, the player chooses one of two protagonists. This choice fundamentally changes the narrative perspective, available crew, encounter dialogue, and side missions.

| | **Aristotle** | **Dave** |
| --- | --- | --- |
| **Species** | Cat | Dog |
| **Faction** | Felid Corsairs | Canis League |
| **Title** | Captain | Commander |
| **Ship** | The Whisper (Corsair Raider) | The Iron Paw (League Cruiser) |
| **Starting Region** | The Fringe | The Fringe |
| **Play Style** | Fast, cunning, high crystal capacity | Tough, loyal, heavy armour and firepower |
| **Narrative Tone** | Pragmatic wit, pirate independence | Disciplined duty, questioning loyalty |

Aristotle's story is about a self-made street cat who built an empire and must decide what to do with it. Dave's story is about a loyal soldier sent to break that empire who begins questioning who the real enemy is.

### Core Gameplay Loop

1. **Explore** — Navigate regions, discover points of interest, uncover hidden locations
2. **Encounter** — Trigger story events, diplomatic meetings, combat, and trade opportunities
3. **Choose** — Make branching dialogue choices that affect faction reputation, resources, and story flags
4. **Fight** — Engage in tactical ship combat with damage calculations, upgrades, and crew bonuses
5. **Trade** — Buy and sell crystals, salvage, and goods across faction markets
6. **Recruit** — Find and recruit crew members through dedicated side missions
7. **Manage** — Upgrade your ship, monitor crew morale, and balance your economy
8. **Progress** — Complete arc objectives to advance the story toward one of four endings

### Controls & Navigation

The player pilots their ship through 2D side-scrolling space regions. Key controls include:

- **Movement** — Navigate through space, avoiding hazards and approaching points of interest
- **Tab** — Open the Star Map overlay (full galaxy view with fog of war)
- **M** — Open the Mission Log
- **Ship Screen** — View crew roster, ship stats, and upgrades
- **Faction Screen** — View faction relationships and diplomacy status

A **minimap** shows the local area with fog of war, POIs colour-coded by type (story=gold, hidden=purple, combat=red, rescue=orange, trade=green, exploration=cyan), and the current region name.

---

## The Story

The narrative spans **10 sequential arcs**, each escalating in scope, complexity, and stakes. Arcs must be completed in order — each unlocks the next. The story has expanded far beyond the original cats-vs-dogs conflict into a multiverse-spanning epic that explores ancient civilisations, the true origin of whisper crystals, and one cat captain's journey from pirate to potential steward of reality itself.

### Arc 1 — The Upstart (Origin)

**Theme:** How did a street cat become the most powerful figure in the multiverse?

**What happens:** The player discovers Whisper Crystals in a forgotten nebula. The crystals hum with raw, unearthly power — fuel for starships, currency for empires. Word spreads fast. Commander Dave of the Canis League arrives demanding terms. A shadowy figure called Death watches from the edges of scanner range.

**Key encounters:**

- **The Forgotten Deposit** — Crystal discovery. The player chooses to approach cautiously (fewer crystals, higher quality) or grab everything (more crystals, lower quality).
- **A Dog at the Door** — First meeting with Dave. A tense trade negotiation with multiple branches: cooperate, refuse, or negotiate. This encounter has deep branching dialogue with 6+ possible outcomes.
- **Eyes in the Dark** — First glimpse of Death. A decaying corsair ship drifts at the edge of scanner range, transmitting nothing but a low, rumbling purr.

**Decision Point:** The player chooses their initial stance — **aggressive expansion**, **cautious trade**, or **isolationist defence**. This shapes faction relationships and encounter availability going forward.

**Side missions available (Aristotle):**

- *Clean Up Aisle Seven* — Bounty: defeat goblin raiders harassing merchant convoys
- *Lost in Transit* — Retrieval: track down a missing cargo shipment
- *Wings of Diplomacy* — Escort: guide a Fairy envoy through Lion territory
- *Ghost Ship* — Retrieval: board and salvage a derelict vessel

**Side missions available (Dave):**

- *Patrol Duty* — Escort: protect a League supply convoy
- *Intelligence Sweep* — Retrieval: recover encrypted data drives from a destroyed scout ship
- *Border Enforcement* — Bounty: neutralise a Corsair raider hitting League trade lanes
- *Diplomatic Courier* — Escort: deliver sealed orders to a Knight garrison

**Special characters introduced:** Patch (Aristotle's old mentor), Rustclaw (goblin scrap dealer), Jinx (calico cat thief at the Twilight Bazaar)

**Crew recruitment begins:**

- **Aristotle:** Nine Lives (First Mate) and No Tail (Gunner) become available
- **Dave:** Charlie (First Mate) and Bombardier (Gunner) become available

**Exit conditions:** Crystal discovered, Dave met, Death glimpsed, stance chosen.

---

### Arc 2 — The Squeeze (Rising Pressure)

**Theme:** Power attracts enemies. The monopoly is now a target for everyone.

**What happens:** Dave escalates with a full blockade of the primary crystal supply route. Death's agents sabotage the player's fleet from within. The Lion Sovereign demands a 50% tribute on all crystal yields. The player is fighting on three fronts simultaneously.

**Key encounters:**

- **The Squeeze Begins** — Dave blockades the Delta-9 crystal route. The player must negotiate (pay a processing fee), fight (brutal skirmish, heavy damage), or stealth-reroute through a nebula (lose some ships but bypass entirely). Each choice has drastically different consequences.
- **Shadows in the Ranks** — Death's saboteurs bomb the main refinery ship. The player can purge ranks violently (stops sabotage but destroys morale) or investigate quietly with internal spies (expensive but preserves crew trust).
- **The Royal Demand** — A Lion emissary demands 50% tribute. Options: pay tribute and gain Lion protection, refuse and gain crew loyalty but make a powerful enemy, or bribe the emissary to report the territory as barren.
- **A Flickering Proposition** — The Fairies offer cloaking technology in exchange for crystals.

**Decision Point:** The player chooses which front to prioritise — **external threat** (Dave), **internal threat** (Death), or **political threat** (Lions).

**Special characters introduced:** Cogsworth (goblin engineer), Ser Galvain (Knight champion), Tidewalker (veteran dog captain), Sister Meridian (fairy healer), Wraith (Death's lieutenant)

**Crew recruitment continues:**

- **Aristotle:** Silky (Navigator) and Blood Paw (Surgeon) become available
- **Dave:** Luna (Navigator) and Thistle (Surgeon) become available

**Exit conditions:** Supply route situation resolved, Death's betrayal discovered, Lion tribute responded to.

---

### Arc 3 — The Alliance (Unlikely Partners)

**Theme:** Sometimes your enemy's enemy is your only friend.

**What happens:** The multiverse is more complex than cats vs dogs. To survive, the player must forge alliances with factions they'd normally raid or avoid. An alien civilisation makes contact. Dave requests a secret meeting. Death's true allegiance is finally revealed.

**Key encounters:**

- **Strangers from the Void** — An alien vessel defies known physics. A being of shifting light speaks directly into the player's mind, offering "elevation" at a cost. The player can embrace alien technology (powerful but terrifying crew toll), reject them (earns respect from traditional factions), or attempt to steal their tech (disastrous — they ARE the technology).
- **A Quiet Meeting** — Dave sends an unencrypted channel request. He meets Aristotle on a derelict station, no guards, no weapons. He reveals the Lions and Wolves ("the Sovereigns") are moving to annex the entire sector. He proposes a temporary ceasefire. The player can ally with Dave (fragile peace, shared intelligence) or refuse (maintain independence but face the Sovereigns alone).
- **The Master's Voice** — Death materialises on the bridge, having bypassed every security system. He reveals he was sent by masters and asks the player to guess his allegiance. The player's choice determines Death's true loyalty:
  - **Lions** — Death is a Lion agent working to return crystal control to the nobility
  - **Wolves** — Death allied with the Wolves, planning a military coup
  - **Independent** — Death serves only himself, driven by pure ambition

**Decision Point:** The player builds their **alliance portfolio** — broad alliance (many factions), selective alliance (few strong partners), or independent path (go it alone).

**Special characters introduced:** Glimmer (fairy crystal botanist), Void Singer (ancient being in Deep Space), Grizzle (bear mercenary), The Debt Collector (mysterious ledger-keeper)

**Exit conditions:** Alien contact made, Dave parley completed, Death's allegiance revealed.

---

### Arc 4 — The Dimming (Cracks in the Foundation)

**Theme:** The crystals themselves are changing — and the multiverse is fracturing.

**What happens:** Strange resonance patterns disrupt the Fairy Realms. The Twilight Bazaar reveals an ancient star chart fragment pointing to places beyond known space. The Lion Dominion begins to fracture — a young prince in exile leads reformists against the old guard in the Shattered Prides. Death's behaviour becomes erratic, his fleet attacking indiscriminately.

**Key encounters:**

- **The Dimming Light** — The Fairy Council warns that crystal resonance patterns are deteriorating. Something ancient is waking up.
- **The Cartographer's Fragment** — A mysterious merchant at the Twilight Bazaar sells a stone fragment covered in constellations matching no known chart — the first hint of the Cradle of Whispers.
- **The Prince in Exile** — In the Shattered Prides, a young Lion reformist challenges the old nobility. The player can support the reformists, back the traditionalists, or stay neutral.
- **The Broken Scythe** — Death's fleet attacks everything — friend, foe, even his own ships. Something has gone deeply wrong with the villain.
- **The Captain's Calculus** — Aristotle must process all the new threads and choose a primary direction: investigate the crystal anomalies, intervene in Lion politics, or hunt Death.

**Side missions:** *Harmonic Dissonance*, *Whispers in the Mane Hall*, *The Bazaar Job*, *The Trail of Cold Stars*

**Special characters introduced:** Lord Mane (Lion patriarch), Lady Penumbra (Lion shadow queen), The Oracle (hidden Fairy seer)

**New region unlocked:** The Shattered Prides (Lion civil war zone), The Twilight Bazaar (neutral trade hub)

**Exit conditions:** Crystal anomaly investigated, Lion fracture witnessed, Death's deterioration noted.

---

### Arc 5 — The Iron Hunt (Wolves Unleashed)

**Theme:** The Wolves stop waiting and launch a full military offensive for crystal control.

**What happens:** Iron Wolf dreadnoughts pour through every jump gate in the Iron Expanse. This is The Hunt — a full-scale military operation. Dave faces a loyalty crisis between the League and his growing doubts. The Knights formally declare their position. The Fairy elders reveal a deep secret about crystal origins.

**Key encounters:**

- **The Hunt Begins** — Iron Fang's armada launches a devastating offensive to seize crystal production by force.
- **The Good Dog's Dilemma** — Dave's loyalty to the League fractures as Wolf High Command pushes for total war. He opens a private channel to Aristotle.
- **The Oath of Iron and Starlight** — Ser Galvain broadcasts a formal Knight declaration that reshapes alliances across the sector.
- **The Deepest Root** — Fairy elders invite Aristotle to the Heart Garden, revealing that whisper crystals are not just fuel — they are alive, and they are dying.
- **The War Room** — Aristotle faces a tactical nightmare: enemies on all sides, allies fracturing, and the crystals themselves failing.

**Side missions:** *Wolves at the Gate*, *The Knight's Gambit*, *Iron Veins*, *Trust, but Verify*

**Special characters introduced:** Iron Fang (Wolf warlord), Snarl (Wolf pack hunter), Admiral Brass (League dreadnought commander)

**New region unlocked:** The Iron Expanse (Wolf military territory)

**Exit conditions:** Wolf offensive responded to, Dave's loyalty crisis resolved, fairy secret learned.

---

### Arc 6 — The Bone Yard (Echoes of the Ancients)

**Theme:** The dead hold secrets that the living have forgotten.

**What happens:** The Bone Yard — a vast starship graveyard spanning millennia — reveals that an ancient civilisation once cultivated whisper crystals deliberately. The Lion civil war erupts into open combat. Goblins attempt a daring heist during the chaos. Death's lieutenant, The Wraith, delivers a desperate confession.

**Key encounters:**

- **The Graveyard of Empires** — Exploring the deepest layers of the Bone Yard reveals pre-war crystal technology and hints of the "Builders."
- **The Voice Between Frequencies** — An ancient signal leads to Echo, a billion-year-old AI who helped plant the original crystal network.
- **The Prides Divided** — The Lion civil war explodes. Lord Mane's reformists face Lady Penumbra's traditionalists, and both beg Aristotle for crystal supply.
- **The Great Crystal Caper** — Goblins launch their most ambitious heist during the Lion chaos. Help them or stop them.
- **The Wraith's Confession** — Death's lieutenant breaks down, revealing that Death is not what he seems — he's been corrupted by something connected to the crystals themselves.
- **The Shattered Mirror** — Aristotle must decide how to respond to the cascading fractures across every faction.

**Side missions:** *Grave Robbers*, *Pride and Prejudice*, *The Big Score*, *Echoes of the Builders*

**Special characters introduced:** Brother Hemlock (badger monk), The Keeper (ancient archivist), Echo (Builder AI)

**New region unlocked:** The Bone Yard (starship graveyard)

**Exit conditions:** Builder origins discovered, Lion civil war engaged, ancient signal decoded.

---

### Arc 7 — The Warp Marches (Beyond Reality)

**Theme:** The boundaries of known space — and known physics — shatter.

**What happens:** Armed with clues from the Bone Yard, the Oracle, and the Fairy elders, Aristotle ventures into the Warp Marches — a region where reality itself is unstable. Crystals grow wild in tears between dimensions. The Void Singer's domain awaits. Dave follows, drawn by something he can't explain. The truth about crystal origins comes into focus.

**Key encounters:**

- **The Marches Beyond Reason** — The ship punches through into a region that shouldn't exist. The crystal drive begins to sing. Reality operates on different rules here.
- **The Voice in the Lattice** — Aristotle achieves crystal communion — direct telepathic contact with the whisper crystal network itself. The crystals are seeds, planted by beings called the Builders.
- **The Truth Behind the Hive** — The alien faction reveals its true agenda, which is tied to the crystal network's survival.
- **The Dog Who Listened** — Dave, having followed Aristotle into the Marches, finally hears the crystals sing. A pivotal moment that can permanently shift his allegiance.
- **The Weight of Knowing** — Aristotle must decide what to do with the revelation that crystals are alive and the network is dying.

**Side missions:** *Through the Looking Glass*, *The Object*, *Resonance Cascade*, *The Web of Whispers*

**Special characters introduced:** Flux (shape-shifting alien merchant)

**New region unlocked:** The Warp Marches (reality-bending frontier)

**Exit conditions:** Crystal communion achieved, alien truth learned, Dave confronted with the truth.

---

### Arc 8 — The Last Table (Gathering Storm)

**Theme:** Every alliance, every enemy, every thread converges for the endgame.

**What happens:** At the Twilight Bazaar, Aristotle convenes the most important summit in multiverse history. Every faction has a seat. Every grievance is on the table. Death undergoes a transformation — corrupted beyond recognition by crystal energy. A portal to the Cradle of Whispers opens for those who have gathered enough knowledge and clues.

**Key encounters:**

- **The Last Table** — The grand alliance summit. Every faction representative in one room, negotiating the fate of the multiverse.
- **What Death Became** — Death, consumed by crystal corruption, transforms into something beyond cat or pirate. His final form is a threat to everyone.
- **The Door That Remembers** — The portal to the Cradle of Whispers opens — but only for those who rescued the Fairy Cartographer, met the Oracle and the Keeper, and decoded the ancient clues scattered across three regions.
- **Before the Storm** — Final preparations. Allies settle personal business. The fleet musters.

**Side missions:** *The Grand Coalition*, *Last Run*, *Unfinished Business*, *The Board Is Set*

**Exit conditions:** Summit concluded, Death's transformation witnessed, Cradle portal accessible.

---

### Arc 9 — The Cradle (The Source of All Things) — HIDDEN ARC

**Theme:** The origin of whisper crystals — and the choice that will define the multiverse.

**What happens:** The Cradle of Whispers is the mythical source of all whisper crystals. It is not a place — it is a memory made solid. Mountains of living crystal rise from floors that don't exist. The crystals here don't just glow; they sing in languages that predate language. Ancient Guardians protect the Heart of All Crystals. The crystal consciousness itself speaks.

**Unlock conditions:** Requires Arc 8 complete plus: alien contact (Arc 3), fairy deep secret (Arc 5), ancient signal decoded (Arc 6), crystal communion (Arc 7), Fairy Cartographer rescued, Cradle clues from Shattered Prides, Warp Marches, and Bone Yard, plus Oracle and Keeper met.

**Key encounters:**

- **The Heart of Everything** — Arrival at the Cradle. A place so vast it makes the multiverse feel like a cupboard. The crystals whisper in a four-billion-year-old conversation.
- **The Broken Song** — The crystal consciousness reveals itself — and reveals that the network is dying. Without intervention, all whisper crystals will go silent within a generation.
- **The Mirrors of Reckoning** — Ancient Guardians test the player, reflecting every choice made throughout the game.
- **The Last Note** — The final choice at the Heart of All Crystals. The player's decision here determines the hidden fourth ending.

**Side missions:** *The Heart of All Things*, *Songs of the First*

**New region unlocked:** The Cradle of Whispers (hidden, the largest region at 10,000×10,000)

**Exit conditions:** Crystal consciousness encountered, Guardians faced, Cradle choice made.

---

### Arc 10 — The Reckoning (Final Conflict)

**Theme:** What is Aristotle willing to become to keep what he built?

**What happens:** All fronts converge. Dave launches a full military assault. Death — now a corrupted crystal abomination — makes a final power grab for the crystal reserves. The Lions or Wolves (depending on Death's revealed allegiance) declare intent to annex the sector. The player faces the ultimate question: what do you do with absolute power?

**Key encounters:**

- **Cry Havoc** — Dave's armada jumps into the system, guns firing. The player faces three options: full defence (apocalyptic battle, massive casualties), tactical retreat (lose infrastructure, save veteran crews), or weaponise the crystal deposits (detonate an asteroid in the fleet — devastating but with terrible backlash).
- **The Knife in the Dark** — While fighting Dave, Death bypasses security and infiltrates the Vault to seize the core crystal reserves.
- **The True Masters** — The Sovereigns arrive. Massive jump-signatures tear open space. Depending on earlier choices, Lions or Wolves appear to annex the sector.
- **The Whisper's End** — Aristotle stands alone at the master console of the central forge. His paw rests over the controls. He controls the fuel of the multiverse. The decision he makes now will rewrite the stars.

**The Endings** — Determined by the **cumulative weight of all choices** made throughout the game, not a single final decision:

| Ending | Outcome Weight | Description |
| -------- | --------------- | ------------- |
| **Ending A — Hold** | Weight ≥ 0.5 | Aristotle keeps the monopoly. He wins, but rules alone. Power concentrated, empire secured, but at the cost of everything soft. |
| **Ending B — Share** | Weight between -0.2 and 0.5 | Aristotle distributes crystal knowledge across the multiverse. Power spreads. Peace through redistribution. The monopoly ends, but so does the war. |
| **Ending C — Destroy** | Weight ≤ -0.2 | Aristotle destroys the production sites. No one wins. The multiverse must find another way. A scorched-earth ending born from desperation or principle. |
| **Ending D — Reunite** | Hidden | Only accessible if the player completed the Cradle arc (Arc 9) and chose to heal the crystal network. Aristotle becomes the steward of a restored crystal consciousness, bridging the gap between the Builders' legacy and the multiverse's future. The crystals sing again. |

Every choice in the game carries an **outcome_weight** value. Aggressive, self-serving, and power-consolidating choices push toward Ending A. Diplomatic, sharing, and cooperative choices push toward Ending B. Destructive, chaotic, and nihilistic choices push toward Ending C. Completing the Cradle arc unlocks Ending D — Reunite.

---

## Content Scale Summary

| Category | Previous | Current | Change |
| ---------- | ---------- | --------- | -------- |
| **Maps/Regions** | 7 | 13 | +6 (Shattered Prides, Iron Expanse, Twilight Bazaar, Warp Marches, Bone Yard, Cradle of Whispers) |
| **Story Arcs** | 4 | 10 | +6 new arcs + 1 hidden (The Cradle) |
| **Endings** | 3 | 4 | +1 hidden (Reunite) |
| **Encounter Files** | 17 | 30 | +13 files |
| **Total Encounters** | ~55 | ~143 | +88 encounters |
| **Side Mission Files** | 11 | 23 | +12 files |
| **Total Side Missions** | ~16 | ~68 | +52 missions |
| **Special Characters** | 0 | 22 | New file with 22 encounters |
| **Distress Signals** | 5 | 10 | +5 region-specific |
| **Purchasable Maps** | 6 | 11 | +5 new charts |

### Per-Path Breakdown

| Category | Aristotle Path | Dave Path |
| ---------- | --------------- | ----------- |
| **Main story encounters per arc** | 4-6 per arc | 4-6 per arc (unique) |
| **Total main story encounters** | ~50 across 10 arcs | ~50 across 10 arcs (unique) |
| **Side missions per arc** | 2-4 per arc | 2-4 per arc (unique) |
| **Total side missions** | ~34 | ~34 |
| **Crew recruitment missions** | 4 (one per crew member) | 4 (one per crew member) |
| **Distress signal encounters** | 10 (repeatable, random, some region-specific) | 10 (repeatable, random, some region-specific) |
| **Special character encounters** | 22 (shared across both paths) | 22 (shared across both paths) |

Each protagonist has **entirely separate encounter files** for every arc, meaning the story dialogue, NPC reactions, and available choices differ based on who you're playing.

---

## Factions

The multiverse has **8 factions**, each with unique abilities, ship designs, and political agendas. Every faction is actively competing for multiverse dominance. Whoever controls the crystals controls who participates in that race.

### Core Factions

#### Felid Corsairs (Player Faction — Cats)

- **Realm:** The Feline Courts
- **Ideology:** Freedom through power
- **Government:** Decentralised captains — leadership earned, not inherited
- **Ships:** Fast (Speed 8), fragile (Armour 3), high crystal capacity. Asymmetric, jury-rigged, devastatingly effective.
- **Special:** The **only faction that can refine raw crystals**. This is their power and their target.
- **Abilities:**
  - *Crystal Refining* — increase crystal quality grade
  - *Shadow Running* — -30% ambush rate in hostile territory
  - *Cunning Diplomacy* — unlocks bluff/misdirect dialogue options

#### Canis League (Primary Antagonist — Dogs)

- **Realm:** The Canine Order
- **Ideology:** Order through loyalty
- **Government:** Military command hierarchy
- **Ships:** Heavy (Armour 8), slow (Speed 4), large crews (Crew 8). Organised fleet formations.
- **Special:** Completely crystal-dependent. This drives their aggression.
- **Abilities:**
  - *Organised Warfare* — +15% armour when 2+ League ships are present
  - *Siege Tactics* — blockade supply routes, -50% crystal throughput
  - *Superior Logistics* — 20% cheaper resupply/repair at League ports

#### The Lions (Noble Cat Hierarchy)

- **Realm:** The Feline Courts (noble branch)
- **Ideology:** Rule by divine birthright
- **Government:** Noble hierarchy
- **Ships:** Ornate, balanced stats (Speed 5, Armour 6, Firepower 5), high crystal capacity.
- **Special:** Claim birthright over Whisper Crystals. Pressure Aristotle from within cat hierarchy. They were rulers before crystals existed and intend to rule after.
- **Tension:** Need Aristotle's knowledge but resent owing anything to a street cat.
- **Abilities:**
  - *Diplomatic Pressure* — force tribute demands costing crystals
  - *Noble Authority* — +20% political influence over neutral factions in their regions
  - *Royal Decree* — temporarily close trade routes to hostile factions

#### The Wolves (Military Elite Dogs)

- **Realm:** The Canine Order (military elite branch)
- **Ideology:** Dominance through superior tactics
- **Government:** Military stratocracy
- **Ships:** Tactical strike craft (Speed 6, Armour 7, Firepower 8). The toughest opponents in space.
- **Special:** The strategic mind behind Canis League military ambition. Want to break the monopoly by force.
- **Abilities:**
  - *Tactical Superiority* — +20% firepower on first strike
  - *Pack Coordination* — multiple ships share targeting data, -15% player dodge
  - *Evolutionary Right* — diplomatic encounters can escalate to combat with no reputation penalty

### Wider Multiverse Factions

#### Fairies

- **Realm:** Fairy Realms
- **Ideology:** Knowledge is currency
- **Role:** Magical traders and information brokers
- **Abilities:**
  - *Magical Espionage* — reveal hidden story flags for a crystal fee
  - *Enchanted Goods* — temporary stat buffs lasting 3 encounters
  - *Intelligence Networks* — reveal encounter tables for the current region
- **Gameplay:** High-value but unpredictable allies. Offer intel, rare trades, and unique crystal knowledge. Friendly starting reputation with the Corsairs (+15).

#### Knights

- **Realm:** Knight Kingdoms
- **Ideology:** Order through law
- **Role:** Feudal military alliance
- **Abilities:**
  - *Heavy Armour* — Knight crew grant +10% armour to any ship
  - *Disciplined Formations* — -10% incoming damage in allied fleet combat
  - *Siege Engineering* — breach blockaded routes at reduced cost
- **Gameplay:** Strong combat support but political strings attached. Cost of alliance is autonomy.

#### Goblins

- **Realm:** Goblin Warrens
- **Ideology:** Profit above all
- **Role:** Scavengers, engineers, black-market dealers
- **Abilities:**
  - *Rapid Ship Modification* — apply upgrades mid-encounter (emergency repairs)
  - *Black-Market Crystal Trade* — buy/sell crystals at volatile prices outside normal channels
  - *Sabotage Services* — hire goblins to reduce a target faction's military strength
- **Gameplay:** Ship upgrades, black-market trades, illicit goods. Useful but unreliable. Friendly starting reputation with Corsairs (+10).

#### Aliens & Space Races

- **Realm:** Deep Space
- **Ideology:** Varies wildly
- **Role:** Advanced civilisations with their own agendas
- **Abilities:**
  - *Superior Technology* — weapons ignore 25% of target armour
  - *Unknown Weapons* — unpredictable damage variance (±50%)
  - *Deeply Unpredictable Behaviour* — diplomatic outcomes swing ±20% randomly
- **Gameplay:** Wild cards. Introduce multiverse scale. Unique tech offers. First contact occurs in Arc 3.

### Faction Relationship Matrix

Factions start with predefined relationships that shift based on player actions. The scale runs from -100 (hostile) to +100 (allied).

| | Corsairs | Canis | Lions | Wolves | Fairies | Knights | Goblins | Aliens |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Corsairs** | — | -20 | -10 | -30 | +15 | 0 | +10 | +5 |
| **Canis** | -20 | — | -15 | +40 | 0 | +20 | -10 | 0 |
| **Lions** | -10 | -15 | — | -20 | +10 | +15 | -5 | +5 |
| **Wolves** | -30 | +40 | -20 | — | -10 | +10 | -15 | -5 |
| **Fairies** | +15 | 0 | +10 | -10 | — | +5 | +20 | +15 |
| **Knights** | 0 | +20 | +15 | +10 | +5 | — | -20 | 0 |
| **Goblins** | +10 | -10 | -5 | -15 | +20 | -20 | — | +10 |
| **Aliens** | +5 | 0 | +5 | -5 | +15 | 0 | +10 | — |

**Diplomatic thresholds:**

- **Hostile:** -100 to -51
- **Wary:** -50 to -1
- **Neutral:** 0 to 25
- **Friendly:** 26 to 75
- **Allied:** 76 to 100

**Cascade rules:** Some faction relationships are linked. Improving relations with the Canis League automatically improves Wolves by 50% of the change (and vice versa at 30%). Improving Lions automatically *worsens* Corsairs by 30%.

---

## Characters

### Protagonists

#### Aristotle — Captain of the Felid Corsairs

- **Species:** Cat
- **Ship:** The Whisper (Corsair Raider)
- **Personality:** Street cat made good. Self-made before the Lions even noticed the crystals existed. Thinks he's the smartest creature in any room — and usually is. Philosophical, cunning, allergic to being told what to do.
- **Philosophy:** Understand everything, control what you can, survive the rest.
- **Backstory:** Born with nothing. Stumbled upon Whisper Crystals, figured out refining through sheer ingenuity. Built an empire before the Lions even noticed.
- **Core Tension:** Balancing being a pirate (free, chaotic, self-serving) with being the most powerful supplier in the multiverse (responsibility, enemies everywhere).
- **Dialogue Tone:** Pragmatic, witty, strategic. Never formal. Never subservient. Deflects tension with humour but the wit masks genuine intelligence and occasional vulnerability.
- **Stats:** Cunning 8, Leadership 6, Stealth 7, Intimidation 6, Combat 5, Negotiation 4

#### Dave — Commander of the Canis League

- **Species:** Dog
- **Ship:** The Iron Paw (League Cruiser)
- **Personality:** The most dangerous kind of antagonist — completely ordinary name, completely extraordinary determination. Methodical, loyal, utterly relentless. He does not hate Aristotle. He simply needs what Aristotle has and will not stop.
- **Motivation:** Break the crystal monopoly. Achieve energy independence for dogs. Through trade, force, or discovering an alternative.
- **Backstory:** A disciplined officer sent to secure the crystals by any means necessary. The deeper he digs, the more he questions who the real enemy is.
- **Dialogue Tone:** Quiet, direct, almost polite. Dave's scariest lines are the simplest. Contrast with Aristotle's wit and Death's theatricality.
- **Stats:** Leadership 8, Combat 7, Negotiation 6, Intimidation 5, Cunning 4, Stealth 3

### The Villain — Death

- **Species:** Cat (rival Felid Corsair captain)
- **Role:** Internal antagonist — wants Whisper Crystal production for himself
- **Personality:** Old world. Theatrical where Dave is quiet. Ancient, patient, and completely certain of his own superiority. Sees Aristotle as an upstart who got lucky.
- **Story Role:** Creates a two-front war — Dave externally, Death internally. Forces alliance choices.
- **Dialogue Tone:** Dark, theatrical, grandiose. Speaks like someone who has been waiting centuries for this moment.
- **True Allegiance:** Hidden until Arc 3. Determined by the player's investigation choices in Arc 2:
  - Lions agent — working to return crystal control to the nobility
  - Wolves agent — planning a military coup
  - Independent — serves only himself
- **Stats:** Intimidation 9, Stealth 8, Cunning 7, Combat 6, Leadership 5, Negotiation 4
- **Arc Progression:** Hidden (Arc 1) → Covert sabotage (Arc 2) → Revealed (Arc 3) → Open conflict and death (Arc 4)

### Crew Members — Aristotle's Path

Each crew member has a dedicated recruitment side mission with unique story encounters.

#### Nine Lives — First Mate

- **Species:** Cat
- **Origin:** Felid Corsairs
- **Backstory:** Legendary survivor found drifting in a damaged escape pod. Old friends with Aristotle from the streets. Has cheated death so many times the crew thinks she's immortal.
- **Recruitment:** Arc 1. She's found in a damaged escape pod near the Asteroid Belt. Joins without hesitation — old debts and older loyalties.
- **Trait — Survivability:** -15% crew casualty chance, +10% hull repair rate, +5% post-combat recovery
- **Join Type:** Willing

#### No Tail — Gunner

- **Species:** Cat
- **Origin:** Felid Corsairs
- **Backstory:** Scarred, battle-hardened cat with a missing tail and a grudge against the Canis League. Found defending a besieged outpost alone.
- **Recruitment:** Arc 1. She doesn't flinch when you approach — just sizes you up. Only strength earns her respect. The player must prove themselves in a challenge.
- **Trait — Firepower:** +10% weapon damage, +5% critical hit chance
- **Join Type:** Must be persuaded

#### Silky — Navigator

- **Species:** Cat
- **Origin:** Fairies
- **Backstory:** A graceful, enigmatic cat who knows hidden routes between realms. Found trapped in a fairy-realm labyrinth, calmly sketching star charts on the walls. She already knows your name.
- **Recruitment:** Arc 2. She joins without being asked. "I was wondering when you'd arrive."
- **Trait — Pathfinding:** +12% exploration discovery rate, +8% fuel efficiency
- **Join Type:** Willing

#### Blood Paw — Surgeon

- **Species:** Cat
- **Origin:** Lions (defector)
- **Backstory:** A former Lion court physician who defected after witnessing corruption. Found running a field hospital in a war zone, treating wounded from three factions.
- **Recruitment:** Arc 2. "If you want my help, help me first. Get these people out." Only after a full evacuation does she agree to join.
- **Trait — Healing:** +10% morale recovery, +8% hull repair rate, +10% post-combat recovery
- **Join Type:** Must be persuaded

### Crew Members — Dave's Path

#### Charlie — First Mate

- **Species:** Dog
- **Origin:** Canis League
- **Backstory:** Dave's childhood friend from the academy. Found commanding a supply convoy under ambush.
- **Recruitment:** Arc 1. You break the ambush together, just like academy drills. He grabs your arm grinning: "Just like old times."
- **Trait — Loyalty:** +12% morale recovery, -8% crew casualty chance
- **Join Type:** Willing

#### Bombardier — Gunner

- **Species:** Dog
- **Origin:** Canis League
- **Backstory:** A demolitions expert court-martialled for "excessive enthusiasm." Found in a League brig during a prison break encounter.
- **Recruitment:** Arc 1. "You another by-the-book officer?" Convince him you're different, and his eyes light up.
- **Trait — Explosives:** +12% firepower, +6% critical hit chance
- **Join Type:** Must be persuaded

#### Luna — Navigator

- **Species:** Wolf-dog hybrid
- **Origin:** Wolves
- **Backstory:** A quiet, calculating navigator who reads star charts like poetry. Found stranded on a derelict research station surrounded by charts pinned to every surface.
- **Recruitment:** Arc 2. "Your mission — it goes beyond the League, doesn't it? Interesting. I'll navigate."
- **Trait — Star Reading:** +10% exploration discovery, +10% ambush detection, +10% fuel efficiency
- **Join Type:** Willing

#### Thistle — Surgeon

- **Species:** Dog
- **Origin:** Knights (disillusioned)
- **Backstory:** A field medic treating wounded from both sides of a battle. Doesn't pick sides — picks up the pieces.
- **Recruitment:** Arc 2. "I don't patch people up so they can go kill each other again. If you're different, prove it."
- **Trait — Field Medicine:** +10% morale recovery, +6% hull repair rate, +12% post-combat survival
- **Join Type:** Must be persuaded

### Mixed-Universe Crews

Ship crews are **not faction-pure**. Any captain's crew can contain members from across the multiverse — a cat captain can have goblin engineers, fairy scouts, and a knight navigator. Crew composition affects ship capabilities, encounter options, and morale dynamics.

### Special Characters (22 Unique Encounters)

Throughout the expanded story, the player meets **22 named special characters** — each with their own dedicated encounter, branching dialogue, and faction consequences. These are not crew members but key NPCs who shape the narrative.

#### Arc 1 Characters

- **Patch** — Aristotle's one-eyed old mentor. A battered trader cat who taught Aristotle everything. Found in The Fringe. Offers smuggling routes, advice, or a farewell.
- **Rustclaw** — Goblin scrap dealer in the Warrens. Wears a cape of hull plating and a crown of circuit boards. Sells bargains buried under garbage, or modifies your ship uninvited.
- **Jinx** — Scrawny calico cat with mismatched eyes. Found at the Twilight Bazaar noodle stand while being chased. Expert infiltrator and lockpick. Recruitable as an ally.

#### Arc 2 Characters

- **Cogsworth** — Goblin engineer-scholar in the Warrens. Meticulous handwriting amidst mechanical chaos. Commission crystal drive upgrades or trade research data.
- **Ser Galvain** — Knight champion at the Knight Kingdoms border station. Full ceremonial armour, unwavering chivalry. Earn passage through respect, trade, or insult.
- **Tidewalker** — Veteran dog captain on a pre-war cruiser held together by stubbornness. Shares decades of wisdom and hidden navigation routes.
- **Sister Meridian** — Fairy healer running a neutral clinic at the Twilight Bazaar. Treats anyone regardless of faction. Patience earns her crystal healing pendant.
- **Wraith** — Death's most trusted lieutenant. A void-ship that absorbs weapons fire and phases through projectiles. First harbinger of Death's interest.

#### Arc 3 Characters

- **Glimmer** — Fairy crystal botanist perched on a tiny asteroid in the Fairy Realms. Her wings catch colours that shouldn't exist. Teaches crystal resonance or watches in disappointment as you harvest her garden.
- **Void Singer** — An ancient being who speaks in harmonics that predate radio technology. Located in Deep Space. Reveals the crystal network's structure and hints at the Cradle.
- **Grizzle** — Bear mercenary the size of a geological feature. Found at the Twilight Bazaar. Available for hire at steep rates. "I don't betray employers. Bad for business."
- **The Debt Collector** — A tall, thin figure in an immaculate suit carrying a ledger of every debt in the multiverse. Repeatable encounter. Always collects.

#### Arc 4 Characters

- **Lord Mane** — Lion Dominion patriarch in the Shattered Prides. Silver-streaked mane, golden eyes. Audience in a cathedral flagship. Requires crystal tribute, strategic alliance, or risks becoming a permanent enemy.
- **Lady Penumbra** — The shadow queen behind half the Lion court's decisions. Meets only in darkness. Offers intelligence and partnership against Lion hardliners.
- **The Oracle** — A being of living crystal hidden in a Fairy Realms pocket dimension. Only accessible if the Fairy Cartographer was rescued. Shows visions of the Cradle and all possible futures.

#### Arc 5 Characters

- **Iron Fang** — Wolf warlord in the Iron Expanse. Challenges Aristotle ship-to-ship. Respects strength, tolerates trade, despises cowardice.
- **Snarl** — Wolf pack hunter. Appears without warning in a kill box of three frigates. Compact, scarred, amber-eyed. Respects survival over bravery.
- **Admiral Brass** — Grizzled bulldog commanding the League's Third Fleet from an immaculate dreadnought. Forty years of combat experience. Surprisingly reasonable if you stand your ground.

#### Arc 6 Characters

- **Brother Hemlock** — Old badger monk tending a garden sanctuary in a derelict carrier deep in the Bone Yard. Offers tea, silence, and an ancient crystal that sings your name.
- **The Keeper** — Ancient figure wrapped in optical fibre robes, guarding a crystal data archive spanning millennia. Reveals that crystals are "seeds" planted by the Builders.
- **Echo** — A billion-year-old AI buried in the Bone Yard's deepest layer. A Builder who helped plant the original crystal network. Fragmentary, desperate, heartbreaking. Can be restored with crystal power.

#### Arc 7 Characters

- **Flux** — Shape-shifting alien merchant in the Warp Marches. Their ship changes form constantly. Sells artifacts from civilisations that won't exist for a million years. Provides Cradle coordinates for free — "an investment in an interesting future."

---

## Ship Management

### Ship Stats

Every ship has 5 core stats:

| Stat | Description |
| ------ | ------------- |
| **Speed** | Movement speed and evasion chance |
| **Armour** | Damage reduction |
| **Firepower** | Weapon damage output |
| **Crystal Capacity** | Maximum crystals the ship can carry |
| **Crew Capacity** | Maximum number of crew members |

### Available Ships

| Ship | Faction | Speed | Armour | Firepower | Crystal Cap | Crew | Hull | Notes |
| ------ | --------- | ------- | -------- | ----------- | ------------- | ------ | ------ | ------- |
| Corsair Raider | Corsairs | 8 | 3 | 5 | 6 | 4 | 100 | Standard, fast, agile |
| Corsair Smuggler | Corsairs | 7 | 3 | 4 | 9 | 3 | 90 | Trade-optimised, expanded cargo |
| Corsair Interceptor | Corsairs | 9 | 1 | 8 | 4 | 3 | 80 | Glass cannon — fastest, hardest-hitting, fragile |
| Pirate Destroyer | Corsairs | 4 | 8 | 9 | 5 | 8 | 160 | Purchasable (80 crystals, 60 salvage). Slow but devastating |
| League Cruiser | Canis | 4 | 8 | 6 | 5 | 8 | 120 | Standard League vessel. Heavy, armed, crewed |
| League Destroyer | Canis | 3 | 9 | 9 | 4 | 10 | 180 | Elite warship. Boss-level threat |
| Royal Galleon | Lions | 5 | 6 | 5 | 7 | 6 | 120 | Ornate, balanced, political prestige |
| Wolf Strike Craft | Wolves | 6 | 7 | 8 | 4 | 7 | 140 | Tactical, optimised for combat |

### Ship Upgrades

Upgrades are purchased at shipyards using crystals and salvage. Some have trade-offs.

| Upgrade | Stat | Bonus | Cost (Crystals/Salvage) | Trade-off |
| --------- | ------ | ------- | ------------------------ | ----------- |
| Reinforced Hull | Armour | +1 | 20/10 | None |
| Turbocharger | Speed | +1 | 25/15 | None |
| Heavy Guns | Firepower | +1 | 30/20 | None |
| Crystal Compressor | Crystal Capacity | +1 | 15/5 | None |
| Expanded Quarters | Crew Capacity | +1 | 10/15 | None |
| Stealth Plating | Speed | +1 | 35/25 | Armour -1 |
| Siege Cannons | Firepower | +2 | 40/30 | Speed -1 |

### Ship Dealers by Region

- **The Feline Courts** — Corsair Raider, Corsair Smuggler, Corsair Interceptor
- **The Canine Order** — League Cruiser, League Destroyer
- **Goblin Warrens** — Corsair Raider, Corsair Smuggler
- **Knight Kingdoms** — Royal Galleon

---

## Economy System

### Currencies

The game has two primary currencies:

- **Whisper Crystals** — The core resource. Fuel, currency, and the reason for the entire conflict. Used for ship upgrades, star chart purchases, faction trade, and crew recruitment costs.
- **Salvage** — Scavenged materials from wrecks, battles, and exploration. Used for ship repairs, upgrades, and trade.

### Crystal Deposits

Six crystal deposits exist across the multiverse, varying in quantity, quality, and accessibility:

| Deposit | Region | Quantity | Quality | Extraction Rate | Status |
| --------- | -------- | ---------- | --------- | ----------------- | -------- |
| Feline Courts Primary | Feline Courts | 500 | Grade 3 | 8/turn | Active |
| Goblin Warrens Scrap | Goblin Warrens | 150 | Grade 1 | 10/turn | Active |
| Canine Order Vein | Canine Order | 200 | Grade 2 | 4/turn | Discovered, inactive |
| Knight Kingdoms Mine | Knight Kingdoms | 300 | Grade 2 | 6/turn | Discovered, inactive |
| Fairy Realms Hidden | Fairy Realms | 350 | Grade 4 | 3/turn | Undiscovered |
| Deep Space Anomaly | Deep Space | 800 | Grade 5 | 2/turn | Undiscovered |

### Supply Routes

Crystal trade flows along defined supply routes with varying capacity and risk:

| Route | Origin → Destination | Capacity | Risk | Threats |
| ------- | --------------------- | ---------- | ------ | --------- |
| Corsair → Goblins | Feline Courts → Goblin Warrens | 15 | Low | Canis League |
| Corsair → Fairies | Feline Courts → Fairy Realms | 10 | Minimal | None |
| Goblins → Knights | Goblin Warrens → Knight Kingdoms | 8 | Medium | Wolves |
| Knights → Canine | Knight Kingdoms → Canine Order | 12 | Low | Corsairs |
| Fairy → Deep Space | Fairy Realms → Deep Space | 5 | High | Aliens |

### Crystal Market

Base crystal price is **100 credits**. Each faction has a demand multiplier:

| Faction | Demand Multiplier | Effective Price |
| --------- | ------------------ | ----------------- |
| Canis League | 1.5x | 150 (highest — most desperate) |
| Wolves | 1.4x | 140 |
| Lions | 1.3x | 130 |
| Knights | 1.2x | 120 |
| Fairies | 1.1x | 110 |
| Aliens | 1.0x | 100 |
| Goblins | 0.9x | 90 |
| Corsairs | 0.8x | 80 (lowest — they produce them) |

### Trade Goods

| Good | Base Value | Weight |
| ------ | ----------- | -------- |
| Raw Whisper Crystals | 100 | 1 |
| Refined Whisper Crystals | 250 | 1 |
| Salvage Parts | 30 | 2 |
| Fairy Enchantments | 200 | 1 |
| Goblin Tech Scrap | 50 | 3 |

---

## The Galaxy

### Regions

The galaxy ("The Celestial Codex") contains **13 regions**, each controlled by a faction with varying danger levels and facilities. Six new regions were added to support the expanded 10-arc narrative:

| Region | Name | Controller | Danger | Size | Unlocked |
| ------ | ------ | ----------- | -------- | ------ | ---------- |
| starting_realm | The Fringe | Corsairs | 1 | 6000×6000 | Start |
| feline_courts | The Feline Courts | Corsairs | 1 | 6000×6000 | Start |
| canine_order | The Canine Order | Canis League | 3 | 7000×7000 | Start |
| fairy_realms | Fairy Realms | Fairies | 2 | 5500×5500 | Start |
| goblin_warrens | Goblin Warrens | Goblins | 2 | 5500×5500 | Start |
| knight_kingdoms | Knight Kingdoms | Knights | 2 | 6500×6500 | Start |
| deep_space | Deep Space | Aliens | 5 | 8000×8000 | Arc 3 |
| shattered_prides | The Shattered Prides | Lions (civil war) | 3 | 6000×6000 | Arc 4 |
| twilight_bazaar | The Twilight Bazaar | Neutral | 1 | 4500×4500 | Arc 4 |
| iron_expanse | The Iron Expanse | Wolves | 4 | 7000×7000 | Arc 5 |
| bone_yard | The Bone Yard | None (graveyard) | 4 | 7500×7500 | Arc 6 |
| warp_marches | The Warp Marches | Unknown | 5 | 8000×8000 | Arc 7 |
| cradle_of_whispers | The Cradle of Whispers | Ancient Guardians | 5 | 10000×10000 | Arc 9 (hidden) |

The Cradle of Whispers is a **hidden region** that requires completing extensive prerequisites across multiple arcs (see Arc 9 unlock conditions).

### Star Map & Fog of War

Each region has a fog of war grid (64px cells) that the player reveals through exploration. Star charts can be purchased to reveal a percentage of a region's map. A special **Fairy Cartographer rescue** encounter can reveal additional map data.

**11 purchasable star charts:**

| Chart | Region | Cost (Crystals) | Reveals |
| ------ | ------ | ----------------- | --------- |
| Feline Courts Star Chart | Feline Courts | 15 | 60% |
| Goblin Warrens Star Chart | Goblin Warrens | 15 | 60% |
| Fairy Realms Star Chart | Fairy Realms | 20 | 60% |
| Shattered Prides Star Chart | Shattered Prides | 20 | 60% |
| Canine Order Star Chart | Canine Order | 25 | 60% |
| Knight Kingdoms Star Chart | Knight Kingdoms | 25 | 60% |
| Twilight Bazaar Star Chart | Twilight Bazaar | 10 | 70% |
| Iron Expanse Star Chart | Iron Expanse | 30 | 55% |
| Bone Yard Salvage Chart | Bone Yard | 30 | 50% |
| Deep Space Star Chart | Deep Space | 40 | 50% |
| Warp Marches Star Chart | Warp Marches | 45 | 45% |

### Points of Interest

Regions contain discoverable POIs:

- **Wrecks** — Derelict ships with salvage rewards
- **Deposits** — Hidden crystal caves
- **Settlements** — Trading posts (e.g., Goblin Black Market)
- **Anomalies** — Mysterious phenomena with mixed rewards
- **Spawn zones** — Areas where encounters dynamically respawn on timers (30–90 seconds)

---

## Combat System

Combat is tactical, with outcomes determined by ship stats, crew bonuses, and faction abilities:

- **Firepower vs Armour** — Damage dealt minus damage reduction
- **Speed** — Affects evasion and initiative
- **Crew traits** — Gunners add firepower/critical hit bonuses, navigators improve evasion
- **Faction abilities** — Wolves get first-strike bonuses, League gets formation armour, Corsairs get ambush evasion

Combat can be triggered by:

- Story encounters escalating to violence
- Hostile faction patrols in dangerous regions
- Ambushes on supply routes
- Player choice (choosing to fight instead of negotiate)

---

## Crew Morale System

Crew morale affects ship performance and encounter options:

- **High morale** — Bonuses to combat effectiveness and crew loyalty
- **Low morale** — Risk of desertion, reduced performance
- **Morale recovery** — Boosted by surgeon crew members (Blood Paw, Thistle, Charlie)
- **Morale damage** — Caused by brutal player choices (e.g., purging ranks), heavy combat losses, or poor resource management

---

## Distress Signals

Throughout the game, **10 repeatable random encounters** can appear across regions. Five are universal (any region), and five are **region-specific** to the new territories. These are moral dilemmas that affect faction reputation and resources:

### Universal Distress Signals

1. **Stranded Merchant** — A freighter with a dead crystal drive. Help (lose crystals, gain reputation), ignore, or exploit (steal cargo, lose reputation).
2. **Crippled Warship** — A damaged Canis League patrol vessel. Help for free (major League rep boost), help for a price, or leave them.
3. **Escape Pod** — Could be a grateful survivor with crystals, a goblin trap, or nothing.
4. **Faint Signal** — Likely a pirate ambush. Investigate cautiously (fight off goblins), rush in (get trapped), or avoid entirely.
5. **Lion Tribute Ship** — A Lion transport with a failed drive, drifting toward an asteroid field. Help freely (massive Lion rep), demand payment (get crystals), or ignore.

### Region-Specific Distress Signals

1. **Damaged Wolf Patrol** (Iron Expanse) — An Iron Wolf patrol vessel drifts with hull breached and engines cold. Wolves asking for help is nearly unheard of. Help earns safe passage codes; negotiate for patrol route data.
2. **Spatial Anomaly Trap** (Warp Marches) — A merchant vessel caught phasing in and out of reality. Time is broken. Use crystal drive to stabilise, claim anomaly data, or risk the ship being lost between seconds forever.
3. **Trapped Scavenger** (Bone Yard) — A scavenger pinned under thousands of tons of collapsing derelict. Calm, methodical, resigned. Tractor beam rescue, negotiate for salvage rights, or leave another ship to the graveyard.
4. **Smuggler Under Fire** (Twilight Bazaar) — A fast ship taking fire from customs enforcers near the Bazaar. "Medical supplies, I swear!" Intervene, mediate, or stay out of it.
5. **Lion Refugees** (Shattered Prides) — Three transports packed with families fleeing the civil war, running on fumes and prayer. Share crystals and escort to safety, trade help for intelligence, or fly on.

---

## Save System

The game supports **3 save slots** with full game state persistence, including:

- Current arc (1–10) and all story flags (hundreds across the expanded narrative)
- Ship stats, upgrades, and inventory
- Crew roster and recruitment status
- Faction relationships (8 factions)
- Star map fog of war grids (13 regions)
- Special character encounter states (22 NPCs)
- Choice history and cumulative outcome_weight (used for ending calculation)
- Crystal deposits and supply route states
- Cradle unlock progress chain
- Owned purchasable maps (11 charts)

---

## How Decisions Shape the Game

### Cumulative Choice System

Every major choice carries an **outcome_weight** that accumulates over the entire game. This weight determines the ending:

- **Positive weights** (consolidating power, refusing to share, aggressive tactics) → push toward **Ending A (Hold)**
- **Neutral weights** (balanced diplomacy, cooperation, measured responses) → push toward **Ending B (Share)**
- **Negative weights** (destruction, chaos, nihilism, failed gambits) → push toward **Ending C (Destroy)**
- **Cradle completion** (hidden arc + healing choice) → unlocks **Ending D (Reunite)** regardless of weight

### Story Flags

The game tracks **hundreds of story flags** that gate encounters and modify available options. Key categories include:

- **Arc progression flags** — `arc1_crystal_discovered`, `arc1_dave_met`, `arc1_death_glimpsed`, `arc2_route_resolved`, `arc2_death_betrayal`, `arc3_alien_contact`, `arc3_dave_parley`, `arc3_death_allegiance`, etc.
- **Death's allegiance** — `death_serves_lions` / `death_serves_wolves` / `death_independent` — Determines which Sovereign faction appears in Arc 10.
- **Special character flags** — `special_char_{name}_met` for all 22 special characters, plus relationship flags like `lord_mane_respected`, `iron_fang_respect`, `glimmer_gift`, `echo_restored`, etc.
- **Cradle unlock chain** — `arc3_alien_contact`, `arc5_fairy_deep_secret`, `arc6_ancient_signal_decoded`, `arc7_crystal_communion`, `fairy_cartographer_rescued`, `cradle_clue_bone_yard`, `cradle_clue_warp_marches`, `cradle_clue_shattered_prides`, `special_char_oracle_met`, `special_char_keeper_met` — all required to access the hidden Cradle of Whispers region and Arc 9.
- **Crew flags** — `crew_{id}_recruited` — Tracks which crew members have been recruited, affecting available abilities and dialogue.
- **Builder knowledge chain** — `crystal_knowledge_enhanced`, `crystal_origin_hint`, `builder_knowledge`, `builder_schematics`, `crystal_sensitivity` — progressive understanding of crystal origins.

### Faction Cascade Effects

Choices don't just affect the target faction. **Cascade rules** propagate changes:

- Helping the Canis League also improves Wolves by 50% of the change
- Helping the Wolves also improves the League by 30%
- Helping the Lions automatically *hurts* the Corsairs by 30%
- Helping the Corsairs automatically *hurts* the Lions by 20%

This means there is no "safe" choice — every alliance has consequences.

---

## Visual Style

- **Aesthetic:** Spelljammer-inspired — serious stakes with accessible, anthropomorphic characters
- **Palette:** Deep space blacks and blues contrasted with warm ship interiors and crystal glow effects
- **Cat ships:** Asymmetric, jury-rigged, pirate flags, visible crystal fuel chambers
- **Dog ships:** Symmetrical, heavy plating, military markings, fleet formations
- **Lion ships:** Ornate gold filigree, cathedral-ship aesthetic, stained glass viewports
- **Wolf ships:** Streamlined predators, dark paint, low-visibility tactical profiles
- **Crystals:** Soft pulsing glow (blue-white core, purple edges), subtle "whisper" particle trails

---

## Technical Summary

- **Engine:** Godot 4.6, GL Compatibility renderer
- **Language:** GDScript with static typing
- **Resolution:** 1280×720, canvas_items stretch mode
- **Target:** Desktop (Mac M3/M4 primary, Windows compatible)
- **Architecture:** Data-driven (all content in JSON), event bus pattern, autoload singletons (EventBus, GameSession, MusicManager, ProceduralMapManager)
- **State:** Core game (Arcs 1-4, 7 regions, 3 endings) fully playable. Expansion content (Arcs 5-10, 6 additional regions, 4th ending) has data files but is not integration-tested. See `docs/MASTER_PLAN.md` for detailed status.
- **Known Issues:** See `docs/CODE_REVIEW_2026-04-05.md` for 18 issues including 2 critical bugs
