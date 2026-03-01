# TRD-002: Game Engine & Prototype Specification

**Project:** Whisper Crystals — A Space Pirates Game  
**Version:** 0.1  
**Date:** February 2026  
**Classification:** Creative Development — Confidential  

---

## Section 1: Pygame Setup & Environment

### Installation

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install pygame-ce==2.4.1
```

### Display Initialisation

```python
import pygame

SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FPS = 60

pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Whisper Crystals")
clock = pygame.time.Clock()
```

### Mac M3/M4 Notes

- pygame-ce uses SDL2 with Metal rendering backend on macOS by default
- No Rosetta emulation needed if using ARM64 Python
- Set `SDL_RENDER_DRIVER=metal` environment variable if auto-detection fails
- Retina displays: use `pygame.SCALED` flag for automatic DPI scaling

---

## Section 2: Game Loop Implementation Pattern

The game loop follows a fixed-timestep model with variable rendering. All game logic operates on delta-time to ensure consistent behaviour regardless of frame rate.

```python
class GameLoop:
    def __init__(self, state_machine, renderer, input_handler):
        self.state_machine = state_machine
        self.renderer = renderer
        self.input_handler = input_handler
        self.running = True
        self.clock = pygame.time.Clock()

    def run(self):
        while self.running:
            dt = self.clock.tick(FPS) / 1000.0  # Delta time in seconds

            # Phase 1: Input
            events = pygame.event.get()
            actions = self.input_handler.process(events)

            # Phase 2: Check for quit
            for event in events:
                if event.type == pygame.QUIT:
                    self.running = False

            # Phase 3: Update active state
            self.state_machine.current_state.handle_input(actions)
            self.state_machine.current_state.update(dt)

            # Phase 4: Render
            self.renderer.clear()
            self.state_machine.current_state.render(self.renderer)
            self.renderer.present()

        pygame.quit()
```

### Loop Phases

1. **Input Collection** — Pygame events are polled and translated to engine-agnostic action enums
2. **State Update** — The active state processes input and advances game logic using delta-time
3. **Rendering** — The active state draws to the renderer; renderer presents the frame
4. **Timing** — Clock enforces target FPS; delta-time is passed to all update calls

---

## Section 3: State Machine Specification

The state machine uses a stack-based model supporting push (overlay), pop (return), and switch (replace) operations.

```python
from enum import Enum, auto
from abc import ABC, abstractmethod

class GameStateType(Enum):
    MENU = auto()
    NAVIGATION = auto()
    COMBAT = auto()
    TRADE = auto()
    DIALOGUE = auto()
    CUTSCENE = auto()
    PAUSE = auto()
    END = auto()

class GameState(ABC):
    """Base class for all game states."""

    @abstractmethod
    def enter(self):
        """Called when this state becomes active."""
        pass

    @abstractmethod
    def exit(self):
        """Called when this state is deactivated."""
        pass

    @abstractmethod
    def handle_input(self, actions: list):
        """Process player input actions."""
        pass

    @abstractmethod
    def update(self, dt: float):
        """Update game logic for this frame."""
        pass

    @abstractmethod
    def render(self, renderer):
        """Draw this state's visuals."""
        pass

class GameStateMachine:
    def __init__(self):
        self._stack: list[GameState] = []

    @property
    def current_state(self) -> GameState | None:
        return self._stack[-1] if self._stack else None

    def push(self, state: GameState):
        """Push a new state on top (e.g., pause overlay)."""
        if self._stack:
            self._stack[-1].exit()
        self._stack.append(state)
        state.enter()

    def pop(self):
        """Remove the top state and resume the one below."""
        if self._stack:
            self._stack[-1].exit()
            self._stack.pop()
        if self._stack:
            self._stack[-1].enter()

    def switch(self, state: GameState):
        """Replace the top state (e.g., menu → navigation)."""
        if self._stack:
            self._stack[-1].exit()
            self._stack.pop()
        self._stack.append(state)
        state.enter()
