// ===========================================
// NPC: Dr Nalini Bashir (NCSC / HSE Senior Inspector)
// Scenario: Albion Battery Hall Crisis
// Type: Person NPC (debrief station — initiallyHidden, revealed when facility_safe_state)
// Role: Closing synthesis; safety claim review; SIS patch dilemma; normalisation of deviance
// ===========================================
//
// GLOBALS READ:
//   esd_activated, network_isolated, sis_tamper_confirmed, ncsc_notified,
//   trent_water_notified, en001_claim_assessed, en002_claim_assessed,
//   en005_claim_assessed, patch_decision, jump_server_confirmed
//
// GLOBALS WRITTEN:
//   en005_claim_assessed (set when SIS patch dilemma topic engaged)
//   patch_decision (set by player choice: "active_management" or "deferral")
//   debrief_complete (set when debrief closing topic completed)
//
// NOTE: This NPC reveals via eventMapping when dr_bashir_visible = true.
//   timedConversation fires debrief_intro automatically on reveal.
//   Person NPC — has position in scada_control_room (initiallyHidden until safe state).
//
// ===========================================

// Global variables managed by scenario - declared locally and updated by game engine
VAR sis_tamper_confirmed = false
VAR trent_water_notified = false
VAR en005_claim_assessed = false
VAR ncsc_notified = false

// Local NPC state tracking
VAR debrief_started = false
VAR topic_root_cause_done = false
VAR topic_sis_independence_done = false
VAR topic_patch_done = false
VAR topic_nis_reviewed = false
VAR topic_closing_done = false


// ===========================================
// AUTO-TRIGGERED DEBRIEF INTRO (via timedConversation on dr_bashir_visible)
// ===========================================

=== debrief_intro ===
#speaker:dr_nalini_bashir
~ debrief_started = true

Dr Bashir: I'm Dr Nalini Bashir. I'm here representing both NCSC and the HSE's ICS security inspection programme — we're conducting this review jointly because the incident involved both a notifiable NIS breach and a near-miss under COMAH.

Dr Bashir: You've done the hard part — the immediate safety emergency is contained. What I need to do is understand what happened, what held, and what failed.

Dr Bashir: This is not a blame exercise. It is a learning exercise. But it requires honesty about both the system and the organisation.

-> DONE


// ===========================================
// DEFAULT ENTRY POINT
// ===========================================

=== start ===
#speaker:dr_nalini_bashir

{ not debrief_started:
    Dr Bashir: Dr Nalini Bashir — NCSC and HSE. I'm here for the post-incident review.
    Dr Bashir: When you're ready, we should go through what happened and what it means for your safety case.
    ~ debrief_started = true
    -> hub
}

{ debrief_started:
    -> hub
}


// ===========================================
// MAIN DEBRIEF HUB
// ===========================================

=== hub ===
#speaker:dr_nalini_bashir

+ [Discuss the root cause and attack pathway] { not topic_root_cause_done }
    -> root_cause

+ [Discuss SIS independence — how was the SIS compromised?] { sis_tamper_confirmed and not topic_sis_independence_done }
    -> sis_independence

+ [Discuss the SIS patch dilemma] { sis_tamper_confirmed and not topic_patch_done }
    -> patch_dilemma

+ [Review the NCSC notification] { not topic_nis_reviewed }
    -> nis_review

+ [Ask about the Trent Water cross-sector dependency] { trent_water_notified }
    -> trent_water_review

+ [Closing summary — what have we learned?] { topic_root_cause_done and topic_sis_independence_done and topic_patch_done }
    -> closing_summary

