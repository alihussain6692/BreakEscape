# Scenario Design Constraints in Hacktivity Cyber Security Labs

There are several constraints and patterns for designing scenarios for BreakEscape.

---

## Scenario Validator

The validator script renders your ERB template to JSON, validates it against the schema, and checks for structural issues, bad cross-references, and missing best-practice fields.

### Prerequisites

The `json-schema` gem is required:

```bash
gem install json-schema
# or add to Gemfile: gem 'json-schema', then bundle install
```

### Running the Validator

```bash
# Basic validation
ruby scripts/validate_scenario.rb scenarios/my_scenario/scenario.json.erb

# Specify a custom schema path
ruby scripts/validate_scenario.rb scenarios/my_scenario/scenario.json.erb --schema scripts/scenario-schema.json

# Verbose output (includes full JSON on schema failure)
ruby scripts/validate_scenario.rb scenarios/my_scenario/scenario.json.erb --verbose

# Print the rendered JSON to stdout (useful for debugging ERB substitution)
ruby scripts/validate_scenario.rb scenarios/my_scenario/scenario.json.erb --output-json
```

### What the Validator Checks

The validator performs three phases:

1. **ERB rendering** – renders the `.json.erb` template with randomised placeholder values (`random_password`, `random_pin`, `random_code`, `vm_object()`, `flags_for_vm()`)
2. **Schema validation** – checks the rendered JSON against `scripts/scenario-schema.json`
3. **Common issues** – structural checks including:
   - Object types with no matching sprite file in `public/break_escape/assets/objects/`
   - Containers with `contents` that are missing the required `locked` field
   - Key locks and key items missing the required `keyPins` array
   - Room connections using invalid directions (only `north`, `south`, `east`, `west`)
   - Missing or non-bidirectional room connections
   - `onRead.setVariable` / `onPickup.setVariable` referencing variables not in `globalVariables`
   - `globalVarOnKO` / `taskOnKO` cross-references on NPCs
   - NPC `timedConversation` using `knot` instead of `targetKnot`
   - Phone NPC pitfalls (`targetKnot` in eventMappings, `conversationMode` on phone NPCs, etc.)
   - Task `targetNPC`, `targetRoom`, `targetObject` cross-references
   - `collection_group` on items without a matching task `targetGroup`, and vice-versa
   - Music events referencing undefined NPCs or global variables
   - Items with an `id` field inside `itemsHeld` (should use `type` only)
   - `vm-launcher` missing `vm` or `hacktivityMode` fields
   - `launch-device` missing required fields
4. **Recommended fields** – warnings for missing `globalVariables`, `objectives`, `observations`, NPC `position`, `currentKnot`, etc.
5. **Suggestions** – guidance for adding VM launchers, flag stations, opening cutscenes, closing debriefs, patrol NPCs, and variety in lock types

### Exit codes

| Code | Meaning |
|------|---------|
| `0`  | Validation passed (suggestions and warnings do not cause failure) |
| `1`  | Schema validation failed or unrecoverable error |

---

## Scenario Structure Constraints

### Basic Structure
- Each scenario must have a `scenario_brief` that explains the mission
- Each scenario must define a `startRoom` where the player begins
- Some scenarios include an `endGoal` property
- All scenarios must have a `rooms` object containing individual room definitions

### Room Connections

Rooms can connect in **four directions**: `north`, `south`, `east`, `west`

**Connection Syntax**:
```json
"connections": {
  "north": "office1",           // Single connection
  "south": ["reception", "hall"], // Multiple connections (array)
  "east": "serverroom",
  "west": ["closet1", "closet2"]
}
```

**Key Points**:
- All directions support both single connections (string) and multiple connections (array)
- The room layout algorithm positions rooms using breadth-first traversal
- Multiple rooms in the same direction are positioned side-by-side (N/S) or stacked (E/W)
- All rooms align to grid boundaries for consistent door placement

#### Door Validation and Locking

The code in `validateDoorsByRoomOverlap()` (lines 3236-3323) shows that:

1. Doors must connect exactly two rooms (line 3281)
2. If a door connects to a locked room, the door inherits the lock properties (lines 3296-3303)
3. Doors that don't connect exactly two rooms are removed (lines 3281-3291)

#### Designing Solvable Scenarios with the Grid System

The grid-based room layout system provides significant flexibility for scenario design:

1. **Flexible Layout Patterns**: Design scenarios using any combination of directions:
   - **Vertical**: Stack rooms north/south for traditional layouts
   - **Horizontal**: Connect rooms east/west for wide facilities
   - **Mixed**: Combine directions for complex, non-linear layouts
   - **Branching**: All directions support multiple connections

2. **Room Size Variety**: Mix different room sizes for visual interest and gameplay:
   - Use **1×1 GU closets** for small storage rooms or utility spaces
   - Use **2×2 GU standard rooms** for offices, reception areas
   - Use **1×2 GU or 4×1 GU halls** to connect distant areas
   - Ensure all room dimensions follow the valid size formula

3. **Lock Progression**: Design logical progression through the facility:
   - Place keys, codes, and unlock items in accessible rooms first
   - Create puzzles that require backtracking or exploring side rooms
   - Use east/west connections for optional areas with bonus items
   - Layer security with multiple lock types (key → PIN → biometric)

