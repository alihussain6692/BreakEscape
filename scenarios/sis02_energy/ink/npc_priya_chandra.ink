// ===========================================
// NPC: Priya Chandra (SCADA Engineer)
// Scenario: Albion Battery Hall Crisis
// Role: Primary guide; walkdown companion; ESD knowledge; SIS expertise
// ===========================================
//
// GLOBALS READ:
//   anomaly_detected, historian_flatline_found, jump_server_confirmed,
//   sis_tamper_confirmed, esd_activated, facility_safe_state
//
// GLOBALS WRITTEN:
//   priya_briefed (set in arrival_briefing and start)
//
// TASKS COMPLETED VIA EVENTMAPPING (not directly):
//   check_hmi_readings, check_thermometer, read_sis_config,
//   find_certification_doc, pull_ethernet_cable, read_incident_folder,
//   complete_nis_form
//
// ===========================================

// Global variables managed by scenario - declared locally and updated by game engine
VAR anomaly_detected = false
VAR historian_flatline_found = false
VAR sis_tamper_confirmed = false
VAR esd_activated = false
VAR facility_safe_state = false

// Local NPC state tracking
VAR priya_briefed = false
VAR topic_walkdown_offered = false
VAR topic_esd_explained = false
VAR topic_sis_explained = false
VAR topic_patch_discussed = false


// ===========================================
// TIMED OPENING CUTSCENE (called by timedConversation)
// ===========================================

=== arrival_briefing ===
#speaker:priya_chandra

Priya: You made good time. I appreciate it.

Priya: I'm Priya Chandra — I run the PLC and SCADA systems here. I came in early for a maintenance window.

Priya: The overnight shift left no incident reports. Readings look entirely normal. But something feels off.

Priya: The night shift technician — Jay Patel — he usually flags anything unusual in the handover notes. Today's notes are just 'uneventful.'

Priya: Jay's been here three years. He never writes 'uneventful' when it actually was.

~ priya_briefed = true
#set_global:priya_briefed:true

-> DONE


// ===========================================
// DEFAULT ENTRY (player walks up to Priya)
// ===========================================

=== start ===
#speaker:priya_chandra

{ not priya_briefed:
    Priya: Oh good — you're here. Let me brief you quickly.
    Priya: I'm Priya Chandra. Something about this morning handover isn't sitting right with me.
    ~ priya_briefed = true
    #set_global:priya_briefed:true
    -> briefing_hub
}

{ priya_briefed and not topic_walkdown_offered:
    Priya: I'd like to do a walkdown of Battery Hall 1 before the maintenance window opens.
    Priya: I have the plant room badge. Shall we go?
    ~ topic_walkdown_offered = true
    -> walkdown_offer
}

{ priya_briefed:
    -> hub
}


// ===========================================
// INITIAL BRIEFING HUB
// ===========================================

=== briefing_hub ===
#speaker:priya_chandra

Priya: Where do you want to start?

* [Tell me about the facility]
    -> facility_overview

* [What does the HMI show?]
    -> hmi_overview

* [How do we get into the battery halls?]
    -> access_explained

