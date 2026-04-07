// ===========================================
// NPC: Marcus Webb (OT Security Manager)
// Scenario: Albion Battery Hall Crisis
// Type: Phone NPC
// Role: Security authority; ESD direction; network isolation trade-off; CLAIM-EN-001
// ===========================================
//
// GLOBALS READ:
//   jump_server_confirmed, historian_flatline_found, anomaly_detected,
//   esd_activated, network_isolated, sis_tamper_confirmed
//
// GLOBALS WRITTEN:
//   marcus_webb_contacted (set when first substantive call completes)
//   en001_claim_assessed (set when IT/OT boundary topic discussed)
//
// NOTE: Phone NPC — no position, no sprite. Accessed via site_phone inventory item.
// timedMessages are defined in scenario.json.erb eventMappings.
//
// ===========================================

// Global variables managed by scenario - declared locally and updated by game engine
VAR jump_server_confirmed = false
VAR marcus_webb_contacted = false
VAR sis_tamper_confirmed = false
VAR esd_activated = false
VAR network_isolated = false

// Local NPC state tracking
VAR marcus_called = false
VAR marcus_rdp_briefed = false
VAR topic_isolation_discussed = false
VAR topic_claim001_discussed = false
VAR topic_nis_discussed = false


// ===========================================
// FIRST CALL
// ===========================================

=== start ===
#speaker:marcus_webb

{ not marcus_called:
    Marcus: Marcus Webb.
    Marcus: Priya said you'd be calling. What have you got?
    ~ marcus_called = true
    -> first_call_hub
}

{ marcus_called:
    -> hub
}


=== first_call_hub ===
#speaker:marcus_webb

* [The HMI readings look normal but the analog thermometer in Battery Hall 1 reads 51°C]
    Marcus: Fifty-one. Say that again.
    Marcus: The HMI says twenty-eight and the gauge says fifty-one?
    Marcus: That gauge doesn't lie. Something's feeding the SCADA false data.
    -> initial_assessment

* [The historian trend for Rack A1 shows a flat line for three hours]
    Marcus: Zero variance? Not possible unless the data is synthetic. Someone replaced the real readings.
    Marcus: Do you have the jump server access logs yet? I want to see who's been on that network.
    -> initial_assessment

* [Nothing specific yet — just a gut feeling from Priya]
    Marcus: Priya's gut has been right more often than our monitoring systems. Tell her I'm listening.
    Marcus: Get me something specific — historian trend, access logs, anything.
    -> hub


=== initial_assessment ===
#speaker:marcus_webb

Marcus: Right. I need you to get into the Engineering Workshop and pull the jump server access logs on HMI-ENG-02.

Marcus: Key's in the duty desk drawer. Once you're in, look for any active sessions on JS-ALBION-01 that shouldn't be there. Dormant accounts, unusual source IPs.

Marcus: And find out if Priya can check the SIS configuration while you're there. I want to know if anyone touched the setpoints.

#set_global:marcus_webb_contacted:true

-> hub


// ===========================================
// MAIN HUB (repeatable)
// ===========================================

=== hub ===
#speaker:marcus_webb