4. **Connection Planning**:
   - Start by sketching your layout on grid paper (5-tile width increments)
   - Ensure all rooms are reachable from the starting room
   - Verify room dimensions before creating Tiled maps
   - Test door alignment between connected rooms

5. **Avoid Common Pitfalls**:
   - **Invalid heights**: Heights of 7, 8, 9, 11, 12, 13 will cause issues
   - **Room overlaps**: System validates and warns, but plan carefully
   - **Disconnected rooms**: Ensure all rooms connect to the starting room
   - **Asymmetric connections**: When connecting single-door to multi-door rooms, the system handles alignment automatically

#### Example Layout Structures

**Vertical Tower** (traditional):
```
        [Server Room]
             ↑
        [CEO Office]
             ↑
    [Office1] [Office2]
         ↑       ↑
        [Reception]
```

**Horizontal Facility** (wide):
```
[Closet1] ← [Office] → [Meeting] → [Server]
                ↑
           [Reception]
```

**Complex Multi-Direction**:
```
    [Storage]   [CEO]
        ↑         ↑
    [Closet] ← [Office] → [Server]
                  ↑
             [Reception]
```

**With Hallways**:
```
    [Office1]  [Office2]
        ↑          ↑
    [---- Hall ----]
           ↑
      [Reception]
```

These layouts demonstrate the flexibility of the new grid system for creating engaging, solvable scenarios.


### Top-Level Optional Scenario Properties

| Property | Description |
|---------|-------------|
| `globalVariables` | Key/value map of all game state variables. Required for Ink dialogue, event-driven logic, and objective tracking. |
| `player` | Player sprite configuration: `id`, `displayName`, `spriteSheet`, `spriteTalk`, `spriteConfig` |
| `narrator` | Defines a narrator voice used for cutscenes. Include `id`, optional `skipTextValidation: true`, and a `voice` object. |
| `objectives` | Array of objective `aims`, each containing `tasks`. Drives the objectives HUD. |
| `startItemsInInventory` | Array of items the player starts with (e.g., a phone, lockpick, workstation). |
| `flags` | Map of VM flag arrays by VM name. Populated via ERB helper `vm_flags_json('vm_name')`. |
| `show_scenario_brief` | When to show the brief: `"on_start"`, `"on_resume"`, or omit. |
| `music` | Dynamic music event system. See Music System section. |

### Available Room Types

The `type` field of each room must match a file in `public/break_escape/assets/rooms/`. Available types:

| Room Type | Description |
|-----------|-------------|
| `room_reception` | Reception area (standard 2×2 GU) |
| `room_office` | Open-plan office (standard 2×2 GU) |
| `room_ceo` | Executive office |
| `room_meeting` | Meeting / conference room |
| `room_break` | Break room |
| `room_closet` | Storage closet |
| `room_servers` | Server room |
| `room_it` | IT department |
| `small_office_room1_1x1gu` | Small private office (1×1 GU) |
| `small_office_room2_1x1gu` | Small private office variant 2 |
| `small_office_room3_1x1gu` | Small private office variant 3 |
| `small_room_1x1gu` | Generic small room (1×1 GU) |
| `small_room_storage_1x1gu` | Small storage room (1×1 GU) |
| `small_room_closet_east_connections_only_1x1gu` | Small closet (east connections only) |
| `hall_1x2gu` | Vertical hallway (1×2 GU) |
| `hall4x10` | Wide horizontal hall (4×10 tiles) |

### Room Properties

```json
"room_id": {
  "type": "room_office",
  "locked": true,
  "lockType": "key",
  "requires": "main_office_key",
  "keyPins": [45, 25, 55, 35],
  "difficulty": "medium",
  "door_sign": "Main Office",
  "ambientSound": "server_room_ventilation",
  "ambientVolume": 0.4,
  "connections": { "north": "next_room" },
  "npcs": [...],
  "objects": [...]
}
```

All room lock properties are the same as object lock properties (see Lock Types below).

### Starting Inventory

Use the `startItemsInInventory` array at scenario root level. Players have these items automatically at game start:

```json
"startItemsInInventory": [
  {
    "type": "phone",
    "name": "Your Phone",
    "takeable": true,
    "phoneId": "player_phone",
    "npcIds": ["agent_0x99"],
    "observations": "Your secure encrypted phone"
  },
  {
    "type": "workstation",
    "name": "CyberChef Workstation",
    "takeable": true,
    "observations": "A crypto analysis tool"
  }
]
```

---

## Object Reference

### Object Placement and Positioning

Each room type has a Tiled map template (`.tmj`) that pre-defines positions for certain object types. When the engine loads a room, it matches each object from the scenario's `objects` array against available slots in that template:

- **Matched objects** are placed at the position defined in the Tiled template (correct furniture placement, on desks, shelves, etc.)
- **Unmatched objects** — those whose `type` has no available slot left in the template — are placed at a **random position** within the room bounds (with padding from walls)

This means you can place any number of objects in a room, but only objects that correspond to pre-placed items in the room template will appear in their intended position. Extra objects of the same type, or types not present in the template, will be scattered randomly. Keep this in mind when designing room contents — using object types that the room template already contains gives predictable, visually coherent results.

Every object in `rooms[id].objects[]`, in NPC `itemsHeld[]`, in container `contents[]`, or in `startItemsInInventory[]` uses these common fields:

