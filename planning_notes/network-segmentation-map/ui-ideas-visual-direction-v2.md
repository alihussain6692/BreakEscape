# MG-04 Network Segmentation Map - UI Ideas and Visual Direction v2

## Purpose

Define the updated visual direction for MG-04 so the minigame feels like a Northgate network control surface rather than a generic diagram editor, and make clear where the current implementation still falls short of that target.

## Design Principles

- Make the network architecture legible at a glance.
- Use visual hierarchy to separate safe paths from exception paths.
- Keep the interface sharp, clinical, and in-universe.
- Make the isolation decision feel like a consequence, not a puzzle reward.
- Stay consistent with Break Escape's pixel-art presentation style: sharp corners, 2px borders, no rounded UI chrome.

## Overall Layout

- Full-panel layout with a left-to-right network diagram.
- Right-hand consequence panel occupying roughly one third of the width.
- Bottom action strip for the sever control and confirmation affordance.
- The diagram should remain readable on a wall display and still work on a tablet-sized frame.

## Topology Rendering

**REQUIRED IMPLEMENTATION (not a gap):**

The minigame MUST render all four zones as defined in `planning_notes/sis_scenarios/case_1_healthcare_information_pack/system_architecture/network_architecture.md`. This is not optional for alignment with the information pack.

- Device labels MUST use canonical system names from network_architecture.md, not abbreviations.
- All four zones MUST be visually distinct and immediately legible.

### Zones (Canonical)

- External zone: red border.
- Enterprise IT zone: blue border.
- Clinical / Device zone: green border.
- Legacy flat segment: amber border (currently missing from code).

### Systems To Show (Canonical Names)

**Source of truth: `case_1_healthcare_information_pack/system_architecture/network_architecture.md`**

- External zone:
  - Internet
  - NHS HSCN Network
  - Vendor Remote Access (Infusion Pump Manufacturer)
- Enterprise zone:
  - Active Directory (Domain Controllers)
  - Email Server (Exchange)
  - Electronic Health Records (EHR)
  - File Servers (FILESERVER-01 to 04)
  - Admin Workstations (~1,800)
  - Backup Infrastructure (NAS + Tape Library)
  - SIEM / Log Aggregation
- Clinical zone:
  - Infusion Pump Fleet Management Console
  - Infusion Pumps (480 units)
  - Patient Monitor Central Stations
  - Bedside Patient Monitors (320 units)
  - Ventilators (60 units)
  - PACS Server + Image Archive
  - Imaging Modalities (CT / MRI / X-ray)
  - Clinical Workstations (Dual-Homed)
- Legacy flat segment (3 wards — not yet migrated):
  - Patient Monitors (Legacy Wards)
  - Ward Workstations (Legacy Wards)
  - Infusion Pumps (Legacy Wards)

## Line Language

- Perimeter firewall: solid white, padlock icon.
- VPN gateway: dashed line with no-MFA warning label.
- Internal firewall: solid amber, padlock icon.
- Dual-homed bridge: dashed orange with warning marker.
- Legacy flat segment: thicker dashed orange with a segmentation warning.
- Attack-path overlay: animated red arrow or tracer line drawn over the relevant bridge.

## Interactive State

**REQUIRED IMPLEMENTATION (core design):**

The minigame MUST implement toggleable exception rules with consequence panel updates. This is not a "nice to have" — it is the primary teaching mechanism for understanding the attack surface.

- Rule toggles MUST be present on the three legacy exception rules
- The consequence panel MUST update reactively per rule toggle
- The sever button MUST be gated: disabled on open, enabled only after first rule interaction

### First Open

- Show the full topology immediately.
- Show a concise consequence summary before any interaction.
- Mark the legacy exception paths as visually risky from the start.
- If the map is reopened after isolation, shift the diagram to a severed state and make that state obvious.

### Toggle State

- Each toggle widget should be readable from a distance.
- Open state should read as green and active.
- Closed state should read as red and blocked.
- The toggle animation should be short and crisp, not playful.
- When a toggle changes, the right-hand consequences should update with specific operational impact text.

### Sever State

- The sever button MUST be visually dominant and styled as a primary action.
- Default state: DISABLED (grey/inactive) when the map opens.
- The button MUST become active (amber/red) only after the player has toggled at least one exception rule.
- This enforces player engagement with understanding the architecture before making the isolation decision.
- The confirmation dialog MUST clearly warn of clinical consequences:
  - EHR access loss on affected wards → paper-based prescribing
  - Fleet management console offline → bedside manual pump entry risk
  - Drug library access loss during post-recovery validation

## Consequence Panel

Current implementation gap:

- The panel shows a generic summary today.
- It does not yet react to specific exceptions or display different outcomes by toggle state.

- Header: CONSEQUENCE ASSESSMENT.
- Show short bullet points, not paragraphs.
- Use the panel to translate topology into clinical workflow impact.
- The panel should include concrete outcomes such as:
  - EHR access loss on affected wards
  - infusion pump management loss
  - legacy ward exposure
  - isolation stopping lateral movement

## Visual Tone

- Clinical, infrastructural, and slightly oppressive.
- Avoid arcade styling and avoid overly futuristic neon.
- Use the existing Break Escape colour system so the map feels like part of the hospital set.
- Make the diagram feel like a system the players might actually see in a trust IT office.

## Motion And Feedback

- Use subtle slide-ins for consequence updates.
- Use a short pulse or trace on the attack path when a toggle changes.
- Keep the sever confirmation modal still and authoritative.
- If the link is severed, the map should show a stable post-action state rather than continuing to animate aggressively.

## Accessibility And Usability

- Maintain clear contrast between the zone fills and the connection lines.
- Keep labels large enough for a wall-mounted screen.
- Preserve usable touch targets for tablet use.
- If the viewport is narrow, stack the consequence panel below the diagram without losing the action button.

## v2 Design Decisions

These decisions are meant to close the gap between the current code and the documented Northgate experience.

1. The map should present the architecture as a security-safety argument, not just an IT topology.
2. The legacy exception paths should be unmistakable, because they are the teaching target.
3. The sever action should read as an operational decision with clinical consequences.
4. The UI should stay faithful to the hospital setting and the existing pixel-art presentation rules.

## Acceptance Checklist

- ✅ All four zones (External, Enterprise, Clinical, Legacy flat segment) are rendered and immediately legible.
- ✅ Device labels use canonical system names from network_architecture.md (not abbreviations).
- ✅ Three legacy exception rules are toggleable with clear open/closed affordances.
- ✅ Attack path overlays draw red animated arrows when rules are toggled.
- ✅ Consequence panel updates with rule-specific clinical impacts (EHR loss, fleet loss, legacy exposure).
- ✅ Sever button is DISABLED on open, enabled only after first rule toggle.
- ✅ Confirming sever displays warning modal with clinical consequences and requires YES/NO confirmation.
- ✅ Map detects prior isolation state and shows post-sever visual (red X) if `network_isolated` is already true.
- ✅ `network_rules_reviewed` is set by minigame on first toggle interaction (NOT by readable stub).
- ✅ Implementation aligns with information pack topology and minigame_planning.md behaviour spec.