+ [I've identified a contractor RDP session — c.ellison — connected since 01:47] { jump_server_confirmed and not marcus_rdp_briefed }
    -> rdp_session_confirmed

+ [Tell me about the network isolation decision] { jump_server_confirmed and not topic_isolation_discussed }
    -> isolation_trade_off

+ [Ask about CLAIM-EN-001 — the IT/OT boundary] { marcus_webb_contacted and not topic_claim001_discussed }
    -> claim_en001

+ [What should we do about the SIS patch?] { sis_tamper_confirmed }
    -> sis_patch_view

+ [Ask about the NIS notification obligation] { not topic_nis_discussed }
    -> nis_obligation

+ [What's the current status?]
    -> current_status

+ [Nothing right now]
    Marcus: Don't take long. If that temperature reading is real, we don't have time to spare.
    #exit_conversation
    -> DONE


// ===========================================
// RDP SESSION CONFIRMED
// ===========================================

=== rdp_session_confirmed ===
#speaker:marcus_webb
~ marcus_rdp_briefed = true

Marcus: c.ellison? That account belongs to a contractor who left eight months ago. That account was supposed to be deprovisioned on their last day.

Marcus: Someone has been sitting in our SCADA network since 01:47 this morning using credentials that shouldn't exist.

Marcus: Right. Here's what you need to do. Listen carefully.

Marcus: First — get back to Battery Hall 1 and press the ESD. Don't wait for further confirmation. If that analog thermometer is right, those cells need to come off the charging circuit now.

Marcus: The ESD code is in the system — you'll have received it. Use it.

Marcus: While you do that, I need someone on the jump server cable in the Engineering Workshop. Pull it. The physical cable. Not a firewall rule — the actual cable.

-> hub


// ===========================================
// ISOLATION TRADE-OFF
// ===========================================

=== isolation_trade_off ===
#speaker:marcus_webb
~ topic_isolation_discussed = true

Marcus: Here's the problem with full network isolation right now.

Marcus: If I kill the SCADA-to-enterprise connection — which means the jump server AND the historian proxy — we lose automated monitoring and control of Racks B1 through C4 as well.

Marcus: Those racks are fine right now. But if something develops while the SCADA server can't communicate, the control system can't respond automatically.

* [What's the safer choice?]
    -> isolation_surgical_approach

* [What if the attacker has a secondary pathway?]
    -> isolation_secondary_concern

* [Should we isolate before or after pressing the ESD?]
    -> isolation_timing

* [What's the worst case if we isolate too early?]
    -> isolation_worst_case


=== isolation_surgical_approach ===
#speaker:marcus_webb

Marcus: Surgical isolation first. Pull the jump server cable — that kills the attacker's primary pathway. Then call Tom at CastleTech to close the enterprise-side connections.

Marcus: If the historian Modbus proxy is also compromised, I'll need to escalate that separately. One problem at a time.

Marcus: The key is the jump server first. That's the active session. Once that's severed, we've interrupted the real-time access the attacker has.

-> hub


=== isolation_secondary_concern ===
#speaker:marcus_webb

Marcus: They probably do. I saw unusual Modbus traffic from the historian server last week — flagged it, didn't action it fast enough.

Marcus: Which is why Tom at CastleTech needs to lock down the enterprise side simultaneously. Belt and braces.

Marcus: The historian is dual-homed — it sits in both the SCADA network and the enterprise network. If the attacker has compromised it, they could be using Modbus commands to manipulate the PLCs directly.

Marcus: That's why we need multiple isolation points. Not just pull one cable and assume we're safe.

#influence_decreased

-> hub


=== isolation_timing ===
#speaker:marcus_webb

Marcus: ESD first. The physical safety hazard takes priority over the network containment.

Marcus: If you isolate the network before pressing ESD, and the cells deteriorate while the SCADA is offline, there's no automated response left. The ESD is the one action that helps regardless of what the attacker does next.

Marcus: The sequence is: (1) press ESD — disconnect cells from the charging circuit; (2) pull the jump server cable — disconnect the attacker; (3) call Tom — isolate enterprise-side.

Marcus: All within about ten minutes. That's the clean response.

-> hub


=== isolation_worst_case ===
#speaker:marcus_webb

Marcus: Let's say we isolate the network first, before pressing the ESD. The SCADA server goes offline.

Marcus: At that moment, Racks B1 through C4 are no longer under automated control. If any of those racks develop a fault — a charge controller failure, a cell problem — the SCADA can't see it and can't respond.

Marcus: The BMS in those racks has local protection, but SCADA coordination is lost. That creates a window of vulnerability that I'd rather not open.

Marcus: But if we press the ESD first — Racks A1 through A4 are already safe, already offline. Then we can isolate the network without that specific concern.

Marcus: The attacker is ejected, and the remaining racks are managed locally until we can bring SCADA back up in a clean state.

-> hub


// ===========================================
// CLAIM-EN-001 — IT/OT BOUNDARY
// ===========================================

=== claim_en001 ===
#speaker:marcus_webb
~ topic_claim001_discussed = true
#set_global:en001_claim_assessed:true

Marcus: I've written this up twice. Quarterly risk reports. Both times the board noted it and moved on.

Marcus: The jump server was set up during commissioning to allow bidirectional RDP. That was supposed to be temporary — to let the vendor configure the SCADA remotely. It was never reverted.

Marcus: The historian has a Modbus proxy that was enabled for vendor support access. Same story. Never removed.

* [Why wasn't it fixed?]
    -> why_not_fixed

* [What should the boundary look like?]
    -> proper_boundary_design

* [Could this have been prevented?]
    -> prevention_discussion


=== why_not_fixed ===
#speaker:marcus_webb

Marcus: Cost and disruption. Reconfiguring the jump server means taking the SCADA offline. The historian proxy is vendor-supported infrastructure — touching it requires a change management process.

Marcus: The risk was real and documented. The organisation chose to accept it rather than pay to fix it. That's the honest answer.

Marcus: I've seen this pattern at every facility I've worked at. A temporary commissioning measure that's never properly decommissioned. A patch that's always "next quarter." A firewall rule that nobody remembers why it exists.

Marcus: And then one day, someone exploits it.

-> hub


=== proper_boundary_design ===
#speaker:marcus_webb

Marcus: The historian should be read-only from the enterprise side with no execution capability. The jump server should be decommissioned or replaced with a one-way data diode for historian replication only.

Marcus: No bidirectional access between enterprise and SCADA. Not temporary, not conditional. No bidirectional access.

Marcus: The SIS engineering port should be completely isolated. Not even on the SCADA network. Air-gapped. Local terminal access only.

Marcus: And any system that bridges IT and OT — the jump server, the historian, the shared file server — should be treated as a perimeter, not as part of either zone.

Marcus: Every connection should be questioned: What is this for? Is it necessary? What could go wrong if it's compromised? And if the answer is "we don't know," then it shouldn't exist.

-> hub


=== prevention_discussion ===
#speaker:marcus_webb

Marcus: Yes. If we'd done the proper boundary segmentation, this attack doesn't work.

Marcus: The attacker gets into enterprise IT — that part probably happens regardless. But from enterprise, they cannot reach the SCADA zone because there's no bidirectional pathway.

Marcus: The jump server doesn't exist. The historian proxy is one-way. The SIS is air-gapped. None of the attack routes we're seeing today would have been available.

Marcus: That was preventable. The cost of prevention was maybe £40,000 and two weeks of downtime. The cost of response is... well, let's see what the debrief says.

Marcus: This is why I keep writing up the risk assessments. Because eventually, someone listens.

-> hub


// ===========================================
// SIS PATCH VIEW
// ===========================================

=== sis_patch_view ===
#speaker:marcus_webb

Marcus: I wrote the risk assessment on that patch eighteen months ago. The vulnerability is an authentication bypass on the SIS engineering port.

Marcus: The compensating control I proposed was OT-inclusive network monitoring. What actually got implemented was a SOC contract that explicitly excludes the OT zone. So the compensating control was ineffective from day one.

* [Was deferral the wrong decision?]
    -> patch_assessment_reflection

* [What exactly is the vulnerability?]
    -> patch_technical_detail

* [What's your recommendation for the debrief?]
    -> marcus_patch_rec

* [Could the patch have prevented this?]
    -> patch_prevention


=== patch_assessment_reflection ===
#speaker:marcus_webb

Marcus: The decision was made on incomplete information — the board didn't understand that the compensating control didn't actually work. That's partly on me for not pushing harder.

Marcus: I should have said: "If you're not going to apply the patch, then we need to actually implement OT-inclusive monitoring. Not just contract with a SOC that excludes OT. That won't protect the safety system."

Marcus: I documented it. But I didn't force the conversation hard enough. That's my failure.

Marcus: Going forward: apply the patch. Spend the £180,000. Eighty-five degrees vs. fifty-five degrees — that's the cost of the deferral, sitting right there in Battery Hall 1.

-> hub


=== patch_technical_detail ===
#speaker:marcus_webb

Marcus: The SIS engineering port has a default credential vulnerability. You can authenticate without a password using a well-known default account.

Marcus: Normally this would be mitigated — change the default credentials, enforce strong auth, apply vendor patches. But the patch that closes this vulnerability has been available and deferred for eighteen months.

Marcus: Someone on the SCADA network found the SIS engineering port, discovered the default credential vulnerability, and used it to modify the thermal runaway setpoint from 55 to 85 degrees.

Marcus: That's not a sophisticated attack. It's a straightforward exploitation of a documented vulnerability that we chose to leave unfixed.

-> hub


=== marcus_patch_rec ===
#speaker:marcus_webb

Marcus: Apply the patch. Accept the recertification cost. And make sure the next risk assessment includes a realistic evaluation of whether the compensating controls actually provide the mitigation they're supposed to provide.

Marcus: Patch deferral is sometimes defensible. But only if the alternatives actually exist and actually work. At Albion, they didn't.

Marcus: The board needs to understand: accepting a risk with non-existent compensating controls is not risk acceptance. It's risk pretence.

-> hub


=== patch_prevention ===
#speaker:marcus_webb

Marcus: Absolutely. The patch closes the authentication bypass. An attacker on the SCADA network could no longer modify SIS setpoints without proper credentials.

Marcus: If we'd applied the patch eighteen months ago, the attacker could still get onto the SCADA network, but they couldn't reach into the SIS. The SIS threshold would have stayed at 55 degrees.

Marcus: That alone would have changed the outcome. The cells would have still heated up, but the SIS would have tripped automatically. No need for a hardwired ESD. The safety system would have worked as designed.

Marcus: Instead, we left it unfixed. And now someone's life — or the life of this facility — depended on an old thermometer and a red button on a wall.

-> hub


// ===========================================
// NIS OBLIGATION
// ===========================================

=== nis_obligation ===
#speaker:marcus_webb
~ topic_nis_discussed = true

Marcus: We're an Operator of Essential Services under NIS Regulations 2018. We have 72 hours from detection to notify NCSC.

Marcus: Detection was approximately 06:28 this morning — when Priya called it in. The clock is running.

Marcus: There's also a potential COMAH notification to HSE. Battery hall thermal runaway is a major accident hazard under COMAH.

* [What about Trent Water?]
    Marcus: Good question. We share a file server with Trent Water. Tom at CastleTech flagged unusual access patterns. If the attacker pivoted to Trent Water's network from that shared server, they need to know.
    Marcus: Trent Water runs SCADA for water treatment and pumping. The cross-sector implications could be significant.
    -> hub

* [What needs to go in the notification?]
    Marcus: Nature of incident, timeline, affected systems, physical consequences, actions taken. The NIS form in the Incident Response folder covers it.
    Marcus: The important thing is timeliness. Late notification is itself a regulatory breach.
    -> hub


// ===========================================
// CURRENT STATUS
// ===========================================

=== current_status ===
#speaker:marcus_webb

{ not esd_activated:
    Marcus: ESD not yet pressed. That's the priority right now. Everything else waits.
    -> hub
}

{ esd_activated and not network_isolated:
    Marcus: Good — ESD is done. Now we need full network isolation. Jump server cable pulled?
    Marcus: Call Tom at CastleTech and get the enterprise side locked down.
    -> hub
}

{ network_isolated:
    Marcus: We're in a contained state. Immediate hazard is managed. Focus shifts to the SIS investigation and NCSC notification.
    -> hub
}