| Field | Required | Description |
|-------|----------|-------------|
| `type` | ✅ | Sprite name (see categories below). Must match a file in `assets/objects/` |
| `name` | ✅ | Display name shown in UI |
| `takeable` | ✅ | `true` = player can pick up; `false` = stays in room |
| `observations` | recommended | Description shown when player examines the object |
| `id` | optional | Explicit ID for cross-referencing in objectives (`targetObject`) |
| `locked` | required for containers | Must be `true` or `false` on any container with `contents` |
| `readable` | optional | `true` enables the "Read" interaction |
| `text` | optional | Body text shown when the player reads the item |
| `collection_group` | optional | Tag used for objective `collect_items` task tracking |
| `important` | optional | `true` marks item as important in inventory |
| `isEndGoal` | optional | `true` marks item as the scenario's win condition |
| `onRead` | optional | `{ "setVariable": { "var_name": true } }` — sets a global variable on read |
| `onPickup` | optional | `{ "setVariable": { "var_name": true } }` — sets a global variable on pickup |

### Lock Types

Applies to both rooms and objects (safes, PCs, briefcases, doors, etc.):

| `lockType` | `requires` value | Notes |
|-----------|-----------------|-------|
| `key` | `key_id` string matching a key item's `key_id` | Also requires `keyPins` array on **both** the lock and the matching key item (e.g., `[45, 25, 55, 35]`) |
| `pin` | 4-digit PIN string (e.g., `"2468"`) | Player enters PIN in numeric keypad mini-game |
| `password` | Password string (e.g., `"Marketing123"`) | Player types password; `showKeyboard: true` shows on-screen keys; `maxAttempts: 3` limits tries; `postitNote` + `showPostit: true` shows a hint post-it |
| `rfid` | `key_id` of a keycard / rfid item | Player must scan a keycard using the `rfid_cloner` or by carrying the card |
| `bluetooth` | Bluetooth device MAC address | Requires `bluetooth_scanner` tool; device must be discovered |
| `biometric` | Fingerprint owner name | Requires `fingerprint_kit`; `biometricMatchThreshold` (0.0–1.0) sets difficulty |
| `flag` | `"vm_name:flag_id"` string | Unlocked by submitting a VM flag at a `flag-station`; supports `flagRewards` array |

```json
"locked": true,
"lockType": "key",
"requires": "derek_office_key",
"keyPins": [35, 55, 45, 25],
"difficulty": "medium"
```

### Container Objects

Containers hold `contents` arrays of nested items. Every container with `contents` **must** declare `locked: true` or `locked: false`.

| Type | Notes |
|------|-------|
| `safe` (variants: `safe1`–`safe5`) | In-room safe; common PIN or password lock |
| `suitcase` (variants: `suitcase1`–`suitcase21`, colour variants) | Briefcase/luggage; common key lock |
| `briefcase` (variants: `briefcase1`–`briefcase13`, colour variants) | Briefcase; common key lock |
| `bag` (variants: `bag1`–`bag25`) | Bag/backpack |
| `bin` / `bin1`–`bin11` | Recycling/waste bin (often `locked: false` with hidden clue items inside) |
| `pc` (variants: `pc1`–`pc12`) | Computer terminal; supports `lockType: "password"`, `postitNote`, `showPostit`, `maxAttempts` |
| `filing_cabinet` | Filing cabinet |

#### PC-specific properties

```json
{
  "type": "pc",
  "name": "Derek's Computer",
  "takeable": false,
  "locked": true,
  "lockType": "password",
  "requires": "Anniversary",
  "postitNote": "Think: important dates",
  "showPostit": true,
  "maxAttempts": 3,
  "showKeyboard": true,
  "observations": "A password-locked workstation",
  "contents": [
    { "type": "text_file", "name": "Access Log", "readable": true, "text": "..." }
  ]
}
```

### Readable / Document Objects

| Type | Notes |
|------|-------|
| `notes` (also `notes1`–`notes5`) | Loose notes / paper; `notes2`–`notes5` use different coloured sprites — handy for colour-coding evidence tiers |
| `text_file` | Digital file found inside a PC container |
| `phone` | Desk phone / answerphone — supports `voice` (TTS script), `ttsVoice`, `avatar`, `sender`, `timestamp` for voicemail presentation |
| `tablet` | Tablet device |
| `smartscreen` | Wall-mounted display |

#### Phone / voicemail object

```json
{
  "type": "phone",
  "id": "reception_desk_phone",
  "name": "Reception Desk Phone",
  "phoneId": "reception_desk_phone",
  "takeable": false,
  "readable": true,
  "voice": "Hi Sarah, it's Kevin. The IT room PIN is 2468.",
  "ttsVoice": { "name": "Charon", "style": "Nerdy Australian IT guy", "language": "en-GB" },
  "avatar": "assets/characters/male_nerd_headshot.png",
  "sender": "Kevin Park (IT)",
  "timestamp": "Yesterday, 6:47 PM",
  "observations": "The message light is blinking"
}
```

### Key & Access Items

These items are carried in the player's inventory to unlock doors, containers, or systems.

| Type | Notes |
|------|-------|
| `key` | Physical key. Must have `key_id` and `keyPins` array. |
| `keycard` | RFID keycard. Must have `key_id`. Variants: `keycard-ceo`, `keycard-maintenance`, `keycard-security`. |
| `id_badge` | Visitor or staff badge (narrative/inventory item). |
| `key-ring` | Decorative key-ring item. |

