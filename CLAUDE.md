# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BreakEscape** is a mountable Rails 7 Engine implementing a cybersecurity training escape room game. It runs in two modes:

- **Standalone Mode**: Self-contained with `BreakEscape::DemoUser` auth (SQLite)
- **Mounted Mode**: Integrated into a host Rails app (e.g., Hacktivity) using Devise `current_user` (PostgreSQL with JSONB)

**Critical rule**: All solution validation (passwords, PINs, biometrics) is enforced server-side. Client-side validation is UX-only.

## Commands

### Running Locally (Standalone)
```bash
export BREAK_ESCAPE_STANDALONE=true
bundle exec rails server -b 0.0.0.0 -p 3000
# Visit http://localhost:3000/break_escape/
```

### Testing
```bash
rails test                   # All tests
rails test:models
rails test:controllers
rails test:integration
rails test test/controllers/break_escape/games_controller_test.rb  # Single file
```

### Linting
```bash
rubocop                      # Check
rubocop -A                   # Auto-fix
```

### Scenario Validation & Build Tools
```bash
ruby scripts/validate_scenario.rb scenarios/<name>/scenario.json.erb
./scripts/compile-ink.sh     # Compile .ink dialogue files to .json
./scripts/update_tileset.sh  # Update tileset references
```

### Installing into a Host App
```bash
bundle install
rails break_escape:install:migrations
rails db:migrate
rails db:seed  # Creates missions from scenario files
```

## Architecture

### Rails Engine Structure
- `lib/break_escape/engine.rb` — Engine boot, Pundit integration
- `lib/break_escape.rb` — Configuration (`standalone_mode`, `demo_user_handle`)
- `config/routes.rb` — All REST endpoints (games, missions, configuration)
- `app/models/break_escape/` — `Game`, `Mission`, `DemoUser`, `PlayerPreference`, `Cybok`
- `app/controllers/break_escape/` — REST API; `GamesController` is the core
- `app/policies/break_escape/` — Pundit authorization policies
- `app/services/break_escape/` — `TtsService`, `TtsBatchProcessor`, `InkTextValidator`, `CybokSyncService`
- `scenarios/` — 50+ game scenarios as `.json.erb` templates

### Key Models
- **`Game`**: Central record. Holds `scenario_data` (JSONB — ERB-rendered scenario snapshot stored at game creation) and `player_state` (JSONB — live progress). Polymorphic `player` (User or DemoUser).
- **`Mission`**: Scenario metadata — `name`, `published`, `difficulty_level`, `vm_activation_mode` (eager/lazy).
- **`PlayerPreference`**: `selected_sprite` and `in_game_name`, polymorphic player association.

### API Endpoints
- `GET /games/:id/bootstrap` — Initial game data
- `GET /games/:id/scenario` — Scenario JSON (ERB-generated)
- `GET /games/:id/ink?npc=X` — NPC Ink script (JIT compiled)
- `PUT /games/:id/sync_state` — Sync player state
- `POST /games/:id/unlock` — Validate unlock attempt
- `POST /games/:id/inventory` — Update inventory

### Scenario System (ERB Generation)
Scenarios are `.json.erb` files. On game creation, ERB is rendered server-side with randomized values:
- `<%= random_password %>`, `<%= random_pin %>`, `<%= random_code %>`

The rendered JSON is stored in `scenario_data` JSONB. This snapshot is what the backend validates against — the client never sees the solution directly.

Scenario JSON structure:
```json
{
  "scenario_brief": "Mission description",
  "endGoal": "What player must accomplish",
  "startRoom": "room_id",
  "globalVariables": { "quest_complete": false },
  "startItemsInInventory": [
    { "type": "object_type", "name": "Display name", "takeable": true, "observations": "..." }
  ],
  "rooms": {
    "room_id": {
      "type": "room_type",
      "connections": { "north": "next_room" },
      "objects": [
        { "type": "object_type", "name": "...", "interactable": true, "active": true, "scenarioData": {} }
      ]
    }
  }
}
```