```

### State Transitions

```
MENU → (New Game) → NAVIGATION
MENU → (Continue) → NAVIGATION (from save)
NAVIGATION → (Encounter Trigger) → COMBAT | TRADE | DIALOGUE
NAVIGATION → (Story Beat) → CUTSCENE
NAVIGATION → (Pause Key) → PAUSE [pushed on top]
COMBAT → (Victory/Defeat/Flee) → NAVIGATION
TRADE → (Complete/Cancel) → NAVIGATION
DIALOGUE → (Complete) → NAVIGATION | COMBAT | TRADE
CUTSCENE → (Complete) → NAVIGATION
PAUSE → (Resume) → [pop to previous]
PAUSE → (Quit) → MENU
ANY → (Arc Complete + Final) → END
```

---

## Section 4: Rendering Pipeline

### Layer Order (back to front)

1. **Background** — Parallax space background (star field, nebulae)
2. **Environment** — Realm-specific environmental elements (asteroids, stations)
3. **Entities** — Ships, characters, projectiles (sorted by y-position or depth)
4. **Effects** — Particle effects, explosions, crystal glow
5. **UI** — HUD elements, dialogue boxes, trade panels
6. **Overlay** — Pause screen, fade transitions

```python
class Renderer:
    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        self.camera = Camera(SCREEN_WIDTH, SCREEN_HEIGHT)

    def clear(self):
        self.screen.fill((0, 0, 0))

    def draw_sprite(self, sprite: pygame.Surface, world_pos: tuple[float, float]):
        screen_pos = self.camera.world_to_screen(world_pos)
        self.screen.blit(sprite, screen_pos)

    def draw_text(self, text: str, pos: tuple[int, int], font: pygame.font.Font,
                  color: tuple[int, int, int] = (255, 255, 255)):
        surface = font.render(text, True, color)
        self.screen.blit(surface, pos)

    def draw_rect(self, rect: pygame.Rect, color: tuple[int, int, int],
                  width: int = 0):
        pygame.draw.rect(self.screen, color, rect, width)

    def present(self):
        pygame.display.flip()
```

### Camera System

```python
class Camera:
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.x = 0.0
        self.y = 0.0

    def world_to_screen(self, world_pos: tuple[float, float]) -> tuple[int, int]:
        return (int(world_pos[0] - self.x), int(world_pos[1] - self.y))

    def follow(self, target_pos: tuple[float, float], dt: float,
               smoothing: float = 5.0):
        self.x += (target_pos[0] - self.width / 2 - self.x) * smoothing * dt
        self.y += (target_pos[1] - self.height / 2 - self.y) * smoothing * dt
```

---

## Section 5: Encounter Engine Design

The encounter engine is an event-driven dispatcher that routes encounter triggers to the appropriate handler system.

```python
from enum import Enum, auto
from dataclasses import dataclass

class EncounterType(Enum):
    COMBAT = auto()
    TRADE = auto()
    DIPLOMATIC = auto()
    EXPLORATION = auto()

@dataclass
class EncounterTrigger:
    encounter_id: str
    encounter_type: EncounterType
    conditions: dict          # Story flags, location, faction state
    priority: int             # Higher priority encounters override lower