```json
{
  "type": "key",
  "name": "Derek's Office Key",
  "takeable": true,
  "key_id": "derek_office_key",
  "keyPins": [35, 55, 45, 25],
  "observations": "Spare key to Derek Lawson's office"
}
```

### Security Tools

Security tools enable specific mini-games and unlock mechanics. Can be placed as room objects or in NPC `itemsHeld`.

| Type | Mini-game / Effect |
|------|-------------------|
| `lockpick` | Enables lockpicking mini-game on `lockType: "key"` locks |
| `fingerprint_kit` | Enables fingerprint collection from objects with `hasFingerprint`; required for biometric locks |
| `pin-cracker` / `pin-cracker-large` | Enables PIN-cracking mini-game on `lockType: "pin"` locks |
| `bluetooth_scanner` | Enables Bluetooth scanning to discover devices for `lockType: "bluetooth"` locks |
| `rfid_cloner` | Enables RFID cloning from keycards for `lockType: "rfid"` locks |
| `workstation` | Opens embedded CyberChef cryptography tool (browser-based) |

### Hacking / VM Objects

| Type | Notes |
|------|-------|
| `vm-launcher` (variants: `vm-launcher-kali`, `vm-launcher-desktop`) | Opens a VM terminal (Hacktivity mode) or a simulated interface. Requires `vm` (ERB: `<%= vm_object('vm_name', fallback) %>`), `hacktivityMode`, and `id`. |
| `flag-station` | Flag submission terminal. Accepts flags from specified VMs (`acceptsVms`), validates against `flags` array (ERB: `<%= flags_for_vm('vm_name') %>`), and fires `flagRewards` actions on success. |
| `launch-device` | High-stakes interactive device for mission climax. Full required fields: `mode` (`"launch-abort"`), `acceptsVms`, `flags`, `flagRewards`, `onAbort`, `onLaunch`, `abortConfirmText`, `launchConfirmText`. |

#### vm-launcher example

```json
{
  "type": "vm-launcher",
  "id": "vm_launcher_kali",
  "name": "Kali Terminal",
  "sprite": "vm-launcher-kali",
  "takeable": false,
  "observations": "A Kali Linux attack terminal",
  "hacktivityMode": <%= vm_context && vm_context['hacktivity_mode'] ? 'true' : 'false' %>,
  "vm": <%= vm_object('intro_to_linux_security_lab', {"id":1,"ip":"192.168.100.50"}) %>
}
```

#### flag-station example

```json
{
  "type": "flag-station",
  "id": "flag_station_1",
  "name": "SAFETYNET Terminal",
  "takeable": false,
  "observations": "Secure terminal for submitting flags",
  "acceptsVms": ["desktop"],
  "flags": <%= flags_for_vm('desktop') %>,
  "flagRewards": [
    { "type": "set_global", "key": "linux_flag_submitted", "value": true }
  ]
}
```

#### launch-device example (see `scenarios/m01_first_contact/scenario.json.erb` for full reference)

```json
{
  "type": "launch-device",
  "name": "ENTROPY Launch Device",
  "takeable": true,
  "mode": "launch-abort",
  "acceptsVms": ["desktop"],
  "flags": ["desktop:flag_3"],
  "flagRewards": [{ "type": "set_global", "key": "launch_code_submitted", "value": true }],
  "onAbort": { "setGlobal": { "player_aborted_attack": true }, "emitEvent": "attack_aborted" },
  "onLaunch": { "setGlobal": { "player_launched_attack": true }, "emitEvent": "attack_launched" },
  "abortConfirmText": "ABORT OPERATION? This cannot be undone.",
  "launchConfirmText": "EXECUTE OPERATION? This cannot be undone."
}
```

### Decorative / Environment Objects

These objects have no special gameplay function but improve immersion. They use `takeable: false` and `observations`.

The `type` value must match a sprite filename (without extension) in `public/break_escape/assets/objects/`. Variants with an integer suffix are valid types — e.g. `notes`, `notes2`, `notes3` are all distinct sprite files and all valid `type` values.

| Category | Types |
|----------|-------|
| Office misc | `chalkboard`, `chair-*` (many variants), `sofa1`, `laptop1`–`laptop7`, `keyboard1`–`keyboard8`, `tablet`, `smartscreen` |
| Plants | `plant-large1`–`plant-large13`, `plant-flat-pot1`–`plant-flat-pot7`, `plant-large-displacement` |
| Pictures / decor | `picture1`–`picture14`, `lamp-stand1`–`lamp-stand5`, `outdoor-lamp1`–`outdoor-lamp4` |
| Server room | `servers`, `servers2`–`servers4` |
| Loot / ambience | `office-misc-*` (pencils, pens, stapler, clock, fan, hdd, headphones, lamp, speakers, plants, etc.) |
| Other | `book1`, `bookcase`, `spooky-candles`, `spooky-splatter`, `torch-1`, `torch-left`, `torch-right` |

---

## NPC System

NPCs are defined in `rooms[id].npcs[]` arrays. Two NPC types exist:

### Person NPCs (`npcType: "person"`)

In-world characters with sprites that the player can walk up to and interact with.