* [Let's do the Battery Hall walkdown now]
    -> walkdown_offer

* [I need to read through the Incident Response folder first]
    Priya: Of course — it's on the wall behind you. Take a minute.
    -> hub


=== facility_overview ===
#speaker:priya_chandra

Priya: We have two battery halls — Hall 1 and Hall 2. 220 MWh total. Four racks in each hall.

Priya: The SCADA system monitors and controls everything — temperature, state of charge, charge rate. The SIS sits underneath that and should trip the system if any safety parameter is breached.

Priya: Should. That's the word I keep getting stuck on this morning.

-> briefing_hub


=== hmi_overview ===
#speaker:priya_chandra

Priya: HMI-OPS-01 shows everything you'd expect — Battery Hall 1 sitting at a steady 28 degrees, state of charge at 72 percent, all alarms green.

Priya: That's actually part of what concerns me. These readings show almost no variance overnight. Normally we'd see at least a degree of fluctuation as the cells cycle.

Priya: The historian trend would show that more clearly. Have a look if you want.

-> hub


=== access_explained ===
#speaker:priya_chandra

Priya: Battery Hall 1 requires the plant room RFID badge — I have it here.

Priya: The Engineering Workshop is east of us. Key's in the duty officer desk drawer. That room has the engineering workstation and the jump server rack.

-> hub


// ===========================================
// WALKDOWN OFFER
// ===========================================

=== walkdown_offer ===
#speaker:priya_chandra

Priya: I've got the plant room badge here. Battery Hall 1 is through the north door.

* [Yes — let's go now]
    Priya: Right. Follow me.
    Priya: I'll tell you what to look for on the way.
    -> hub

* [I want to review the historian trend first]
    Priya: That's sensible. I'll be here when you're ready.
    -> hub

* [What should I look for in the battery hall?]
    -> what_to_look_for


=== what_to_look_for ===
#speaker:priya_chandra

Priya: The main thing I want to check is the temperature at Rack A2. The SCADA reading is fine — but that rack ran warmer than the others last month.

Priya: There's an old analog thermometer on the wall near A2. Not networked. I want to compare it against the digital reading.

Priya: If they disagree, that tells us something important.

* [Why specifically compare analog vs digital?]
    -> why_analog_comparison

* [What range should we expect?]
    -> expected_temperature_range

* [Let's go check it now]
    -> hub


=== why_analog_comparison ===
#speaker:priya_chandra

Priya: Because the digital reading is part of the SCADA system — if someone has compromised the system, they can falsify that data.

Priya: An analog thermometer is just a tube of mercury in a glass case. It doesn't have firmware, it doesn't have a network connection. It cannot be hacked remotely.

Priya: It can fail — the mercury can break or get stuck — but if it's physically intact, it shows the truth. That's why I use it as a cross-reference. When digital and analog readings disagree, the analog wins.

Priya: It's not elegant, but it's how you design systems that remain safe even when the digital parts are compromised.

-> hub


=== expected_temperature_range ===
#speaker:priya_chandra

Priya: Under normal charge cycle at this state-of-charge, the cells should be running between 28 and 32 degrees Celsius. Slight variance — not huge swings.

Priya: If the thermometer reads significantly higher than the HMI says — like if HMI says 28 and the thermometer says 40-plus — that's a red flag.

Priya: Lithium cells can undergo thermal runaway above about 55 degrees. The SIS should trip them offline before that happens. But if the SIS has been compromised or isn't working...

* [What happens if we don't catch thermal runaway in time?]
    -> thermal_runaway_explained

* [Is that what you're worried about today?]
    -> priya_intuition

* [Let's look at the thermometer and find out]
    -> hub


=== thermal_runaway_explained ===
#speaker:priya_chandra

Priya: The cells enter a self-sustaining exothermic reaction — they generate heat faster than the cooling system can remove it.

Priya: Once it starts, it's very hard to stop. The temperature ramps exponentially. The cell catches fire, or releases hydrogen gas.

Priya: We have 220 megawatt-hours in two battery halls. If a thermal runaway propagates across Rack A1, that's kilograms of lithium burning in a confined space.

Priya: Which is why we have the SIS — to trip the system and isolate the affected cells before thermal runaway develops.

Priya: And which is why, if I think the SIS might not be working, I want to verify the real temperature before trusting what the SCADA tells me.

-> hub


=== priya_intuition ===
#speaker:priya_chandra

Priya: Probably not. This facility has been running smoothly for two years. Overnight shift was uneventful — no alarms, no anomalies.

Priya: But Jay Patel never writes 'uneventful.' And the historian trend shows absolutely no variance — exactly the same reading for hours. That's not normal.

Priya: I've learned to trust my gut when the data is too clean. Perfect readings usually mean something is hiding underneath.

Priya: Could be nothing. But I want to know.

-> hub


// ===========================================
// MAIN REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:priya_chandra

+ [Ask about the analog thermometer discrepancy] { anomaly_detected }
    -> thermometer_discrepancy

+ [Ask about the historian flat-line reading] { historian_flatline_found }
    -> historian_anomaly

+ [Ask about the SIS configuration] { sis_tamper_confirmed }
    -> sis_compromise_discussion

+ [Ask about the hardwired ESD] { not topic_esd_explained }
    -> esd_explanation

+ [Ask about the SIS patch situation] { sis_tamper_confirmed and not topic_patch_discussed }
    -> patch_situation

+ [Ask about next steps]
    -> next_steps

+ [Nothing right now]
    Priya: I'll be here. Don't take too long — if my instincts are right, time matters.
    #exit_conversation
    -> DONE


// ===========================================
// ANOMALY DETECTION BRANCH
// ===========================================

=== thermometer_discrepancy ===
#speaker:priya_chandra

Priya: Fifty-one degrees. The HMI says twenty-eight.

Priya: I've been in this industry long enough to know what that means. One of those readings is a lie.

Priya: The analog thermometer was calibrated six months ago. It has no network connection. It cannot be falsified remotely.

* [So the SCADA reading is wrong?]
    Priya: If the physical thermometer is correct, then yes. Something is feeding the SCADA system false data.
    Priya: That thermometer is the most important object in this building right now, because it is the only reading that cannot be compromised.
    -> hub

* [Could the thermometer itself be faulty?]
    Priya: It's possible. But if I had to choose between trusting a networked digital system and a certified analog gauge, and those readings disagree by twenty-three degrees — I trust the gauge.
    Priya: The digital system has more failure modes. Including deliberate manipulation.
    -> hub

* [What do we do with this information?]
    Priya: We need to verify it — check the historian trend data, look at the access logs. And we need to seriously consider pressing the ESD before this escalates further.
    -> hub


// ===========================================
// HISTORIAN ANOMALY BRANCH
// ===========================================

=== historian_anomaly ===
#speaker:priya_chandra

Priya: Three hours of exactly twenty-eight point zero. Not twenty-seven point nine, not twenty-eight point one. Exactly twenty-eight.

Priya: Real sensor data has noise. Electrical interference, measurement jitter, thermal fluctuation. A perfectly flat line for three hours means the data is synthetic.

Priya: Someone wrote a value to the sensor feed and held it there. This is not a sensor failure. This is deliberate falsification.

* [How long has this been going on?]
    Priya: The flat-line starts at 23:12 last night. That's when the real reading was replaced.
    Priya: Which means Battery Hall 1 has been operating without meaningful temperature monitoring for over seven hours.
    -> hub

* [Is Marcus Webb the right person to call?]
    Priya: Yes. Marcus is OT Security. He's been trying to get the IT/OT boundary sorted for eighteen months. He'll know what to do.
    -> hub


// ===========================================
// ESD EXPLANATION
// ===========================================

=== esd_explanation ===
#speaker:priya_chandra
~ topic_esd_explained = true

Priya: The hardwired ESD is a red mushroom-head button on the wall in Battery Hall 1, near Rack A2.

Priya: It is a physical electrical interlock. When you press it, it breaks the charging circuit for Racks A1 through A4. Immediately. No SCADA involved, no SIS firmware, no network command.

Priya: It cannot be disabled remotely. It cannot be falsified. A cyber attack cannot prevent a hardwired circuit from opening.

* [How does it work exactly?]
    -> esd_technical_detail

* [Why do we need it if we have the SIS?]
    -> why_independent_esd

* [Should we press it now?]
    Priya: That's what Marcus needs to confirm. The ESD is irreversible without a manual reset — pressing it without proper authority creates its own complications.
    Priya: But if the cells are at fifty-one degrees and rising with a compromised SIS, the answer may well be yes.
    -> hub


=== esd_technical_detail ===
#speaker:priya_chandra

Priya: It's a direct relay. Power flows through a normally-closed switch. Press the button — circuit opens — racks disconnect. The software doesn't get a vote.

Priya: That's the point. The hardwired ESD exists precisely because we cannot trust that the programmable safety layers will always work.

Priya: The beauty of a hardwired circuit is that there's no attack surface. No firmware to patch, no network port to access, no credentials to steal.

Priya: It's dumb and simple. Which in safety engineering is actually a feature, not a limitation.

* [What's the physical consequence of pressing it?]
    -> esd_consequence

* [Can it be reset?]
    -> esd_reset

* [Let's move on]
    -> hub


=== esd_consequence ===
#speaker:priya_chandra

Priya: The charging circuit to Racks A1 through A4 breaks. They're instantly disconnected from the main power feed.

Priya: The battery management systems go into a safe state — no charging, no discharging, just cooling until the cells stabilise.

Priya: The facility loses about 100 megawatts of stored energy in those four racks. There are contract penalties for an unplanned shutdown.

Priya: But a lost contract penalty is better than a battery hall fire.

-> hub


=== esd_reset ===
#speaker:priya_chandra

Priya: It has to be done manually — someone walks into Battery Hall 1, finds the button housing, pops out the mechanical reset pin, and reinstalls the button.

Priya: It's deliberate. You can't accidental recover from an ESD just by power-cycling the system. The reset requires physical presence and commitment.

Priya: That's a design choice. It forces deliberation. If you press the ESD, you know exactly what you've done and you take responsibility for the consequences.

-> hub


=== why_independent_esd ===
#speaker:priya_chandra

Priya: Because the SIS is software. It has firmware, processors, firmware updates. And all of that — in principle — can be compromised.

Priya: If the SIS fails, we need a safety function that cannot fail in the same way. That means it has to be fundamentally independent — a different kind of thing.

Priya: A hardwired circuit is about as far from software as you can get. No firmware, no networking, no complexity. Just relay contacts and wiring.

Priya: It's not elegant. But it's the reason we can still survive even if every digital system in this building has been compromised.

Priya: That's defence in depth. You don't put all your safety eggs in one digital basket.

-> hub


// ===========================================
// SIS COMPROMISE DISCUSSION
// ===========================================

=== sis_compromise_discussion ===
#speaker:priya_chandra
~ topic_sis_explained = true

Priya: Eighty-five degrees. The SIS thermal runaway threshold has been raised from fifty-five to eighty-five.

Priya: That means the automated safety function won't trip until the cells are already in irreversible failure. The protection we thought was there — isn't.

* [How did they get into the SIS?]
    -> sis_engineering_port

* [What are the consequences?]
    -> sis_compromise_consequences

* [How do we know it's been modified?]
    -> sis_audit_trail


=== sis_engineering_port ===
#speaker:priya_chandra

Priya: The SIS has an engineering port for configuration and maintenance. That port should be isolated — but it's reachable from the SCADA network.

Priya: If someone can get onto the SCADA network, they can reach the SIS engineering interface. Which means the SIS isn't independent. It's connected.

Priya: IEC 61511 requires SIS logical isolation from the control system for exactly this reason.

* [Why is the engineering port connected to SCADA?]
    -> engineering_port_history

* [What should the architecture look like?]
    -> sis_isolation_design

* [Back to the main discussion]
    #set_global:en002_claim_assessed:true
    -> hub


=== engineering_port_history ===
#speaker:priya_chandra

Priya: During commissioning, the SIS vendor needed remote access to configure the safety settings. So we connected the engineering port to the SCADA network with a temporary firewall rule.

Priya: That was supposed to be temporary — removed once commissioning was finished. But 'temporary' became permanent.

Priya: Now, anyone on the SCADA network who knows the access point can reach the SIS and potentially modify setpoints. Marcus flagged this eighteen months ago. The board decided to accept the risk rather than pay for a reconfiguration.

Priya: That decision was made on the assumption that the SCADA network couldn't be compromised. Which turned out to be a bad assumption.

#set_global:en002_claim_assessed:true
-> hub


=== sis_isolation_design ===
#speaker:priya_chandra

Priya: The SIS should be on its own isolated network. Not connected to SCADA. Not connected to enterprise IT. No network at all, ideally.

Priya: Engineering access to the SIS should happen at a physical console — an air-gapped terminal in a restricted room. You plug in a portable device, make your changes, verify them, then disconnect.

Priya: That way, even if the entire SCADA network is compromised, the SIS stays clean.

Priya: We didn't do that because it's operationally inconvenient and it costs money. So we left the engineering port on the SCADA network and hoped nobody would exploit it.

Priya: Someone did.

#set_global:en002_claim_assessed:true
-> hub


=== sis_compromise_consequences ===
#speaker:priya_chandra

Priya: The SIS was our last automated safety backstop. Without it, the only safety function remaining is the hardwired ESD — which is independent, but requires someone to physically go and press it.

Priya: Everything else — the BMS overcharge protection, the cell temperature alarm, the thermal runaway trip — all of those are compromised.

Priya: If the cells do start to go into thermal runaway, there's no automated protection. It's all on the ESD button.

* [That sounds intentional — like they wanted to disable the safeguards]
    -> attacker_intent

* [What about alarms — shouldn't we still see some warning?]
    -> alarm_theory

* [Back to the main discussion]
    -> hub


=== attacker_intent ===
#speaker:priya_chandra

Priya: That's one theory. Another is that they wanted to keep the system running — raise the threshold to prevent any automated shutdowns that would interrupt their access.

Priya: Either way, the result is the same. The safety system that's supposed to protect the facility is no longer protecting it.

Priya: Which is why that analog thermometer in Battery Hall 1 is now the most important instrument in this facility.

-> hub


=== alarm_theory ===
#speaker:priya_chandra

Priya: In theory, yes. The alarm panel in the control room should show something — high temperature warning, SIS deviation alert, something.

Priya: But if the HMI is also compromised — if they're feeding the alarm system false data the same way they're feeding false temperature readings — then the alarm system will also look normal.

Priya: This is why we don't rely only on digital alarms. We have the physical thermometer, we have the hydrogen detector, we have trained operators who know what normal looks like.

Priya: I'm trained to notice when everything looks too perfect. And this morning, everything looked too perfect.

-> hub


=== sis_audit_trail ===
#speaker:priya_chandra

Priya: The SIS has an audit log. Every configuration change is recorded — who made it, when, what was changed.

Priya: The log shows that the threshold was modified at 03:22 this morning by an administrative account. Account name is in the engineering workstation logs if you look.

Priya: The question is: who was authorised to make that change? The answer is: nobody who actually has that access level.

Priya: So either the credentials were stolen, or the account is compromised. Either way, it's unauthorised access.

#set_global:en002_claim_assessed:true
-> hub


// ===========================================
// PATCH SITUATION
// ===========================================

=== patch_situation ===
#speaker:priya_chandra
~ topic_patch_discussed = true

Priya: The patch was available eighteen months ago. It fixes the authentication bypass on the SIS engineering port — the exact vulnerability that was used to change those setpoints.

Priya: We deferred it because applying it requires recertification under IEC 61511. Eight weeks offline. £180,000. The board said no.

* [Was the deferral the right call?]
    -> patch_defensibility

* [What would applying the patch change?]
    -> patch_technical_detail

* [Why does recertification cost so much?]
    -> recertification_explained

* [What would you recommend now?]
    -> priya_patch_recommendation


=== patch_defensibility ===
#speaker:priya_chandra

Priya: I think about that. The risk was real — documented in Marcus's risk assessment. But it felt manageable at the time.

Priya: Now? With a battery hall approaching thermal runaway because someone exploited exactly that vulnerability?

Priya: It wasn't defensible. We accepted a documented risk with a compensating control that wasn't actually in place. That's the mistake.

Priya: The question for the debrief is: what's the right approach going forward? Apply the patch and accept the recertification cost? Or maintain deferral with genuinely effective compensating controls that actually exist and actually work?

-> hub


=== patch_technical_detail ===
#speaker:priya_chandra

Priya: It would close the authentication bypass on the SIS engineering port. An attacker on the SCADA network could no longer modify SIS setpoints without proper credentials.

Priya: But we'd need to re-run the full SIL 2 safety case — verify that the patched firmware meets the functional safety requirements. That's the eight weeks and £180,000.

Priya: The patch itself is maybe two hours of work. The recertification is the burden. We have to prove to a third-party auditor that the patched firmware still meets all the safety requirements of the original design.

Priya: That's not bureaucracy — it's actually important. You don't want to patch a safety system and accidentally break some critical function.

-> hub


=== recertification_explained ===
#speaker:priya_chandra

Priya: Because you can't just patch the firmware in a SIL 2 system without independent verification.

Priya: The SIS has a certified safety case — a formal document that says "this configuration of hardware and firmware will reliably prevent thermal runaway within this operational envelope."

Priya: If you change the firmware, you've changed the subject of the certification. So you have to certify it all over again.

Priya: That means hiring a third-party SIL 2 auditor, running through all the verification tests, doing a full safety analysis on the patched code, getting sign-off.

Priya: It's expensive and time-consuming because the safety function has to be proven to work correctly before we go live. You can't just patch and hope.

* [How long has the patch been available?]
    Priya: Eighteen months. Long enough that the board should have made a decision one way or the other. Instead we just kept deferring.
    -> hub

* [Is the risk documented anywhere?]
    Priya: Yes — Marcus's risk assessment. The vulnerability, the mitigation options, the compensating controls. All documented. All reviewed. And then all filed away.
    -> hub


=== priya_patch_recommendation ===
#speaker:priya_chandra

Priya: Apply the patch and do the recertification. I would have recommended that six months ago.

Priya: The alternative — deferral with compensating controls — only works if the compensating controls actually exist and actually work. At Albion, they don't.

Priya: The compensating control was OT-inclusive network monitoring. We tried to implement it through the CastleTech contract. But their contract explicitly excluded OT. So the compensating control was never there.

Priya: That's a business decision that looked okay on a spreadsheet but created a real safety gap.

Priya: Now we're paying the cost of that gap. The recertification cost looks small in comparison.

-> hub


// ===========================================
// NEXT STEPS
// ===========================================

=== next_steps ===
#speaker:priya_chandra

{ not esd_activated:
    Priya: Priority one is the ESD. If those cells are at fifty-one degrees with a compromised SIS, we need to disconnect them from the charging circuit now.
    Priya: Marcus has the authority to direct that. Have you called him yet?
    -> hub
}

{ esd_activated and not facility_safe_state:
    Priya: Good — ESD is done. The racks are cooling.
    Priya: Now we need to isolate the attacker, understand the full scope of what they changed, and get the notification to NCSC.
    -> hub
}

{ facility_safe_state:
    Priya: We're in a safe state now. The immediate hazard is contained.
    Priya: Dr Bashir from NCSC and HSE has arrived for the post-incident review. I'd suggest talking to her.
    -> hub
}
