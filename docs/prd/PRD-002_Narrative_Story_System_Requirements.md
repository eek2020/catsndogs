# PRD-002: Narrative & Story System Requirements

**Project:** Whisper Crystals — A Space Pirates Game  
**Version:** 0.1  
**Date:** February 2026  
**Classification:** Creative Development — Confidential  

---

## Section 1: Narrative Vision

Whisper Crystals tells the story of Aristotle, a street cat who discovered the multiverse's only source of starship fuel and built a pirate empire before anyone else understood what he had. The narrative explores what happens when an outsider holds the most valuable resource in existence — and everyone from noble lions to military dogs wants to take it.

The tone is Spelljammer-inspired: serious stakes delivered through a cast of cats, dogs, wolves, lions, fairies, and aliens. The narrative is driven by strategic tradeoffs, not binary morality. Every choice has consequences measured in faction loyalty, resource access, and survival.

---

## Section 2: Story Arc Requirements

### Arc 1 — The Upstart (Origin)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-001 | Arc 1 Entry Condition: New game start. Player begins as Aristotle with a single ship, minimal crew, and the first Whisper Crystal deposit | MUST HAVE | Arc 1 loads on new game; initial game state is correctly initialised; tutorial elements introduce core mechanics |
| PRD002-REQ-002 | Key Event — Crystal Discovery: Aristotle discovers the refining process for Whisper Crystals in a forgotten realm | MUST HAVE | Discovery event triggers via exploration encounter; crystal refining mechanic is introduced; story flag `arc1_crystal_discovered` is set |
| PRD002-REQ-003 | Key Event — First Contact with Dave: A tense trade negotiation encounter introduces Dave and the Canis League's interest in crystals | MUST HAVE | Trade/diplomatic encounter triggers with Dave NPC; player makes first strategic choice (share intel / withhold / bluff); story flag `arc1_dave_met` is set; faction score `canis_league` adjusts based on choice |
| PRD002-REQ-004 | Key Event — Death's Shadow: A brief, atmospheric encounter hints at Death observing Aristotle from the shadows | MUST HAVE | Cutscene or narrative encounter plays; no player choice required; story flag `arc1_death_glimpsed` is set |
| PRD002-REQ-005 | Arc 1 Decision Point: Player chooses initial stance — aggressive expansion, cautious trade, or isolationist defence | MUST HAVE | Choice is presented via dialogue UI; selection sets `arc1_stance` flag; faction scores adjust; resource allocation changes |
| PRD002-REQ-006 | Arc 1 Exit Condition: Player has established crystal production, met Dave, and glimpsed Death; all three story flags are set | MUST HAVE | Arc transition triggers when `arc1_crystal_discovered`, `arc1_dave_met`, and `arc1_death_glimpsed` are all true; narrative summary plays; arc 2 content unlocks |

### Arc 2 — The Squeeze (Rising Pressure)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-010 | Arc 2 Entry Condition: Arc 1 complete; all Arc 1 exit flags are set | MUST HAVE | Arc 2 content loads; new encounters, regions, and NPCs become available |
| PRD002-REQ-011 | Key Event — Supply Route Seizure: Dave's forces blockade a major crystal supply route; player must negotiate, fight, or find alternative routes | MUST HAVE | Event triggers as story-scripted encounter; three resolution paths available; story flag `arc2_route_resolved` set with method (`negotiate` / `fight` / `reroute`); faction scores adjust accordingly |
| PRD002-REQ-012 | Key Event — Death's Betrayal: Death orchestrates a mutiny or sabotage within the Felid Corsairs | MUST HAVE | Event triggers as narrative encounter; player discovers betrayal; story flag `arc2_death_betrayal` is set; corsair fleet strength is temporarily reduced |
| PRD002-REQ-013 | Key Event — Lion Tribute Demand: The Lions demand Aristotle pay tribute, claiming birthright over crystals | MUST HAVE | Diplomatic encounter with Lion faction; player chooses to pay / refuse / counter-offer; story flag `arc2_lion_response` set; `lions` faction score adjusts |
| PRD002-REQ-014 | Key Event — Alliance Offer: A multiverse faction (Fairies, Knights, or Aliens) offers alliance with conditions | SHOULD HAVE | Diplomatic encounter presents alliance terms; acceptance modifies faction scores and unlocks resources; refusal closes that path for Arc 2 |
| PRD002-REQ-015 | Arc 2 Decision Point: Player chooses primary front — focus on external threat (Dave), internal threat (Death), or political threat (Lions) | MUST HAVE | Choice affects resource allocation and available missions in Arc 3; story flag `arc2_priority` set |
| PRD002-REQ-016 | Arc 2 Exit Condition: Route crisis resolved, Death betrayal discovered, and Lion demand addressed | MUST HAVE | Arc transition when `arc2_route_resolved`, `arc2_death_betrayal`, and `arc2_lion_response` are all set |