```json
{
  "id": "kevin_park",
  "displayName": "Kevin Park",
  "npcType": "person",
  "position": { "x": 4, "y": 4 },
  "spriteSheet": "male_nerd",
  "spriteTalk": "assets/characters/male_nerd_talk.png",
  "spriteConfig": { "idleFrameRate": 6, "walkFrameRate": 10 },
  "storyPath": "scenarios/my_scenario/ink/npc_kevin.json",
  "currentKnot": "start",
  "voice": { "name": "Charon", "style": "Nerdy Australian", "language": "en-GB" },
  "globalVarOnKO": "kevin_ko",
  "taskOnKO": "meet_kevin",
  "behavior": {
    "hostile": { "chaseSpeed": 145, "attackDamage": 15, "pauseToAttack": false },
    "patrol": { "waypoints": [{"x": 2, "y": 2}, {"x": 6, "y": 4}] },
    "initiallyHidden": false
  },
  "itemsHeld": [
    { "type": "lockpick", "name": "Lock Pick Kit", "takeable": true, "observations": "..." }
  ]
}
```

**Key person NPC fields:**

| Field | Description |
|-------|-------------|
| `position` | `{ "x": tiles_from_left, "y": tiles_from_top }`. Omit only if `behavior.initiallyHidden: true`. |
| `spriteSheet` | Character sprite name (see `public/break_escape/assets/characters/`) |
| `spriteTalk` | Headshot image for dialogue box |
| `storyPath` | Path to compiled Ink `.json` story file |
| `currentKnot` | Starting Ink knot (usually `"start"`) |
| `voice` | TTS voice for dialogue: `{ "name": "...", "style": "...", "language": "en-GB" }` |
| `globalVarOnKO` | Global variable name to set `true` when NPC is knocked out |
| `taskOnKO` | Task ID to complete when NPC is knocked out |
| `itemsHeld` | Items dropped when NPC is knocked out (do NOT give items an `id` field here — use `type` only) |
| `behavior.hostile` | Makes NPC chase and attack. Fields: `chaseSpeed`, `attackDamage`, `pauseToAttack` |
| `behavior.patrol` | Patrol waypoints: `{ "waypoints": [{x, y}, ...] }` or multi-room `{ "route": [...] }` |
| `behavior.initiallyHidden` | `true` hides NPC — used for cutscene-only NPCs triggered by events |

#### NPC Timed Conversations (opening cutscenes)

Trigger a conversation automatically when the player loads the room:

```json
"timedConversation": {
  "delay": 0,
  "targetKnot": "start",
  "background": "assets/backgrounds/hq1.png",
  "waitForEvent": "game_loaded",
  "skipIfGlobal": "briefing_played",
  "setGlobalOnStart": "briefing_played"
}
```

| Field | Description |
|-------|-------------|
| `delay` | Milliseconds before triggering (use `0` for immediate) |
| `targetKnot` | Ink knot to jump to |
| `background` | Background image for person-chat overlay |
| `waitForEvent` | Wait for this game event before starting |
| `skipIfGlobal` | Skip if this global variable is truthy (prevents cutscene replaying on resume) |
| `setGlobalOnStart` | Set this global variable to `true` when conversation starts |
| `disableClose` | `true` prevents player closing the dialog |

#### NPC Event Mappings

React to game events on any NPC type:

```json
"eventMappings": [
  {
    "eventPattern": "global_variable_changed:derek_confronted",
    "condition": "value === true",
    "onceOnly": true,
    "conversationMode": "person-chat",
    "targetKnot": "aftermath",
    "background": "assets/backgrounds/hq1.png"
  }
]
```

Common event patterns:
- `"global_variable_changed:var_name"` — fires when a global variable changes (`condition: "value === true"`)
- `"room_entered:room_id"` — fires when player enters a room
- `"npc_ko:npc_id"` — fires when an NPC is knocked out
- `"npc_attacked:npc_id"` — fires when an NPC is attacked
- `"item_picked_up:item_type"` — fires when an item is picked up
- `"door_unlock_attempt"` — fires on any door unlock attempt (`condition: "data.connectedRoom === 'room_id'"`)
- `"object_interacted"` — fires when object interacted with (`condition: "data.objectType === 'vm-launcher'"`)
- `"conversation_closed:npc_id"` — fires when a conversation closes
- `"attack_aborted"` / `"attack_launched"` — fires from launch-device

Event mapping actions (can be combined):

| Action | Description |
|--------|-------------|
| `setGlobal: { "var": value }` | Set one or more global variables |
| `sendTimedMessage: { "delay": ms, "message": "..." }` | Send a timed message from this NPC (phone NPCs) |
| `completeTask: "task_id"` or `["id1","id2"]` | Mark a task complete |
| `unlockTask: "task_id"` | Unlock a locked task |
| `unlockAim: "aim_id"` | Unlock a locked objective aim |
| `conversationMode: "person-chat"` | Trigger a person-chat cutscene (person NPCs only) |
| `targetKnot: "knot_name"` | Jump to this Ink knot (person NPCs only; does NOT work on phone NPCs after first open) |
| `background: "path"` | Background image for person-chat cutscene |
| `onceOnly: true` | Ensure mapping only fires once |

### Phone NPCs (`npcType: "phone"`)

Contacts in the player's phone. Not rendered in the world — they exist only in the phone UI.

