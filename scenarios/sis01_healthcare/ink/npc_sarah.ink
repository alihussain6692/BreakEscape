// ===========================================
// NPC: Sarah Mitchell (Charge Nurse)
// Scenario: Northgate Hospital
// Role: Initial briefer; escalation gatekeeper for Bed 4 patient
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR bed4_escalated = false
VAR network_isolated = false
VAR drug_library_compromised = false
VAR drug_library_restored = false

// Local tracking vars for this NPC
VAR sarah_briefed = false
VAR bed4_raised = false
VAR topic_ransomware = false
VAR topic_network = false
VAR topic_pumps = false

// ===========================================
// TIMED OPENING CUTSCENE (called by timedConversation)
// ===========================================

=== arrival_briefing ===
#speaker:sarah_mitchell

Sarah: Listen up — I know this is a lot to take in.

Sarah: Our monitoring station went down forty minutes ago. Ward is running on paper.

Sarah: I've got two nurses covering six beds and no automated alarms. Someone needs to fix this now.

~ sarah_briefed = true

-> DONE


// ===========================================
// DEFAULT ENTRY POINT (player walks up to Sarah)
// ===========================================

=== start ===
#speaker:sarah_mitchell

{not sarah_briefed:
    Sarah: Are you from IT? Please tell me you're here to help.
    Sarah: The whole monitoring station is locked up — some kind of ransom screen.
    ~ sarah_briefed = true
    -> briefing_hub
}

{sarah_briefed and not bed4_raised:
    Sarah: I need you to look at the situation with Bed 4.
    Sarah: Mrs Fletcher has been restless for the last hour. Without the monitor I can't verify her sats.
    -> bed4_concern
}

{bed4_raised:
    -> hub
}


// ===========================================
// BED 4 CONCERN
// ===========================================

=== bed4_concern ===
#speaker:sarah_mitchell
~ bed4_raised = true

Sarah: Mrs Fletcher in Bed 4 — post-op cardiac, day two.

Sarah: Under normal conditions she'd be on continuous monitoring.

Sarah: With the station down I have no O2 sat, no BP trace. Just spot checks.

* [What are her current observations?]
    Sarah: Last manual set fifteen minutes ago — sats 94%, slightly low but not critical yet.
    Sarah: Trend concerns me though. She's had two periods of agitation. Could be pain, could be hypoxia.
    -> bed4_options

* [How long has this been going on?]
    Sarah: Since the attack hit. Just under an hour without continuous monitoring.
    Sarah: Every minute counts with post-op cardiac. This needs escalating.
    -> bed4_options

* [I'll get to her after IT is sorted]
    Sarah: There may not be time for "after." This patient is at risk *right now*.
    #influence_decreased
    -> bed4_options


=== bed4_options ===
#speaker:sarah_mitchell

Sarah: I need you to flag this to the duty registrar and get a manual check done immediately.

* [I'll escalate it now]
    #complete_task:escalate_bed4
    #set_global:bed4_escalated:true
    Sarah: Thank you. I'll get the registrar to do a bedside review.
    -> hub

* [Can't your nursing staff handle it?]
    Sarah: We're at minimum safe staffing. I'm the only registered nurse on this bay right now.
    Sarah: If you don't escalate, I have to, and that means leaving the ward station unattended.
    -> bed4_options

* [I'll look into it later]
    Sarah: I hope "later" isn't too late.
    #influence_decreased
    -> hub


=== escalate_bed4 ===
#speaker:sarah_mitchell

Sarah: You escalated. Good call.

{bed4_escalated:
    Sarah: Dr Hassan is with Mrs Fletcher now. We caught it early.
    Sarah: This is exactly why monitoring continuity matters — cyber incident or not.
    -> hub
}

-> hub


// ===========================================
// POST-ISOLATION REACTION
// ===========================================

=== post_isolation ===
#speaker:sarah_mitchell

Sarah: Network's isolated? Does that mean the monitoring station might come back?

Sarah: Even a partial recovery would help. My team are exhausted running manual checks.

* [We're working on restoration]
    Sarah: Thank you. Please hurry — we can't sustain this workload indefinitely.
    -> hub

* [It may take a while yet]
    Sarah: Understood. I'll keep the manual rounds going. Just keep us in the loop.
    -> hub


// ===========================================
// POST DRUG TAMPER DISCOVERY
// ===========================================

=== post_drug_tamper ===
#speaker:sarah_mitchell

Sarah: The drug library was tampered with?

Sarah: I need to suspend all pump-administered medication until that library is verified.

Sarah: This is a clinical safety incident. I'm alerting the on-call pharmacist right now.

#complete_task:notify_clinical_staff
#set_global:clinical_staff_notified:true

* [What medications are at risk?]
    Sarah: Any drug administered via the Alaris pumps — morphine, heparin, insulin.
    Sarah: If the dose limits were changed, a nurse could administer a fatal overdose without a warning.
    -> hub

* [The correct library is being restored]
    Sarah: That's a relief. But I want written confirmation before any pump is restarted.
    Sarah: Patient safety has to come first, even if that means delays.
    -> hub


// ===========================================
// REPEATABLE HUB
// ===========================================

=== briefing_hub ===
#speaker:sarah_mitchell

Sarah: We've had no monitoring for nearly an hour. IT security are in the office down the hall.

Sarah: Ravi Anand — he's the one who called in the cyber incident. Talk to him first.

-> hub

=== hub ===
#speaker:sarah_mitchell

+ {not topic_ransomware} [What exactly happened to the monitoring station?]
    ~ topic_ransomware = true
    Sarah: Someone's locked our workstation with ransomware. Demanding over a million pounds.
    Sarah: The screen says seventy-two hours. But we can't run a cardiac ward blind for seventy-two minutes.
    -> hub

+ {not topic_network} [Is this affecting anything else?]
    ~ topic_network = true
    Sarah: The ward printer is also down. Some of the bedside tablets can't reach the EPR.
    Sarah: It's spreading, or maybe it was always bigger than just this room.
    -> hub

+ {not topic_pumps} [What about the infusion pumps?]
    ~ topic_pumps = true
    Sarah: The smart pumps are standalone — they run on their own network segment.
    Sarah: But their drug library is pulled from the central server. If that's compromised...
    Sarah: I don't want to think about it.
    -> hub

+ [Leave conversation]
    Sarah: Please be quick. Every minute without monitoring is a minute I'm flying blind.
    #exit_conversation
    -> DONE
