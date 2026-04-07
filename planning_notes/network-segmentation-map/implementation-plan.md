# MG-04 Network Segmentation Map - Implementation Plan

## Purpose

Implement MG-04 as a high-priority minigame for Room 2 (IT Security Office), with draft scope first and post-draft enhancements tracked explicitly.

## Source Constraints Used

- This plan is based only on:
  - user-provided MG-04 brief in this conversation
  - `game_design/minigame_planning.md` (Section 4)
  - `game_design/healthcare_draft/gdd.md` (Network Segmentation Map element + event/state sections)
  - `game_design/minigame_design_guide.md` (minigame architecture and integration points)

## Confirmed Requirements

- Category: minigame (HTML/CSS + inline SVG)
- Scenario moment: Day 1 firewall review and Day 2 isolation decision
- Core concept: incomplete segmentation as attack surface; security-safety trade-off when isolating
- Location: Room 2, wall-mounted display or tablet on stand
- Priority: High
- Main action: SEVER ENTERPRISE -> CLINICAL LINK with confirmation
- Global state write on confirm: `window.npcManager.setGlobalVariable('network_isolated', true)`
- Physical/system consequences when `network_isolated = true`:
  - `ehr_status -> OFFLINE`
  - `fleet_console_status -> OFFLINE`
  - network map indicates severed link
  - corridor warning light activates (per user brief)

## Scope Split

### Draft (MVP)

- Render three-zone network diagram.
- Render and visually highlight legacy exception rules in orange dashed style.
- Keep per-rule toggles non-interactive (view-only in draft).
- Keep `network_rules_reviewed` unused in draft.
- Make SEVER + confirmation modal the core interaction.
- Make SEVER immediately enabled in draft.
- Write `network_isolated = true` on confirmation.
- Update consequence panel around SEVER decision.

### Post-Draft Enhancement

- Add interactive toggle switches at line midpoints for rule-level changes.
- Set `network_rules_reviewed = true` when any toggle is interacted with.
- Enable real-time consequence updates for each rule toggle.
- Gate SEVER activation behind at least one toggle interaction.

## Implementation Steps

## 1. Minigame Class Scaffold

- Create a new class extending `MinigameScene` in:
  - `public/break_escape/js/minigames/network-segmentation-map/network-segmentation-map-minigame.js`
- Implement `init()`:
  - build full-panel layout container
  - inject inline SVG diagram area
  - inject right-side consequence panel
  - inject bottom SEVER control row
- Implement `start()`:
  - initialize draft state (view-only rules)
  - wire SEVER button and confirmation flow
  - call `this.complete(success)` on close/commit path according to existing minigame patterns

## 2. Register Minigame in Framework

- Update `public/break_escape/js/minigames/index.js`:
  - import new minigame class
  - `MinigameFramework.registerScene('network-segmentation-map', NetworkSegmentationMapMinigame)`

## 3. Add Starter Helper

- Update `public/break_escape/js/systems/minigame-starters.js`:
  - add `startNetworkSegmentationMapMinigame(...)` helper that calls `window.MinigameFramework.startMinigame(...)`
  - pass object/scenario context as needed for consequence text and state handling

## 4. Add Object Interaction Route

- Update `public/break_escape/js/systems/interactions.js` and/or unlock routing path used for lockType dispatch:
  - support a custom object route for the map terminal (for example `network_map_terminal` object type or lockType route)
  - ensure interacting with the Room 2 map object opens MG-04

## 5. Scenario Wiring

- In scenario data for Room 2, assign the map object to launch this minigame through the existing object interaction + lockType/starter flow.
- Ensure placement corresponds to the Room 2 environment notes (wall display/tablet stand, patch panel nearby as environmental reinforcement).

## 6. Draft UI/UX Build (Fact-Constrained)

- Three side-by-side zone boxes:
  - EXTERNAL ZONE
  - ENTERPRISE IT ZONE
  - CLINICAL / DEVICE ZONE
- Connection visuals:
  - perimeter firewall: solid white with padlock icon (always present)
  - internal firewall: amber line with padlock icon
  - legacy exception rules: dashed orange with warning icon, highlighted
- Consequence panel (right side, about 30% width):
  - title: CONSEQUENCE ASSESSMENT
  - shows clinical workflow impact text
- SEVER button:
  - large red button at bottom
  - confirmation modal text from spec

## 7. State and Event Integration

- On confirmation:
  - `window.npcManager.setGlobalVariable('network_isolated', true)`
- MG-04 draft acceptance scope for immediate NPC reactions: Helen Carver, David Osei, and Dr Fiona Hartley.
- Rely on existing downstream event/state logic to drive:
  - EHR offline
  - fleet console offline
  - NPC reactions
  - map severed-link display state

## 8. Validation Checklist

- Minigame opens from intended Room 2 object.
- Diagram renders all three zones and line types.
- Draft mode has non-togglable exception lines.
- SEVER confirmation sets `network_isolated = true` through `npcManager` API.
- Expected side effects appear in world/system state after confirmation.
- Minigame registration/starter path works without console errors.

## Deliverables

- New minigame module for MG-04
- Registration entry in minigame index
- Starter helper function
- Interaction routing update for map terminal object
- Scenario hook for Room 2 object
- Draft-complete UI with SEVER confirmation and global variable write

## Dependencies

- None listed in tracker entry.