```json
{
  "id": "agent_0x99",
  "displayName": "Agent HaX",
  "npcType": "phone",
  "phoneId": "player_phone",
  "storyPath": "scenarios/my_scenario/ink/phone_handler.json",
  "currentKnot": "first_call",
  "avatar": "assets/characters/female_spy_headshot.png",
  "voice": { "name": "Aoede", "style": "Intelligence handler", "language": "en-GB" },
  "timedMessages": [
    {
      "delay": 3000,
      "message": "Agent, I'm your handler for this op.",
      "waitForEvent": "conversation_closed:briefing_cutscene"
    }
  ],
  "eventMappings": [
    {
      "eventPattern": "room_entered:server_room",
      "onceOnly": true,
      "setGlobal": { "server_room_entered": true },
      "sendTimedMessage": { "delay": 1000, "message": "You're in the server room." }
    }
  ]
}
```

**Important phone NPC rules:**
- Phone NPCs must **not** have `position` or `spriteSheet`
- Phone NPCs must have `phoneId` matching a phone in `startItemsInInventory`
- `targetKnot` in event mappings does **not** work after first conversation — use `setGlobal` + an Ink conditional hub choice instead
- `conversationMode` field is ignored on phone NPCs
- A phone NPC with no `timedMessages` still works as a contact the player can call manually

---

## Objectives System

Objectives structure the mission with `aims` (groups) containing `tasks` (individual goals):

```json
"objectives": [
  {
    "aimId": "establish_access",
    "title": "Establish Access",
    "description": "Get into the building",
    "status": "active",
    "order": 0,
    "unlockCondition": { "aimCompleted": "previous_aim" },
    "tasks": [
      {
        "taskId": "check_in",
        "title": "Check in at reception",
        "type": "npc_conversation",
        "targetNPC": "sarah_martinez",
        "status": "active",
        "optional": true,
        "showProgress": true,
        "onComplete": { "unlockAim": "next_aim", "unlockTask": "another_task", "setGlobal": { "var": true } }
      }
    ]
  }
]
```

### Task Types

| `type` | Required fields | Notes |
|--------|----------------|-------|
| `npc_conversation` | `targetNPC` | Complete by talking to the specified NPC ID |
| `enter_room` | `targetRoom` | Complete by entering the specified room ID |
| `unlock_object` | `targetObject` | Complete when an object with that ID is unlocked. Object must have an explicit `id` field. |
| `unlock_room` | `targetRoom` | Complete when the specified room is unlocked |
| `collect_items` | `targetItems` or `targetGroup` or `targetItemIds` + `targetCount` | Track item collection. `targetItems` matches by `type`; `targetGroup` matches `collection_group` on items; `targetItemIds` matches by `name` or `id`. Add `showProgress: true` for a progress counter. |
| `submit_flags` | `targetFlags`, `targetCount` | Track VM flag submissions |
| `manual` | — | Completed only via `completeTask` in an event mapping |
| `custom` | — | Custom completion logic |

### `unlockCondition`

Aims can be locked until prerequisites are met:

```json
"unlockCondition": { "aimCompleted": "survey_offices" }
"unlockCondition": { "aimsCompleted": ["return_intel", "deactivate_the_launch"] }
```

---

## Global Variables

Declare all variables in `globalVariables` at the scenario root. Referenced in Ink stories, event conditions, and `onRead`/`onPickup` handlers.

```json
"globalVariables": {
  "briefing_played": false,
  "derek_confronted": false,
  "start_debrief_cutscene": false,
  "ssh_flag_submitted": false,
  "audit_correct_answers": 0,
  "player_name": "Agent Zero"
}
```

Values can be `false`, `true`, `0`, or `""`. The validator will error if any `setVariable`, `globalVarOnKO`, or event mapping references a variable not defined here.

---

## Music System

Dynamic music based on in-game events:

```json
"music": {
  "events": [
    { "trigger": "game_loaded", "condition": "!globalVars.briefing_played", "playlist": "cutscene", "fade": false },
    { "trigger": "game_loaded", "condition": "globalVars.briefing_played === true", "playlist": "noir", "fade": false },
    { "trigger": "conversation_closed:briefing_cutscene", "playlist": "noir", "fade": true },
    { "trigger": "npc_hostile_state_changed", "condition": "isHostile === true", "playlist": "threat", "fade": true },
    { "trigger": "all_hostiles_ko", "playlist": "noir", "fade": true },
    { "trigger": "global_variable_changed:start_debrief_cutscene", "condition": "value === true",
      "playlist": "victory", "track": "Ghost in the Wire", "autoStop": true, "disableClose": true, "fade": true,
      "credits": [
        { "text": "MISSION COMPLETE", "style": "title", "condition": "!globalVars.player_launched_attack" }
      ]
    }
  ]
}
```

| Trigger | Description |
|---------|-------------|
| `game_loaded` | Fires on game start/resume |
| `conversation_closed:npc_id` | Fires when a conversation closes |
| `npc_hostile_state_changed` | Fires when any NPC becomes hostile |
| `all_hostiles_ko` | Fires when all hostile NPCs are knocked out |
| `global_variable_changed:var_name` | Fires when a global variable changes |

---

## ERB Template Helpers

Scenario files are `.json.erb` templates. Available helpers:

| Helper | Description |
|--------|-------------|
| `<%= @random_password %>` | Random 8-char alphanumeric password (changes per render) |
| `<%= @random_pin %>` | Random 4-digit PIN string |
| `<%= @random_code %>` | Random 8-char hex code |
| `<%= vm_object('vm_title', fallback_hash) %>` | Returns VM data as JSON; uses Hacktivity VM context or fallback |
| `<%= flags_for_vm('vm_name', fallback_array) %>` | Returns flag array as JSON for a named VM |
| `<%= vm_flags_json('vm_name', fallback_array) %>` | Alias for `flags_for_vm`; used in `flags:` top-level map |
| `<%= base64_encode("text") %>` | Base64-encodes a string (for encoded notes puzzles) |
| `<%= rot13("text") %>` | ROT13-encodes a string (for cipher puzzles) |

