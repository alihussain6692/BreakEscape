# MG-04 Network Segmentation Map - UI Ideas and Visual Direction

## Purpose

Document the visual direction for MG-04 using only details already present in the game design documentation and user brief, with no added fictional UI features.

## Source Constraints Used

- user-provided MG-04 brief in this conversation
- `game_design/minigame_planning.md` (Section 4, Visual Design)
- `game_design/healthcare_draft/gdd.md` (Element context and room placement)

## Visual Direction (Confirmed)

### Overall Composition

- Full-panel map-oriented interface.
- Left-to-right network topology showing three zone boxes:
  - EXTERNAL ZONE
  - ENTERPRISE IT ZONE
  - CLINICAL / DEVICE ZONE
- Right sidebar reserved for consequences (about 30% width).
- Bottom row reserved for the critical sever action.

### Zone Styling

- Pixel-art bordered boxes.
- Zone border colors:
  - External: blue
  - Enterprise IT: green
  - Clinical/Device: teal
- Each zone contains icon groups for key systems named in design docs:
  - VPN gateway
  - domain controllers
  - EHR server
  - file servers / infusion pump console
  - patient monitors
  - PACS

### Connection Line Language

- Pixel-art path style (horizontal segments and step corners).
- Rule types:
  - Perimeter firewall (Enterprise <-> External): solid white + padlock icon (always present)
  - Internal firewall (Enterprise <-> Clinical): solid amber + padlock icon
  - Legacy exception rules: dashed orange + warning triangle icon, one line per rule

## Draft Presentation Rules (MVP)

- Legacy exception lines are visually highlighted.
- Per-rule toggles are not interactive in draft (per simplified draft note in planning docs and user brief).
- Consequence panel and SEVER flow are primary interactive elements in draft.
- SEVER is immediately enabled in draft.
- `network_rules_reviewed` remains unused in draft.

## Post-Draft Interaction Direction

- Add midpoint pixel toggle widgets for each toggleable rule:
  - left position = OPEN (green)
  - right position = CLOSED (red)
- Toggle motion includes a short switch animation.
- Consequence panel updates per rule change.

## Consequence Assessment Panel

- Location: right sidebar.
- Header text: CONSEQUENCE ASSESSMENT.
- Content style: impact-focused bullet list tied to network action state.
- Example impact text present in design docs:
  - EHR access lost on Ward 5; medication prescribing reverts to paper.

## Critical Action UI

### SEVER Button

- Large red pixel-art button at bottom of panel.
- Label text: SEVER ENTERPRISE -> CLINICAL LINK.
- Draft behavior: immediately enabled.
- Full-feature direction (post-draft): initially disabled/greyed out; activates after engagement with rule controls.

### Confirmation Modal

- Triggered on SEVER press.
- Confirmation copy from design docs:
  - This will disconnect all clinical zone systems from the enterprise network.
  - Clinical staff will lose EHR access.
  - Confirm?
- Actions: YES / NO buttons in pixel-art style.

## In-World Placement and Narrative Framing

- Display exists in Room 2 (IT Security Office).
- Form factor: wall-mounted touch screen or tablet on stand.
- Patch panel rack in room visually reinforces the topology concept.
- Conceptual continuation in Room 3 via Dual-Authorisation route to `network_isolated = true` if not set from map.
- MG-04 draft acceptance scope for immediate NPC reactions: Helen Carver, David Osei, and Dr Fiona Hartley.

## Visual Acceptance Checklist

- Three-zone topology is immediately legible at a glance.
- Rule type differences are distinguishable by color, icon, and line style.
- Exception-rule highlighting is clear in draft mode.
- Consequence panel communicates clinical workflow impact clearly.
- SEVER action and confirmation communicate the security-safety trade-off.

## Finalized Draft Decisions

1. Draft behavior is strictly view-only.
2. SEVER is immediately enabled in draft.
3. NPC reaction scope for MG-04 draft acceptance is Ravi Anand and David Osei.
4. `network_rules_reviewed` remains unused in draft.

## Design-Doc Divergence Note

- These draft UI decisions intentionally override conflicting gdd text that describes toggle-gated SEVER during draft.
- Post-draft interaction direction remains unchanged and still includes per-rule toggle controls.
- `gdd.md` initial state description refers to legacy exception rules as "highlighted in amber". This plan uses orange (dashed orange lines) per the authoritative visual design spec in `minigame_planning.md` Section 4. Amber is already used for the internal firewall line; using orange for legacy exception rules preserves the distinction between the two rule types.