### Arc 3 — The Alliance (Unlikely Partners)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-020 | Arc 3 Entry Condition: Arc 2 complete; all Arc 2 exit flags are set | MUST HAVE | Arc 3 content loads; new diplomatic options and regions available |
| PRD002-REQ-021 | Key Event — Alien Summit: Aristotle meets a faction leader from a completely alien universe, establishing multiverse scale | MUST HAVE | Diplomatic encounter with alien NPC; world-building dialogue; story flag `arc3_alien_contact` set |
| PRD002-REQ-022 | Key Event — Aristotle and Dave Scene: A tense, almost respectful meeting between the two leaders; both acknowledge the coming final conflict | MUST HAVE | Narrative encounter with Dave; no combat; dialogue choices affect final arc setup; story flag `arc3_dave_parley` set |
| PRD002-REQ-023 | Key Event — Death's Allegiance Revealed: Player discovers whether Death works for Lions, Wolves, or an independent agenda | MUST HAVE | Revelation encounter; outcome depends on player investigation choices in Arc 2; story flag `arc3_death_allegiance` set to `lions` / `wolves` / `independent` |
| PRD002-REQ-024 | Arc 3 Decision Point: Player builds alliance portfolio — which factions to ally with and which to oppose | MUST HAVE | Multiple diplomatic encounters available; each alliance choice modifies faction matrix; cumulative choices feed ending calculation |
| PRD002-REQ-025 | Arc 3 Exit Condition: Alien contact made, Dave parley complete, Death allegiance known | MUST HAVE | Arc transition when all three flags set |

### Arc 4 — The Reckoning (Final Conflict)

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-030 | Arc 4 Entry Condition: Arc 3 complete; all Arc 3 exit flags are set | MUST HAVE | Arc 4 content loads; all faction states are locked for final conflict |
| PRD002-REQ-031 | Key Event — Dave's Assault: Dave launches a full-scale military campaign against crystal production sites | MUST HAVE | Multi-stage combat encounter chain; player defends key locations; outcomes affect crystal reserves |
| PRD002-REQ-032 | Key Event — Death's Power Grab: Death makes a final bid to seize crystal production from Aristotle | MUST HAVE | Internal conflict encounter; player confronts Death; resolution depends on prior arc choices |
| PRD002-REQ-033 | Key Event — Lion/Wolf Declaration: The Lions and Wolves declare their ultimate intent regarding crystals | MUST HAVE | Diplomatic/narrative encounter; factions reveal positions; player's prior relationship determines tone |
| PRD002-REQ-034 | Arc 4 Final Decision: Player chooses ending path based on cumulative choice history | MUST HAVE | Ending is calculated from weighted choice history, not a single selection; ending path is determined by `outcome_weights` thresholds |

---

## Section 3: Dialogue System Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-040 | Dialogue Trees: All narrative and diplomatic encounters use branching dialogue trees loaded from JSON data files | MUST HAVE | Dialogue data is stored in `data/dialogue/`; trees support branching, conditional nodes, and variable insertion |
| PRD002-REQ-041 | Dialogue UI: Character portrait, name plate, dialogue text with typewriter effect, and 2–4 response buttons | MUST HAVE | UI renders correctly; text speed is adjustable; responses are selectable via mouse or keyboard |
| PRD002-REQ-042 | Conditional Dialogue: Dialogue options and NPC responses can be gated by story flags, faction scores, or resource levels | MUST HAVE | Conditions are evaluated at runtime; unavailable options are hidden (not greyed out); fallback dialogue exists |
| PRD002-REQ-043 | Dialogue Consequences: Each player dialogue selection can trigger one or more consequence actions — flag set, faction score change, resource change, encounter trigger | MUST HAVE | Consequences fire immediately on selection; multiple consequences per choice are supported; consequences are defined in dialogue data |