class EncounterEngine:
    def __init__(self, data_loader, state_machine, event_bus):
        self.data_loader = data_loader
        self.state_machine = state_machine
        self.event_bus = event_bus
        self.encounter_table: list[EncounterTrigger] = []
        self.handlers = {
            EncounterType.COMBAT: self._start_combat,
            EncounterType.TRADE: self._start_trade,
            EncounterType.DIPLOMATIC: self._start_diplomatic,
            EncounterType.EXPLORATION: self._start_exploration,
        }

    def load_encounters(self, arc_id: str):
        """Load encounter definitions for the current story arc."""
        self.encounter_table = self.data_loader.load_encounters(arc_id)

    def check_triggers(self, game_state: dict) -> EncounterTrigger | None:
        """Evaluate all encounter triggers against current game state."""
        for trigger in sorted(self.encounter_table, key=lambda t: -t.priority):
            if self._evaluate_conditions(trigger.conditions, game_state):
                return trigger
        return None

    def dispatch(self, trigger: EncounterTrigger):
        """Route to the appropriate encounter handler."""
        handler = self.handlers.get(trigger.encounter_type)
        if handler:
            handler(trigger)

    def _evaluate_conditions(self, conditions: dict, game_state: dict) -> bool:
        """Check if all trigger conditions are met."""
        for key, expected in conditions.items():
            if game_state.get(key) != expected:
                return False
        return True

    def _start_combat(self, trigger: EncounterTrigger):
        combat_state = CombatState(trigger, self.event_bus)
        self.state_machine.push(combat_state)

    def _start_trade(self, trigger: EncounterTrigger):
        trade_state = TradeState(trigger, self.event_bus)
        self.state_machine.push(trade_state)

    def _start_diplomatic(self, trigger: EncounterTrigger):
        dialogue_state = DialogueState(trigger, self.event_bus)
        self.state_machine.push(dialogue_state)

    def _start_exploration(self, trigger: EncounterTrigger):
        exploration_state = ExplorationState(trigger, self.event_bus)
        self.state_machine.push(exploration_state)
```

---

## Section 6: Input Handling

Input is abstracted into action enums to decouple game logic from specific key bindings.

```python
from enum import Enum, auto

class Action(Enum):
    MOVE_UP = auto()
    MOVE_DOWN = auto()
    MOVE_LEFT = auto()
    MOVE_RIGHT = auto()
    FIRE = auto()
    INTERACT = auto()
    PAUSE = auto()
    CONFIRM = auto()
    CANCEL = auto()
    MENU_UP = auto()
    MENU_DOWN = auto()

# Default key mapping (configurable)
DEFAULT_KEY_MAP = {
    pygame.K_w: Action.MOVE_UP,
    pygame.K_s: Action.MOVE_DOWN,
    pygame.K_a: Action.MOVE_LEFT,
    pygame.K_d: Action.MOVE_RIGHT,
    pygame.K_SPACE: Action.FIRE,
    pygame.K_e: Action.INTERACT,
    pygame.K_ESCAPE: Action.PAUSE,
    pygame.K_RETURN: Action.CONFIRM,
    pygame.K_BACKSPACE: Action.CANCEL,
    pygame.K_UP: Action.MENU_UP,
    pygame.K_DOWN: Action.MENU_DOWN,
}

class InputHandler:
    def __init__(self, key_map: dict = None):
        self.key_map = key_map or DEFAULT_KEY_MAP
        self.active_actions: set[Action] = set()

    def process(self, events: list[pygame.event.Event]) -> list[Action]:
        """Convert raw Pygame events to game actions."""
        triggered = []
        for event in events:
            if event.type == pygame.KEYDOWN:
                action = self.key_map.get(event.key)
                if action:
                    triggered.append(action)
                    self.active_actions.add(action)
            elif event.type == pygame.KEYUP:
                action = self.key_map.get(event.key)
                if action:
                    self.active_actions.discard(action)
        return triggered

    def is_held(self, action: Action) -> bool:
        """Check if an action key is currently held down."""
        return action in self.active_actions
```

---

## Section 7: Asset Management

Assets are loaded once and cached by ID for efficient reuse.

```python
import os