### Frontend Architecture (Vanilla JS + Phaser 3.60)
No bundler. Files use query-string versioning (`import { x } from 'file.js?v=7'`) to bust cache.

External dependencies (loaded via CDN/local):
- **Phaser.js v3.60** — game engine (graphics, physics, input)
- **EasyStar.js v0.4.4** — A* pathfinding for player/NPC movement
- **CyberChef v10.19.4** — embedded crypto tools (iframe in laptop mini-game)

Global window objects (cross-module access pattern):
```javascript
window.game           // Phaser instance
window.gameScenario   // Scenario JSON
window.player         // Player sprite
window.rooms          // Room data
window.gameState      // { biometricSamples, bluetoothDevices, notes, startTime, globalVariables }
window.inventory      // Player's items
```

Initialization order: `game.js` (Phaser scene) → `rooms.js` → `player.js` → systems → mini-games.

### Tiled Map Integration
Rooms use Tiled editor JSON format (`assets/rooms/*.tmj`). Objects stored in `map.getObjectLayer()` collections; Tiled object GID maps to textures via a tileset registry. `TiledItemPool` prevents object duplication across room loads.

### Depth/Layering Rule
**Every Phaser object's depth = `worldY + layerOffset`** (not CSS z-index). Offsets: Walls `+0.2`, Doors `+0.45`, Objects/Player `+0.5`. See `js/core/rooms.js` lines 1–40.

### Mini-game Framework
All mini-games extend `MinigameScene` (`js/minigames/framework/base-minigame.js`):
```javascript
// Register (in js/minigames/index.js)
MinigameFramework.registerScene('game-name', GameClass);
// Start
window.MinigameFramework.startMinigame('game-name', { data });
```

### Object Interactions
Objects need `interactable: true` and `active: true` in scenario JSON. Proximity checked every 100ms within `INTERACTION_RANGE = 64px`. Dispatched by `js/systems/interactions.js` to `unlock-system.js`, `doors.js`, `inventory.js`, or `biometrics.js`.

### JIT Ink Compilation
NPC dialogue `.ink` scripts compile to JSON on first request (~300ms via `inklecate`), then cached. Request: `GET /games/:id/ink?npc=X`.

### NPC Global Variables
Cross-NPC narrative state is stored in `window.gameState.globalVariables` and automatically synced into all loaded Ink stories. Declare in scenario JSON under `globalVariables`, or in `.ink` files using the `global_` naming convention. See `docs/GLOBAL_VARIABLES.md` for full details.

## CSS Conventions
Pixel-art aesthetic — **no `border-radius`**, **borders exactly 2px**. Apply to all UI elements (buttons, panels, modals, inputs).

## Debugging Hints
- **Object not interactive**: Check `interactable: true`, `active: true`, and player distance vs `INTERACTION_RANGE`
- **Depth/layering wrong**: Recalculate as `worldY + layerOffset`
- **Player stuck**: Check `STUCK_THRESHOLD` and `PATH_UPDATE_INTERVAL` in `js/utils/constants.js`
- **Mini-game not loading**: Verify registered in `js/minigames/index.js`
- **Standalone auth issues**: Confirm `BREAK_ESCAPE_STANDALONE=true` is set
- **Ink conditional choices wrong**: Must recompile `.ink` after edits; use `+ {variable} [choice text]` syntax (not wrapping the choice block)
- **Isolated JS testing**: Open `test-*.html` files directly (e.g., `test-npc-ink.html`, `test-pin-minigame.html`) for standalone system tests without the full game

## Key Files to Read First
1. `config/routes.rb` — All endpoints
2. `app/models/break_escape/game.rb` — Core game logic
3. `app/controllers/break_escape/games_controller.rb` — Main API
4. `public/break_escape/js/main.js` — Frontend boot
5. `public/break_escape/js/core/game.js` — Phaser scene lifecycle
6. `public/break_escape/js/core/rooms.js` — Room/depth system
7. `scenarios/m01_first_contact/scenario.json.erb` — Example scenario

## Integration Guide
See `HACKTIVITY_INTEGRATION.md` for mounting into a host Rails app.