Define custom helpers at the top of the `.erb` file inside `<% ... %>` blocks:

```erb
<%
def rot13(text)
  text.tr('A-Za-z', 'N-ZA-Mn-za-m')
end

def base64_encode(text)
  Base64.strict_encode64(text)
end

client_list_message = "The IT room PIN is: 2468"
%>
```

---

## Room Layout System (Grid-Based)

The game uses a **grid unit system** for room positioning that supports variable room sizes and four-direction connections.

### Grid Unit System

- **Base Grid Unit (GU)**: 5 tiles wide × 4 tiles tall (160px × 128px)
- **Tile Size**: 32px × 32px
- **Room Structure**:
  - Top 2 rows: Visual wall (overlaps room to north)
  - Middle rows: Stackable area (used for positioning calculations)
  - All rooms must be multiples of grid units

### Valid Room Sizes

**Width**: Must be multiple of 5 tiles (5, 10, 15, 20, 25...)

**Height**: Must follow formula `2 + (N × 4)` where N ≥ 1
- **Valid heights**: 6, 10, 14, 18, 22, 26... (increments of 4 after initial 2)
- **Invalid heights**: 7, 8, 9, 11, 12, 13...

**Examples**:
- **1×1 GU** (Closet): 5×6 tiles = 160×192px
- **2×2 GU** (Standard): 10×10 tiles = 320×320px
- **1×2 GU** (Hall): 5×10 tiles = 160×320px
- **4×1 GU** (Wide Hall): 20×6 tiles = 640×192px

### Room Positioning Algorithm

1. The `startRoom` is positioned at grid coordinates (0,0)
2. Rooms are positioned outward from the starting room using breadth-first traversal
3. Rooms align to grid boundaries using `Math.floor()` for consistent rounding
4. **North/South**: Rooms stack vertically, centered or side-by-side when multiple
5. **East/West**: Rooms align horizontally, stacked vertically when multiple
6. All positions are validated to detect overlaps

### Door Placement Rules

**North/South Doors**:
- **Size**: 1 tile wide × 2 tiles tall
- **Single door**: Placed in corner (NW or NE), determined by grid coordinates using `(gridX + gridY) % 2`
- **Multiple doors**: Evenly spaced across room width with 1.5 tile inset from edges

**East/West Doors**:
- **Size**: 1 tile wide × 1 tile tall
- **Single door**: North corner of edge, 2 tiles from top
- **Multiple doors**: First at north corner, last 3 tiles up from south, others evenly spaced

**Alignment**: Doors must align perfectly between connecting rooms. Special logic handles asymmetric connections (single door to multi-door room).

### Four-Direction Connections

Unlike the old system (north/south only), the new system supports:
- **North**: Connects to rooms above
- **South**: Connects to rooms below
- **East**: Connects to rooms on the right
- **West**: Connects to rooms on the left

Each direction supports multiple connections (arrays).

## Designing Solvable Scenarios

The canonical reference scenario is `scenarios/m01_first_contact/scenario.json.erb` — the most complete example, demonstrating every major system. Validate your scenario against it with the validator script.

1. **Clear Progression Path**: Design a logical sequence of rooms that can be unlocked in order
   - Ensure keys/codes for locked rooms are obtainable before they're needed
   - Use the four-direction connection system to create interesting navigation puzzles

2. **Tool Placement**: Place necessary tools early in the scenario
   - Critical tools like `lockpick`, `fingerprint_kit`, or `bluetooth_scanner` should be available before they're needed
   - Consider adding some tools to the initial inventory with `startItemsInInventory`

3. **Clue Distribution**: Spread clues logically throughout the scenario
   - Place hints for codes/passwords in accessible locations (bins, other NPCs)
   - Use readable objects (`notes`, `phone` voicemails, `pc` files) to provide guidance

4. **Lock Type Variety**: Use at least 3 different lock types to teach security concepts
   - `key` + lockpicking mini-game for physical security
   - `pin` for numeric codes found elsewhere in the scenario
   - `password` for computer access (with optional `postitNote` hint)
   - `rfid` for high-security doors (keycard required)
   - `flag` for VM-based hacking challenges

5. **Nested Containers**: Use containers within containers strategically
   - Avoid unsolvable dependency loops (key A inside box requiring key B, which requires key A)
   - Use `bin` containers with `locked: false` for discarded-clue items

6. **Objectives with Task Cross-References**: Verify all cross-references:
   - `targetNPC` IDs must exist in a room's `npcs` array
   - `targetRoom` must be a defined room ID
   - `targetObject` must match an object with an explicit `id` field
   - `targetGroup` must match `collection_group` on at least one item

7. **Global Variables for Ink State**: All variables referenced in Ink stories or event conditions must be declared in `globalVariables`. Use `false` as the default for boolean flags.

8. **Opening + Closing Cutscenes**: Canonical pattern from m01:
   - Opening: person NPC with `timedConversation` + `skipIfGlobal` + `setGlobalOnStart` in the start room
   - Closing: person NPC with `behavior.initiallyHidden: true` triggered by a phone NPC Ink story using `#set_global:start_debrief_cutscene:true` + `#exit_conversation`

