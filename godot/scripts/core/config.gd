## Global constants — shared configuration for game systems and UI.
##
## Centralises values that were scattered as magic numbers across scripts.
## For colour palette and font sizes, see ThemeBuilder.
## (Code Review Issue #9)
class_name Config
extends RefCounted

# --- Display ---
const SCREEN_WIDTH: int = 1280
const SCREEN_HEIGHT: int = 720

# --- Stat limits ---
const STAT_MIN: int = 0
const STAT_MAX: int = 10
const STAT_POINTS_PER_LEVEL: int = 2
const REPUTATION_MIN: int = -100
const REPUTATION_MAX: int = 100

# --- Economy ---
const SELL_PRICE_RATIO: float = 0.75      # sell price = buy price × this
const MAX_SUPPLY_MODIFIER: float = 2.0
const MAX_DEMAND_MULTIPLIER: float = 2.5
const MIN_DEMAND_MULTIPLIER: float = 0.5

# --- Combat ---
const DAMAGE_VARIANCE_MIN: float = 0.8
const DAMAGE_VARIANCE_MAX: float = 1.2
const CRIT_MULTIPLIER: float = 1.5
const MAX_DODGE_CHANCE: float = 0.55
const DODGE_PER_SPEED: float = 0.04

# --- Animation / UI timing ---
const TYPEWRITER_SPEED: float = 0.025     # seconds per character
const FADE_DURATION: float = 0.5
const COMBAT_TURN_DELAY: float = 0.8

# --- Save system ---
const MAX_SAVE_SLOTS: int = 3