+ [I need more time — I'll come back to this]
    Dr Bashir: Of course. I'll be here. Take the time you need.
    #exit_conversation
    -> DONE


// ===========================================
// ROOT CAUSE ANALYSIS
// ===========================================

=== root_cause ===
#speaker:dr_nalini_bashir
~ topic_root_cause_done = true

Dr Bashir: The entry point was a supply chain compromise — a printer firmware update pushed to Albion's enterprise network approximately four months ago. That gave the attacker a persistent foothold.

Dr Bashir: From there: domain controller access, then the dual-homed historian and the jump server — both of which bridged the IT/OT boundary in ways that weren't supposed to be possible.

Dr Bashir: By the time they modified the SIS setpoints at 03:22, they'd been in the SCADA network for hours.

* [Was the attack detectable earlier?]
    -> attack_detection_timing

* [What made the jump server the critical entry point?]
    -> jump_server_criticality

* [What do you do next from a regulatory standpoint?]
    -> regulatory_next_steps


=== attack_detection_timing ===
#speaker:dr_nalini_bashir

Dr Bashir: Yes — twice. The historian Modbus proxy traffic that Marcus Webb flagged three weeks ago. And the c.ellison RDP session that had been active since 01:47.

Dr Bashir: Neither was acted upon in time. The first because OT monitoring was out of scope. The second because the SOC contract excluded the jump server session logs.

Dr Bashir: But here's the crucial point: the attacker made these detectable things. They left IoCs — indicators of compromise — that a monitoring system with the right scope would have caught.

Dr Bashir: The defence existed. It was just outside the contract.

-> hub


=== jump_server_criticality ===
#speaker:dr_nalini_bashir

Dr Bashir: A bidirectional RDP capability that was supposed to be temporary. It was enabled during commissioning and never reverted.

Dr Bashir: That's a configuration management failure. The 'temporary' setting became a permanent attack pathway because no one was responsible for reviewing it.

Dr Bashir: The jump server is the hinge between IT and OT. Once an attacker owns that, they own both zones. Which is exactly what happened here.

Dr Bashir: The contractor account c.ellison was probably established during commissioning. When the contractor left, the account should have been deleted. Instead, it sat dormant with a valid password for eight months.

Dr Bashir: Someone obtained that password — possibly from a credential dump, possibly from a compromised contractor system — and used it to enter through the jump server.

-> hub


=== regulatory_next_steps ===
#speaker:dr_nalini_bashir

Dr Bashir: The NIS investigation will take approximately three months. We'll publish a de-identified version of the findings to support sector-wide learning.

Dr Bashir: Albion will be required to submit a remediation plan addressing: (1) the SIS independence failure, (2) the IT/OT boundary configuration, and (3) the OT monitoring gap.

Dr Bashir: The remediation plan will need to detail timelines for the SIS firmware patch and recertification, architecture changes to the jump server and historian, and contract amendments to the SOC scope.

-> hub


// ===========================================
// SIS INDEPENDENCE
// ===========================================

=== sis_independence ===
#speaker:dr_nalini_bashir
~ topic_sis_independence_done = true

Dr Bashir: IEC 61511 requires the SIS to be logically — and ideally physically — isolated from the basic process control system. The principle is: the safety system should function correctly even when the control system is completely compromised.

Dr Bashir: At Albion, the SIS engineering port was reachable from the SCADA network. That violated the independence requirement.

* [How was the SIS engineering port reachable?]
    -> sis_port_vulnerability

* [What should the architecture have looked like?]
    -> sis_proper_architecture

* [Why did the hardwired ESD still work?]
    -> eis_independence


=== sis_port_vulnerability ===
#speaker:dr_nalini_bashir

Dr Bashir: The jump server that bridged IT and OT also had access to the SIS engineering subnet. It was documented in the network architecture, but the safety implications weren't evaluated.

Dr Bashir: Marcus Webb's risk assessment eighteen months ago identified the SIS patch vulnerability but didn't explicitly note that the SIS engineering port was reachable from SCADA. That gap in the risk assessment was consequential.

Dr Bashir: So we have three failures here: (1) the architecture allows connectivity that shouldn't exist; (2) the risk assessment doesn't fully articulate the implications; (3) the compensating controls that would have mitigated the risk were never implemented.

Dr Bashir: Any one of those alone would be manageable. All three together created the conditions for what happened this morning.

#set_global:en002_claim_assessed:true
-> hub


=== sis_proper_architecture ===
#speaker:dr_nalini_bashir

Dr Bashir: The SIS should have been on a physically separate network with no connection to the SCADA zone except the hardwired process connections — the sensors and actuators.

Dr Bashir: Engineering access to the SIS should have required physical presence at a dedicated, air-gapped configuration terminal. Not a network connection.

Dr Bashir: The SIS should speak to the process via hardwired signals only — temperature sensor feeds, alarm outputs, valve control wires. No Ethernet, no TCP/IP, no possibility of remote compromise.

Dr Bashir: That's what IEC 61511 calls for in principle. Albion's design — with the engineering port reachable from SCADA — was a compromise that traded safety for operational convenience.

-> hub


=== eis_independence ===
#speaker:dr_nalini_bashir

Dr Bashir: Because it was designed to be independent of every software and network system in the facility.

Dr Bashir: A hardwired relay circuit doesn't have firmware. It doesn't have a network interface. It cannot be accessed remotely. That's why it was the last remaining effective safety function when everything else was compromised.

Dr Bashir: And that's why I kept asking about it during the incident — because a hardwired ESD is the penultimate safety layer. If that had also been compromised, there would have been no remaining protection.

Dr Bashir: You pressed it at the right time. And it worked exactly as designed.

-> hub


// ===========================================
// SIS PATCH DILEMMA
// ===========================================

=== patch_dilemma ===
#speaker:dr_nalini_bashir
~ topic_patch_done = true
~ en005_claim_assessed = true
#set_global:en005_claim_assessed:true

Dr Bashir: The SIS firmware patch has been available for eighteen months. It closes the authentication bypass on the engineering port — the exact vulnerability that was exploited.

Dr Bashir: Applying it requires SIL 2 recertification under IEC 61511. Eight weeks offline, approximately £180,000.

Dr Bashir: I'm going to ask you to make a recommendation. Not what Albion chose — what you would recommend.

-> patch_choice


=== patch_choice ===
#speaker:dr_nalini_bashir

Dr Bashir: Two options. First: recommend applying the patch and accepting the recertification cost. Second: recommend continued deferral with genuinely effective compensating controls. Which do you recommend?

* [Apply the patch — accept the recertification cost]
    -> recommend_patch

* [Deferral with effective compensating controls]
    -> recommend_deferral

* [Ask what compensating controls would look like]
    -> compensating_controls_explained


=== recommend_patch ===
#speaker:dr_nalini_bashir
#set_global:patch_decision:active_management

Dr Bashir: That is my recommendation too. And I'll tell you why.

Dr Bashir: The compensating control that was in place — OT-inclusive monitoring — was never actually implemented. The risk assessment accepted a compensating control that didn't exist.

Dr Bashir: If you are going to defer a safety system patch, the compensating controls must actually provide the mitigation they claim to provide. In this case, they did not.

Dr Bashir: The cost of recertification is real. But so is the cost of a thermal runaway event in a 220 MWh battery hall.

-> hub


=== recommend_deferral ===
#speaker:dr_nalini_bashir
#set_global:patch_decision:deferral

Dr Bashir: That position is defensible — under very specific conditions.

Dr Bashir: The compensating controls must actually be implemented and verified. OT-inclusive monitoring — not a SOC contract that excludes the OT zone. Firewall rules that actually isolate the SIS engineering port. Network monitoring that would have detected the c.ellison session at 01:47 rather than at 06:28.

Dr Bashir: And those controls must be subject to independent verification. Not accepted in a risk assessment and then forgotten.

Dr Bashir: Is that what Albion had in place?

* [Clearly not — the compensating controls were ineffective]
    Dr Bashir: Correct. Which is why deferral was not a defensible position in this case, even if the principle can be defensible in others.
    Dr Bashir: The lesson: accepting a risk with compensating controls is only as good as those controls actually are.
    #set_global:patch_decision:deferral
    -> hub

* [That's a fair standard — it just wasn't met here]
    Dr Bashir: Exactly right. The decision framework wasn't wrong. The execution of the decision was.
    -> hub


=== compensating_controls_explained ===
#speaker:dr_nalini_bashir

Dr Bashir: For deferral to be defensible under IEC 61511 clause 4.2.14 — the risk assessment must identify specific, implementable compensating controls that reduce the risk to an acceptable level.

Dr Bashir: In this case, that would mean: OT-inclusive monitoring that covers the SCADA zone, network segmentation that isolates the SIS engineering port from the SCADA network, and regular review of the risk assessment.

Dr Bashir: The compensating control that was recorded — enhanced network monitoring — was never actually implemented for the OT zone. The CastleTech contract explicitly excluded it.

-> patch_choice


// ===========================================
// NIS NOTIFICATION REVIEW
// ===========================================

=== nis_review ===
#speaker:dr_nalini_bashir
~ topic_nis_reviewed = true

{ ncsc_notified:
    Dr Bashir: The NIS notification was made. Good. I want to note that timely notification matters — both as a regulatory obligation and as a practical matter, because the NCSC can provide active support during an OT incident.
    -> hub
}

{ not ncsc_notified:
    Dr Bashir: I note that the NIS Regulations notification has not yet been submitted.
    Dr Bashir: You are an Operator of Essential Services. The 72-hour clock began when you detected this incident. Given the physical consequences, NCSC will expect to hear from you today.
    Dr Bashir: The form is in your Incident Response folder. This needs to be done.
    -> hub
}


// ===========================================
// TRENT WATER CROSS-SECTOR REVIEW
// ===========================================

=== trent_water_review ===
#speaker:dr_nalini_bashir

Dr Bashir: You notified Trent Water — that was the right call, and it was made quickly. Their OT security team has confirmed there was no active intrusion on their ICS network, but they did find a suspicious file on a workstation that accessed the shared file server.

Dr Bashir: This is exactly the kind of cross-sector dependency that nobody formally risk-assessed. A shared enterprise file server between an energy storage operator and a water utility. Both OES. No formal agreement covering cyber incident notification or shared infrastructure responsibilities.

Dr Bashir: That gap needs to be addressed at sector level, not just at Albion's level.

-> hub


// ===========================================
// CLOSING SUMMARY
// ===========================================

=== closing_summary ===
#speaker:dr_nalini_bashir
~ topic_closing_done = true
#complete_task:talk_to_dr_bashir
#set_global:debrief_complete:true

Dr Bashir: Let me summarise what this incident tells us.

Dr Bashir: The hardwired ESD worked. It worked because it was designed to be independent of every system that could be compromised. That's defence in depth functioning exactly as intended.

Dr Bashir: Everything else failed — not because the safety engineering was wrong in principle, but because the security architecture that was supposed to protect it was never properly maintained. A temporary commissioning configuration became a permanent attack pathway. A risk assessment accepted compensating controls that were never actually implemented.

Dr Bashir: The deepest lesson here is what I call normalisation of deviance. The known risks — the jump server configuration, the SIS patch deferral, the historian proxy — became the normal operating state. They were documented, accepted, and forgotten. Until they were exploited.

Dr Bashir: A safety case is not a compliance artefact. It is a living document. When the risks documented in that safety case are accepted, the compensating controls must actually exist, must actually work, and must actually be reviewed.

* [What happens next — from a regulatory standpoint?]
    Dr Bashir: The NIS investigation will take approximately three months. We'll publish a de-identified version of the findings to support sector-wide learning.
    Dr Bashir: Albion will be required to submit a remediation plan addressing the SIS independence failure, the IT/OT boundary configuration, and the OT monitoring gap. Marcus Webb's risk assessments were directionally correct — the organisation needs to act on them.
    #exit_conversation
    -> DONE

* [Any final advice for the team?]
    Dr Bashir: The SCADA engineer who arrived early for a maintenance window and trusted an old analog thermometer over a sophisticated digital system — she's the reason this didn't become a catastrophe.
    Dr Bashir: Invest in the people who understand the physical systems as well as the digital ones. They are your last line of defence.
    #exit_conversation
    -> DONE
