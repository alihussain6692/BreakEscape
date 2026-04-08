// ===========================================
// NPC: Ravi Anand (IT Security Lead)
// Scenario: Northgate Hospital
// Role: SIEM context; VPN anomaly briefing; issues IT security PIN for dual-auth
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR siem_escalated = false
VAR vpn_anomaly_identified = false
VAR network_isolated = false

VAR itsec_pin = ""

VAR ravi_trust = 0
VAR topic_siem = false
VAR topic_vpn = false
VAR topic_isolation = false
VAR topic_contractor = false
VAR gave_itsec_code = false

// Global reads: siem_escalated, vpn_anomaly_identified, network_isolated, itsec_pin
// Global writes: itsec_authorised

// ===========================================
// FIRST ENCOUNTER
// ===========================================

=== start ===
#speaker:ravi_anand

Ravi: Finally. I've been waiting for someone with authority to act on this.

Ravi: We're thirty minutes into a live ransomware incident and I still don't have sign-off to isolate.

Ravi: The SIEM console is through there — I need you to review the alert stream first.

* [Tell me what you know]
    -> siem_briefing

* [What's blocking the isolation?]
    Ravi: Hospital protocol. Major interventions need dual sign-off — IT security and clinical lead.
    Ravi: David Osei is the clinical safety engineer. You'll need him too.
    -> siem_briefing

* [Let's just isolate now]
    Ravi: I can't authorise that alone. And if I isolate the wrong segment, I take down patient systems.
    Ravi: Please — look at the SIEM data first. Then we decide together.
    -> siem_briefing


// ===========================================
// SIEM BRIEFING
// ===========================================

=== siem_briefing ===
#speaker:ravi_anand
~ topic_siem = true

Ravi: The SIEM is picking up lateral movement — same source IP hitting multiple internal hosts.

Ravi: There's also an authentication anomaly in the VPN logs I flagged thirty minutes ago.

Ravi: Review the console, escalate the criticals, then come back to me.

#complete_task:review_siem_alerts
#unlock_task:investigate_vpn_logs

* [What am I looking for?]
    Ravi: Look for the lateral movement alerts — anything tagged RANSOMWARE-PREP or EXFIL.
    Ravi: And check the auth anomaly — a contractor account logged in from Romania. No MFA.
    -> hub

* [I'll look at it now]
    -> hub


// ===========================================
// VPN ANOMALY BRIEFING
// ===========================================

=== vpn_briefing ===
#speaker:ravi_anand
~ topic_vpn = true

Ravi: The log entry at line 31 — user c.ellison, source IP 185.220.101.47, Romania.

Ravi: C. Ellison is on our contractor list but has no active engagement right now.

Ravi: No MFA challenge was triggered. That's a policy violation and a likely initial access vector.

* [How do we confirm it?]
    Ravi: Run check_anomaly.sh on the VM terminal — pass it the IP and it'll verify against our threat intel.
    ~ topic_contractor = true
    -> hub

* {vpn_anomaly_identified} [We've confirmed the anomaly]
    Ravi: Good. That log entry is your initial access evidence. Keep it — it feeds into the safety case.
    #complete_task:investigate_vpn_logs
    -> hub


// ===========================================
// GIVE IT SECURITY PIN
// ===========================================

=== give_itsec_code ===
#speaker:ravi_anand

{not gave_itsec_code:
    {siem_escalated and vpn_anomaly_identified:
        Ravi: You've done the analysis. You've seen what we're dealing with.
        Ravi: Here's my authorisation code for the dual-auth panel.
        Ravi: IT security side: {itsec_pin}.
        Ravi: Don't share it. And get David Osei's code too — you need both.
        ~ gave_itsec_code = true
        #set_global:itsec_authorised:true
        #complete_task:obtain_itsec_code
        -> hub
    }
    {not siem_escalated:
        Ravi: I'm not handing over authorisation codes until we've properly triaged the SIEM.
        Ravi: Review the console and escalate the criticals first.
        -> hub
    }
    {not vpn_anomaly_identified:
        Ravi: We still haven't confirmed the initial access vector.
        Ravi: Check the VPN logs on the terminal. Run the anomaly check script.
        -> hub
    }
}

{gave_itsec_code:
    Ravi: You have my code. Get David's and use the dual-auth panel.
    -> hub
}


// ===========================================
// POST-ISOLATION
// ===========================================

=== post_isolation ===
#speaker:ravi_anand

Ravi: We're isolated. Lateral movement should stop now.

Ravi: Monitoring segment is on its own VLAN — Sarah's ward should start recovering.

{network_isolated:
    Ravi: This is what CLAIM-HC-001 was designed to prevent. Network segmentation working as intended.
    Ravi: Pity it took a live incident to prove the value.
}

* [What's next?]
    Ravi: Backup restoration. Talk to Helen Carver — she holds the ICO obligations and the backup procedures.
    -> hub

* [How did they get past segmentation?]
    Ravi: The VPN contractor account bypassed it. That's the gap we need to close after recovery.
    -> hub


// ===========================================
// REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:ravi_anand

+ {not topic_siem} [Tell me about the SIEM alerts]
    -> siem_briefing

+ {not topic_vpn or vpn_anomaly_identified} [The VPN anomaly]
    -> vpn_briefing

+ {not topic_isolation} [What does network isolation actually do?]
    ~ topic_isolation = true
    Ravi: We disconnect the ransomware-affected segment from clinical systems and internet.
    Ravi: [Points toward the network diagram in the IT office] Look at the network architecture. Enterprise segment is compromised. We sever the connections to Clinical and Legacy.
    Ravi: Stops the spread. Stops the attacker sending a new payload. Buys us time for recovery.
    Ravi: But it also takes down anything running on that segment — which is why we need dual sign-off from David on the clinical side.
    -> hub

+ {not topic_contractor} [Who is C. Ellison?]
    ~ topic_contractor = true
    Ravi: Connor Ellison — an IT contractor who worked here eighteen months ago.
    Ravi: Account was never deprovisioned. Classic offboarding failure.
    Ravi: The attacker either compromised Ellison, or is using stolen credentials.
    -> hub

+ {siem_escalated and vpn_anomaly_identified and not gave_itsec_code} [I need your authorisation code]
    -> give_itsec_code

+ [Leave conversation]
    Ravi: Keep moving. Clock is ticking.
    #exit_conversation
    -> DONE
