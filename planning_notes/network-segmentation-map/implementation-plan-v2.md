# MG-04 Network Segmentation Map - Implementation Plan v2

## Purpose

Implement MG-04 as the authoritative network-segmentation decision interface for the Northgate healthcare scenario, replacing the current readable stub in Room 2 with an interactive minigame that teaches the architecture and drives the isolation decision.

## Source of Truth

This v2 plan is based on the current scenario and healthcare documentation, not the earlier draft notes alone:

- `planning_notes/sis_scenarios/case_1_healthcare_game_design/minigame_planning.md` - MG-04 functional and visual spec
- `planning_notes/sis_scenarios/case_1_healthcare_game_design/gdd.md` - room placement, state machine, and story use
- `planning_notes/sis_scenarios/case_1_healthcare_game_design/be_scenario_walkthrough.md` - player flow through Room 2 and Room 3
- `planning_notes/sis_scenarios/case_1_healthcare_game_design/scenario_implementation_notes.md` - current scenario stub and placeholder wiring
- `planning_notes/sis_scenarios/case_1_healthcare_information_pack/system_architecture/network_architecture.md` - canonical topology and node names
- `scenarios/sis01_sis_healthcare/scenario.json.erb` - live Room 2 placeholder object and current state hooks
- `scenarios/sis01_sis_healthcare/VALIDATION_SUMMARY.md` - current scenario validation state

## Current State

- The current scenario stub in `scenarios/sis01_sis_healthcare/scenario.json.erb` still uses a readable `smartscreen` named `network_map_screen` and sets `network_rules_reviewed = true` on read (wrong: minigame should set this on first toggle).
- The live implementation exists in `public/break_escape/js/minigames/network-segmentation-map/network-segmentation-map-minigame.js` and is already registered and routable.
- Room 3 still provides the fallback isolation route via the dual-authorisation panel.
- `network_isolated = true` is already the key downstream state for both routes.
- **Critical misalignment**: The minigame renders 3 zones; canonical documentation specifies 4 zones.

## Current Implementation Snapshot

The implementation currently does the following:

- Renders a working minigame shell with **three zone boxes** (missing the fourth legacy flat segment).
- SVG connections, consequence panel, sever button, and confirmation modal all present.
- Registers the scene in `public/break_escape/js/minigames/index.js` and exposes the starter helper.
- Routes `type: "network-segmentation-map"` interactions in `public/break_escape/js/systems/interactions.js`.
- Writes `network_isolated = true` through `window.npcManager.setGlobalVariable(...)` when sever is confirmed.
- Falls back to direct global state writes if `npcManager` is unavailable.
- **NOT YET**: Toggleable exception rules (view-only currently).
- **NOT YET**: Four-zone topology with legacy flat segment.
- **NOT YET**: Rule-specific consequence panel updates.
- **NOT YET**: Attack-path overlays (red arrows).
- **NOT YET**: SEVER button gating (enabled immediately, should gate on first toggle).
- **NOT YET**: `network_rules_reviewed` written by minigame (currently only by readable stub).
- **NOT YET**: Canonical device labels (uses abbreviations instead).
- **NOT YET**: Healthcare scenario stub replacement (Room 2 still uses readable version).

## Design Targets for v2

The gap analysis below is the main reason this v2 plan exists: the code is functional, but it is not yet fully aligned with the healthcare documentation.

### Gameplay Role

- Present the hospital network as a security-safety tradeoff, not as a generic admin console.
- Make the player understand why the incomplete segmentation is the attack path.
- Make the isolation decision legible and consequential.
- Keep the network map focused on the Northgate architecture already documented in the information pack.

### Topology to Render

**REQUIRED: This is not optional for alignment with the canonical information pack.**

Currently missing:

- The code renders only three zones; the fourth (legacy flat segment) must be added.
- Device labels are abbreviated; canonical names from network_architecture.md must be used.