9. **Fingerprint Mechanics**: When using biometric locks:
   - Ensure required fingerprints can be collected from objects with `hasFingerprint` in accessible rooms
   - Set appropriate `biometricMatchThreshold` (higher = more difficult)

10. **Testing and Validation**:
    - Run `ruby scripts/validate_scenario.rb scenarios/my_scenario/scenario.json.erb` before playtesting
    - Fix all `❌ INVALID` errors before testing; review `⚠ WARNING` items
    - Use `--output-json` to inspect ERB rendering if substitution looks wrong
    - Play through to verify the scenario is solvable from start to finish
    - Run `ruby scripts/generate_dungeon_graph.rb scenarios/my_scenario/scenario.json.erb` to visualise puzzle dependency flow (requires `puzzle_graph_*` metadata on key items — see §Dungeon Graph Metadata below)

---

## Dungeon Graph Metadata

Break Escape supports an optional metadata layer that lets the dungeon graph generator (`scripts/generate_dungeon_graph.rb`) produce an interactive HTML visualisation of your scenario's puzzle dependency graph — showing which items, clues, and tasks unlock which locks, rooms, and objectives.

Add these fields to objects, items, and tasks. They have **no effect on gameplay** but are read by the graph generator.

### Fields Reference

| Field | Applies to | Type | Description |
|-------|-----------|------|-------------|
| `puzzle_graph_unlocks` | any object, NPC item, task | `string` or `[string]` | The lock ID or room ID this item/task unlocks in the graph. May name `lock_<object_name>` synthetic nodes or real room IDs. |
| `puzzle_graph_role` | any object, NPC item | `string` | Semantic role label (e.g., `"key"`, `"clue"`, `"tool"`). Currently informational only. |
| `puzzle_graph_optional` | any object, NPC item | `boolean` | `true` renders the dependency edge as dashed (optional path, not required for completion). |
| `puzzle_graph_and_with` | any object, NPC item | `string` | AND-gate: this item must be combined with the named item to unlock the target (rendered as a combined edge). |
| `puzzle_graph_reveals` | notes, text_file | `string` | Narrative annotation describing what this clue reveals. Not currently used in graph generation. |

### When to Add `puzzle_graph_unlocks`

Add `puzzle_graph_unlocks` anywhere a player must find/use an item to unlock something:

- **Clue notes inside locked containers** — the note that reveals a PIN or password
- **Keys held by NPCs** — items in `itemsHeld` that are needed to open a lock
- **Readable text files on PCs** — files whose content provides an access code
- **`submit_flags` tasks** — connect flag submission to its narrative consequence
- **Items in `startItemsInInventory`** — if a starting item is the key to the first lock

### Lock ID Convention

Lock IDs follow the pattern `lock_<object_name>` (e.g., `lock_derek_personal_safe`, `lock_server_room`). These match the synthetic nodes generated by the dungeon graph script. Room IDs (e.g., `server_room`) are used directly as targets when an item unlocks room access rather than a specific object.

### Examples

#### Clue note inside a locked safe

```json
{
  "type": "notes",
  "name": "IT Room Access Code",
  "takeable": true,
  "readable": true,
  "text": "IT room code: 1234",
  "puzzle_graph_unlocks": "lock_it_room_door",
  "puzzle_graph_role": "clue"
}
```

#### NPC-held key with AND-gate

```json
{
  "type": "key",
  "name": "Server Room Keycard",
  "takeable": true,
  "puzzle_graph_unlocks": "lock_server_room_door",
  "puzzle_graph_role": "key",
  "puzzle_graph_and_with": "server_room_pin_code"
}
```

#### Optional path (dashed edge in graph)

```json
{
  "type": "notes",
  "name": "Backup Access Instructions",
  "takeable": true,
  "readable": true,
  "puzzle_graph_unlocks": "lock_archive_terminal",
  "puzzle_graph_optional": true
}
```

#### `submit_flags` task linking to narrative consequence

```json
{
  "taskId": "submit_ssh_flag",
  "type": "submit_flags",
  "title": "Submit SSH flag",
  "puzzle_graph_unlocks": "entropy_archive_unlocked"
}
```

### Generating the Graph

```bash
ruby scripts/generate_dungeon_graph.rb scenarios/my_scenario/scenario.json.erb
# Output: scenarios/my_scenario/dungeon_graph.html (open in browser)
```

The output is a three-tab HTML page:
- **Puzzle Graph** — objects, locks, rooms, and their dependencies
- **Story Graph** — objectives, aims, and task completion edges  
- **Integrated Graph** — both layers combined with a highlighted critical path

### Validator Behaviour

The scenario validator (`scripts/validate_scenario.rb`) will:
- Emit a `💡 SUGGESTION` for each clue item inside a locked container that is missing `puzzle_graph_unlocks`
- Emit a `💡 SUGGESTION` for each `submit_flags` task without `puzzle_graph_unlocks`
- Emit a `⚠ WARNING` if a `puzzle_graph_unlocks` target is not a recognised room ID, object ID, or `lock_*` ID
- Emit a `✅ GOOD PRACTICE` confirmation when the scenario has any `puzzle_graph_*` metadata
- Emit a `💡 SUGGESTION` to add metadata when none is found at all