class AssetManager:
    def __init__(self, base_path: str = "assets"):
        self.base_path = base_path
        self._sprite_cache: dict[str, pygame.Surface] = {}
        self._font_cache: dict[tuple[str, int], pygame.font.Font] = {}
        self._sound_cache: dict[str, pygame.mixer.Sound] = {}

    def load_sprite(self, relative_path: str) -> pygame.Surface:
        """Load and cache a sprite image."""
        if relative_path not in self._sprite_cache:
            full_path = os.path.join(self.base_path, "sprites", relative_path)
            image = pygame.image.load(full_path).convert_alpha()
            self._sprite_cache[relative_path] = image
        return self._sprite_cache[relative_path]

    def load_font(self, name: str | None, size: int) -> pygame.font.Font:
        """Load and cache a font."""
        key = (name, size)
        if key not in self._font_cache:
            self._font_cache[key] = pygame.font.Font(name, size)
        return self._font_cache[key]

    def load_sound(self, relative_path: str) -> pygame.mixer.Sound:
        """Load and cache a sound effect."""
        if relative_path not in self._sound_cache:
            full_path = os.path.join(self.base_path, "audio", relative_path)
            self._sound_cache[relative_path] = pygame.mixer.Sound(full_path)
        return self._sound_cache[relative_path]

    def clear_cache(self):
        """Release all cached assets."""
        self._sprite_cache.clear()
        self._font_cache.clear()
        self._sound_cache.clear()
```

---

## Section 8: Development Approach — Vibe Coding

This project is built using a rapid prototyping philosophy: build fast, see results quickly, iterate on what works. This is a personal project and creative endeavour — not an enterprise delivery.

### Core Principles

- **Speed over perfection in Phase 1.** Get the game loop running and playable before engineering elegantly.
- **Iterative builds:** Each coding session should produce something runnable. No long dark periods of build-up before a first result.
- **Placeholder-first:** Placeholder sprites, placeholder audio, placeholder UI — get the logic working first, polish later.
- **Single developer primary:** Architecture must be comprehensible to one person. Avoid over-engineering.
- **AI-assisted development:** Code will be generated with Claude assistance. Code examples in this TRD are prompt-ready — clear, well-commented, easy for an AI to extend.

### Recommended Build Sequence

Each step delivers a visible, runnable result before proceeding to the next. Each feature can be built and tested independently.

**Session 1 — Ship on Screen**
1. Pygame window initialisation (Section 1)
2. Game loop with delta-time (Section 2)
3. Placeholder player ship sprite (coloured triangle)
4. Input handler — WASD movement
5. **Result:** Player ship moves on screen. Runnable game.

**Session 2 — State Machine + Menu**
1. State machine with MENU and NAVIGATION states (Section 3)
2. Basic main menu (New Game / Quit)
3. Transition from menu to navigation
4. **Result:** Menu → gameplay flow. Two distinct states.

**Session 3 — Encounters**
1. Encounter engine with trigger conditions (Section 5)
2. Basic combat state — enemy ship appears, player can fire
3. Combat resolution — victory/defeat/flee
4. **Result:** Player encounters enemies. Combat works.

**Session 4 — Dialogue + Trade**
1. Dialogue UI with text and choices
2. Trade UI with offer/counter-offer
3. Wire to encounter engine as DIPLOMATIC and TRADE types
4. **Result:** All 4 encounter types functional.

**Session 5 — Story + Factions**
1. Data loader reads JSON encounter/faction files
2. Faction reputation system with score tracking
3. Story flags and arc progression
4. **Result:** Decisions affect faction scores. Arc 1 playable end-to-end.

**Session 6 — Save/Load + Polish**
1. Save manager writes/reads game state JSON
2. HUD with ship stats, crystal count, minimap
3. Faction status screen
4. **Result:** Full gameplay loop with persistence.

### Code Style for AI Extension

All code examples in this TRD follow these conventions to maximise AI-assisted development:

- **Type hints** on all function signatures
- **Docstrings** on all classes and public methods
- **Self-contained examples** — each code block can be understood without external context
- **Standard patterns** — no clever tricks; prefer explicit over implicit
- **Small classes** — each class does one thing; easy to extend or replace

---

*Cross-references: See TRD-001 for architecture principles and module structure. See TRD-003 for entity data models used by the encounter engine.*

*TRD-002 v0.2 | Whisper Crystals | Creative Development Confidential*