**Target topology (extract directly from `case_1_healthcare_information_pack/system_architecture/network_architecture.md`):**

**Four zones with canonical system contents:**

- **External zone**: Internet, NHS HSCN Network, Vendor Remote Access (Infusion Pump Manufacturer)
- **Enterprise IT zone**: Active Directory (Domain Controllers), Email Server (Exchange), Electronic Health Records (EHR), File Servers, Admin Workstations, Backup Infrastructure (NAS + Tape Library), SIEM / Log Aggregation
- **Clinical / Medical Device zone**: Infusion Pump Fleet Management Console, Infusion Pumps (480 units), Patient Monitor Central Stations, Bedside Patient Monitors (320 units), Ventilators (60 units), PACS Server + Image Archive, Imaging Modalities (CT / MRI / X-ray), Clinical Workstations (Dual-Homed)
- **Legacy flat segment**: Patient Monitors (Legacy Wards), Ward Workstations (Legacy Wards), Infusion Pumps (Legacy Wards) — 3 wards not yet migrated to segmented VLAN

**Cross-zone connections to visualise:**

- Perimeter firewall (External → Enterprise)
- SSL VPN gateway with no-MFA warning (External → Enterprise)
- Internal firewall with partial segmentation (Enterprise → Clinical)
- **Dual-homed clinical workstations** (Enterprise ↔ Clinical, dashed orange line) — PRIMARY ATTACK VECTOR
- **Legacy flat L2 segment** (Enterprise to Legacy, unfiltered) — SECONDARY ATTACK VECTOR

### Interaction Model

**REQUIRED: Toggleable exception rules are core to the design, not a future enhancement.**

Currently missing:

- No toggle widgets exist in the current minigame.
- No attack-path overlays are drawn.
- The consequence panel is static, not rule-reactive.

Target interaction model (from minigame_planning.md § 4):

- The minigame MUST be interactive, not a pure static diagram.
- The THREE SPECIFIC LEGACY EXCEPTION RULES must be toggleable:
  1. **Ward 5 workstations dual-homed** (Enterprise ↔ Clinical) — entry point for lateral movement
  2. **Ward 7 nursing station retains enterprise domain join** — legacy auth exception
  3. **Pump fleet management accessible from Zone B admin subnet** — console access bridge
- Each toggle interaction MUST:
  - Immediately set `network_rules_reviewed = true` (on first toggle only, then skip)
  - Update the consequence panel with rule-specific clinical impacts
  - Draw or update the red attack-path overlay showing how an attacker would traverse that rule
- The sever button remains initially disabled and becomes active only after the first toggle.
- The sever action must write `window.npcManager.setGlobalVariable('network_isolated', true)` and trigger NPC reactions.

## Behaviour Specification

### Default Open State

Target behaviour:

- Render the full four-zone topology immediately on open with all systems visible.
- Highlight the three legacy exception rules (dashed orange lines) so dangerous paths are immediately obvious.
- Display a generic consequence summary in the right-hand panel:
  - _"Three legacy exception rules create unfiltered access between enterprise and clinical zones."_
  - _"Isolating the network link will break EHR access and device management, forcing manual clinical operations."_
- Colour-code the legacy rule lines distinctly (orange/amber) to draw visual attention to them.
- Make it clear that toggling any rule will reveal specific clinical impact.

### Toggle Interaction

Target behaviour (REQUIRED):

For each of the three toggleable exception rules:

**Rule 1: Ward 5 Dual-Homed Workstations (Enterprise ↔ Clinical)**

- Consequence: _"Ward 5 clinical workstations lose EHR access. Prescriptions must be transcribed to paper. Manual entry increases medication error risk."_
- Attack path: `Compromised enterprise workstation → dual-homed bridge → Clinical zone devices`
- Visual: dashed orange line connecting Enterprise/Clinical with ward 5 label

**Rule 2: Ward 7 Enterprise Domain Join (Legacy Auth Exception)**