---

## Section 4: Narrative Choice & Consequence Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-050 | Choice Presentation: Narrative choices are presented through the dialogue UI at defined story beats; choices show 2–4 options with brief consequence hints | MUST HAVE | Hints do not reveal exact outcome; choices are non-reversible once confirmed |
| PRD002-REQ-051 | Consequence Tracking: All player choices are recorded in a persistent `player_decisions[]` array with timestamps, choice IDs, and `outcome_weights` | MUST HAVE | Decision array persists across sessions via save system; array is queryable for ending calculation |
| PRD002-REQ-052 | Strategic Tradeoffs: No choice is binary good/evil; all choices involve short-term vs long-term tradeoffs (e.g., gain resources now but damage faction standing) | MUST HAVE | Each choice has at least one positive and one negative consequence; QA review confirms no objectively dominant options |
| PRD002-REQ-053 | Ending Calculation: Arc 4 ending is determined by weighted sum of `outcome_weights` from all prior decisions, evaluated against three threshold ranges (Hold / Share / Destroy) | MUST HAVE | Ending calculation is deterministic; same choice history always produces same ending; thresholds are configurable in data files |

---

## Section 5: Whisper Crystal Commodity System Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-060 | Crystal Inventory: Player maintains a crystal inventory with `quantity`, `quality` (grade), and `location` (which ship/depot holds them) | MUST HAVE | Inventory displays in HUD and ship management screen; values update on trade, mining, and combat events |
| PRD002-REQ-061 | Supply/Demand Mechanics: Crystal pricing varies by faction demand, current supply levels, and story state (e.g., blockades increase prices) | MUST HAVE | Price calculations are data-driven; prices update after significant events; price info is visible in trade UI |
| PRD002-REQ-062 | Trade Events: Crystal trade encounters allow player to set prices, negotiate, and finalise deals with faction NPCs | MUST HAVE | Trade flow: player offer → NPC counter → accept/reject; faction standing modifies NPC flexibility |
| PRD002-REQ-063 | Supply Route Defence: Crystal supply routes can be attacked by hostile factions; player must defend or reroute | SHOULD HAVE | Supply route status is tracked; attacks trigger combat encounters; lost routes reduce income until restored |
| PRD002-REQ-064 | Crystal Production: Player manages production sites — assigning crew and resources to maintain output | SHOULD HAVE | Production rate is calculable from assigned resources; production data persists in save |

---

## Section 6: Ending Requirements

| REQ-ID | Description | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PRD002-REQ-070 | Ending A — Hold the Monopoly: Aristotle retains exclusive control of Whisper Crystal production; he wins but rules alone; the multiverse depends entirely on him | MUST HAVE | Triggers when `outcome_weights` sum falls in "hold" threshold range; ending cutscene plays; story flags confirm all factions remain dependent; end state saves |
| PRD002-REQ-071 | Ending B — Share the Crystals: Aristotle distributes crystal production knowledge across factions; power spreads; he gives up control but breaks the cycle of war | MUST HAVE | Triggers when `outcome_weights` sum falls in "share" threshold range; ending cutscene shows power redistribution; faction scores equalise; end state saves |
| PRD002-REQ-072 | Ending C — Destroy the Sites: Aristotle destroys all crystal production sites rather than let anyone control them; no one wins; the multiverse must find another way | MUST HAVE | Triggers when `outcome_weights` sum falls in "destroy" threshold range; ending cutscene shows destruction; crystal inventory zeroes; end state saves |
| PRD002-REQ-073 | Ending Summary Screen: After ending cutscene, display a summary of key decisions made, factions affected, and final state of the multiverse | SHOULD HAVE | Summary shows 5–10 key decisions; faction relationship final states; total playtime; option to save completed game |

---

*Cross-references: See PRD-003 for character and faction entity definitions. See TRD-003 for data models of story flags, choice history, and crystal resources.*

*PRD-002 v0.1 | Whisper Crystals | Creative Development Confidential*
