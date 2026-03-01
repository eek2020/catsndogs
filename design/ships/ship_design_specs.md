# Whisper Crystals — Ship Design Specifications

---

## Ship Stat Ranges

All ship stats use a 1–10 scale. Base templates define starting values; upgrades and crew modify these.

| Stat | Description | Gameplay Effect |
|------|-------------|-----------------|
| Speed | Velocity and acceleration | Movement speed in navigation; dodge chance in combat |
| Armour | Hull durability | Damage reduction per hit; higher = more hits to destroy |
| Firepower | Weapon strength | Damage dealt per hit; affects combat encounter duration |
| Crystal Capacity | Fuel/cargo storage | Max crystals carriable; affects trade volume and travel range |
| Crew Capacity | Max crew slots | More crew = more role bonuses; affects boarding actions |

---

## Faction Ship Templates

### Felid Corsair Ships

**Corsair Raider (Player starting ship)**

| Stat | Value |
|------|-------|
| Speed | 8 |
| Armour | 3 |
| Firepower | 5 |
| Crystal Capacity | 6 |
| Crew Capacity | 4 |

- Visual: Sleek, asymmetric, jury-rigged panels, visible crystal fuel chamber
- Strengths: Fastest in the game, excellent dodge rating
- Weaknesses: Low armour means a few hits can be devastating

**Corsair Smuggler** (upgrade path)

| Stat | Value |
|------|-------|
| Speed | 7 |
| Armour | 3 |
| Firepower | 4 |
| Crystal Capacity | 9 |
| Crew Capacity | 3 |

- Visual: Wider hull with hidden cargo bays
- Role: Trade-focused; maximises crystal transport

**Corsair Interceptor** (upgrade path)

| Stat | Value |
|------|-------|
| Speed | 9 |
| Armour | 2 |
| Firepower | 7 |
| Crystal Capacity | 4 |
| Crew Capacity | 3 |

- Visual: Narrow, blade-like, twin engines
- Role: Combat-focused; glass cannon

---

### Canis League Ships

**League Cruiser (Dave's fleet standard)**

| Stat | Value |
|------|-------|
| Speed | 4 |
| Armour | 8 |
| Firepower | 7 |
| Crystal Capacity | 5 |
| Crew Capacity | 8 |

- Visual: Broad, symmetrical, heavy plating, gun turrets, military markings
- Strengths: High survivability, strong firepower, large crew for boarding
- Weaknesses: Slow, fuel-hungry

**League Destroyer** (elite combat)

| Stat | Value |
|------|-------|
| Speed | 3 |
| Armour | 9 |
| Firepower | 9 |
| Crystal Capacity | 4 |
| Crew Capacity | 10 |

- Visual: Massive, bristling with weapons
- Role: Boss-level threat in combat encounters

---

### Lion Ships

**Royal Galleon**

| Stat | Value |
|------|-------|
| Speed | 5 |
| Armour | 6 |
| Firepower | 5 |
| Crystal Capacity | 7 |
| Crew Capacity | 6 |

- Visual: Ornate gold filigree, stained glass viewports, carved prow
- Role: Diplomatic/trade encounters; balanced stats

---

### Wolf Ships

**Wolf Strike Craft**

| Stat | Value |
|------|-------|
| Speed | 6 |
| Armour | 7 |
| Firepower | 8 |
| Crystal Capacity | 4 |
| Crew Capacity | 7 |

- Visual: Dark, streamlined predator shape, minimal decoration
- Role: Toughest combat opponents; tactical strike missions

---

## Upgrade System

### Upgrade Slots

Each ship has 3 upgrade slots. Upgrades are purchased from friendly ports or looted from encounters.

### Available Upgrades (Phase 1)

| Upgrade | Target Stat | Modifier | Crystal Cost | Salvage Cost |
|---------|------------|----------|-------------|-------------|
| Reinforced Hull | Armour | +1 | 20 | 10 |
| Turbocharger | Speed | +1 | 25 | 15 |
| Heavy Guns | Firepower | +1 | 30 | 20 |
| Crystal Compressor | Crystal Capacity | +1 | 15 | 5 |
| Expanded Quarters | Crew Capacity | +1 | 10 | 15 |
| Stealth Plating | Speed | +1, Armour -1 | 35 | 25 |
| Siege Cannons | Firepower | +2, Speed -1 | 40 | 30 |

---

## Crew Roles and Bonuses

| Role | Primary Stat Affected | Bonus per Skill Level |
|------|----------------------|----------------------|
| Pilot | Speed | +2% per skill level |
| Gunner | Firepower | +2% per skill level |
| Engineer | Armour (repair rate) | +2% per skill level |
| Diplomat | Trade pricing | +2% per skill level |

### Faction Crew Traits

| Crew Origin | Bonus |
|------------|-------|
| Felid Corsairs | +5% Speed (manoeuvrability) |
| Canis League | +5% Armour (discipline) |
| Goblins | +10% Salvage from encounters |
| Fairies | +5% Trade pricing (intel advantage) |
| Knights | +5% Firepower (martial training) |

---

## Damage Model

- Each hit reduces hull by `attacker_firepower - defender_armour` (minimum 1 damage)
- At 50% hull: visual damage effects (smoke, sparks)
- At 25% hull: critical warning, stat penalties (-1 to all stats)
- At 0% hull: ship destroyed (player gets rescue/reload; NPC ships become loot)
- Repair: costs crystals + salvage at friendly ports; engineer crew accelerates passive repair