- Consequence: _"Ward 7 nursing station cannot authenticate to enterprise domain. Loses access to email and file servers. Clinical staff cannot access shift schedules during manual operations."_
- Attack path: `Compromised enterprise AD → bidirectional domain link → Ward 7 devices`
- Visual: amber/orange line from AD to Ward 7 workstations

**Rule 3: Fleet Management from Admin Subnet (Zone B → Zone C Console Access)**

- Consequence: _"Infusion pump fleet management console cannot be accessed from enterprise admin workstations. All dose programming reverts to bedside manual entry. Drug library updates unavailable."_
- Attack path: `Enterprise admin account → permitted firewall rule → Fleet management console`
- Visual: orange line from Enterprise admin workstations to Clinical fleet console

**Toggle mechanics:**

- Each toggle has a clear open/closed affordance (green = open/vulnerable, red = blocked/isolated)
- Clicking a toggle plays a short animation and updates the consequence panel immediately
- Drawing a red attack-path overlay on the relevant bridge line when the rule is toggled
- On first interaction ONLY: set `network_rules_reviewed = true` and enable the sever button

### Sever Interaction

Target behaviour:

- The SEVER button MUST be disabled (greyed out) when the map opens.
- The button becomes active (amber/red, clickable) ONLY after the player has toggled at least one exception rule.
- This enforces engagement: players must understand the architecture before making the isolation decision.
- On click, a confirmation modal appears with the warning text:
  - _"CONFIRM: Sever enterprise-to-clinical network link"_
  - _"Clinical consequences: EHR offline → paper prescribing, Fleet console offline → manual bedside pumping, Backup access blocked → recovery delayed"_
  - Two buttons: YES (proceed) and NO (cancel)
- On YES:
  - Write `network_isolated = true` via `window.npcManager.setGlobalVariable()`
  - Update the map visual to show a red X across all inter-zone connection lines
  - Display a post-sever status banner: _"NETWORK ISOLATED: Enterprise and clinical zones disconnected."_
  - Auto-complete the minigame after 2 seconds
- If the map is reopened after isolation, check `network_isolated` state and display the severed visual immediately.

## Integration With Other Components

### Room 2

**CRITICAL BLOCKING TASK: Scenario stub must be replaced for testing to proceed.**

Current state:

- The live scenario in `scenarios/sis01_sis_healthcare/scenario.json.erb` (line 867–879) still uses a readable `smartscreen` named `network_map_screen`.
- The `onRead` action sets `network_rules_reviewed = true` (wrong actor — should be minigame).
- TODO[MINIGAME] comment at line 874 documents the replacement need.
- The test scenario (`scenarios/test-network-segmentation-plan/scenario.json.erb`) already uses the real minigame and works.

Target Room 2 integration:

1. Replace the `network_map_screen` object definition in the healthcare scenario:
   - Change from `type: "smartscreen"` with `readable: true` to `type: "network-segmentation-map"`
   - Remove the hardcoded readable text
   - Add proper scenarioData with minigame configuration
   - Remove the `onRead` action (minigame now writes `network_rules_reviewed`)
2. Update the object observations to reference it as the interactive network map minigame
3. Verify the object is active and interactable
4. Once swapped, the Room 2 objectives will be gated properly:
   - David Osei's sign-off can fire when `network_rules_reviewed = true` (set by minigame)
   - Dual-authorisation panel in Room 3 recognises prior isolation if needed

### Room 3 Fallback

- Leave the dual-authorisation route intact.
- If the map is used first, Room 3 should still recognise `network_isolated = true` and avoid double-applying side effects.
- If Room 3 is used first, the map should open in a post-isolation state and explain that the link is already severed.
- The plan should treat Room 3 as a governance fallback, not a competing implementation.

### NPC and Story Hooks

Current implementation gap:

- The minigame code itself does not yet manage NPC reactions; it only writes the state variable.
- The scenario docs imply a wider reaction set than the implementation currently visualises.

Target story hooks:

- Immediate reaction targets should follow the live scenario wiring: Sarah Mitchell, Ravi Anand, David Osei, and Helen Carver.
- Dr Fiona Hartley remains relevant for downstream regulatory and governance dialogue, but the map itself should not depend on her to function.
- David’s safety-case dialogue around CLAIM-HC-001 should remain the conceptual bridge into the map.

### Global State Dependencies

Current implementation gap:

- The minigame currently only writes `network_isolated` and does not yet use `network_rules_reviewed` internally.
- There is no runtime logic yet for reacting to `ehr_status` or `fleet_console_status` changes inside the map UI.

Target global dependencies:

- Read from the existing incident state rather than inventing new abstractions.
- At minimum, the map must recognise:
  - `network_rules_reviewed`
  - `network_isolated`
  - `ehr_status`
  - `fleet_console_status`
  - `major_incident_declared`
- The map should not change `ward_monitor_status`, because that state is already part of the ward narrative and starts offline.

## Implementation Steps

1. Build the MG-04 scene as an HTML/CSS + inline SVG minigame.
2. Use the canonical topology from `network_architecture.md` as the rendering source.
3. Implement rule toggles with consequence-panel updates and attack-path overlays.
4. Wire the sever confirmation to `network_isolated = true`.
5. Add scenario wiring so the Room 2 object opens the minigame instead of the readable stub.
6. Make the map resilient when re-opened after isolation or after the Room 3 fallback path.
7. Verify all downstream story and state reactions still fire as expected.

## Acceptance Criteria

- ✅ Topology: All four zones (External, Enterprise, Clinical, Legacy) are rendered with canonical system names from network_architecture.md.
- ✅ Rules: Three legacy exception rules are present, toggleable, and have clear open/closed affordances.
- ✅ Consequences: Consequence panel updates reactively per rule toggle with specific clinical impact text.
- ✅ Attack paths: Red animated arrow overlays draw when rules are toggled, showing attacker traversal paths.
- ✅ State gate: `network_rules_reviewed = true` is written by minigame on FIRST toggle interaction (not by readable stub).
- ✅ SEVER gate: Button is disabled on open, enabled only after first rule toggle.
- ✅ SEVER action: Writes `network_isolated = true`, displays post-sever visual (red X), and triggers NPC reactions.
- ✅ Resilience: Map detects prior isolation and shows severed state if reopened after isolation.
- ✅ Scenario integration: Healthcare scenario Room 2 object is swapped from readable stub to real minigame type.
- ✅ Alignment: Implementation matches minigame_planning.md (§4) specification exactly, not an earlier draft.
- ✅ NPC coordination: David Osei (safety case), Sarah Mitchell (clinical), Ravi Anand (IT), Helen Carver (governance) reactions fire correctly off `network_isolated` and `network_rules_reviewed` state.

## Risks and Open Questions → Resolved

**Previous ambiguity:** "The documentation currently has a mismatch about whether the map should be strictly view-only or toggle-driven in the draft flow."

**Resolution:** The canonical source (minigame_planning.md § 4) specifies toggles as the core mechanic. Toggles ARE REQUIRED. The v2 plan treats this as the target behaviour, aligned with the design spec. The readable stub is a temporary placeholder only — the minigame must replace it.

**Previous ambiguity:** "The docs also disagree slightly on which NPCs should react immediately to isolation."

**Resolution:** Follow the live scenario wiring in scenario.json.erb. Immediate reaction targets are:

- Sarah Mitchell (Ward 7, clinical consequence awareness)
- Ravi Anand (IT Security, isolation confirmation)
- David Osei (Clinical Engineering, safety-case alignment)
- Helen Carver (Major Incident Command, governance/ICO notification)

Dr Fiona Hartley remains a downstream regulatory conversation but is not dependent on the map itself.
