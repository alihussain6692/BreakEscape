import { MinigameScene } from '../framework/base-minigame.js';

/**
 * MG-04 — Network Segmentation Map
 *
 * Behaviour (healthcare-aligned implementation):
 *  - Renders FOUR-zone network topology: External, Enterprise IT, Clinical/Device, Legacy flat segment
 *  - Uses canonical system names from case_1_healthcare_information_pack/system_architecture/network_architecture.md
 *  - Renders toggle controls for the three legacy exception rules
 *  - Shows rule-specific consequences and attack-path overlays when toggled
 *  - Gates SEVER until the first rule interaction
 *  - SEVER writes `network_isolated = true` and shows post-sever visual state
 *  - Detects prior isolation and displays severed state if reopened
 */
export class NetworkSegmentationMapMinigame extends MinigameScene {
    constructor(container, params) {
        params = params || {};
        super(container, params);
        this.severed = false;
        this.rulesReviewedSet = false; // track if we've written network_rules_reviewed
        this.ruleStates = {
            rule1: false, // Ward 5 dual-homed
            rule2: false, // Ward 7 domain join
            rule3: false  // Fleet management access
        };
        this._resizeHandler = null;
    }

    init() {
        // Check prior isolation state
        if (window.gameState?.globalVariables?.network_isolated === true) {
            this.severed = true;
        }

        // Full custom layout — does not call super.init() so we own the entire container.
        this.container.innerHTML = `
            <button type="button" class="minigame-close-button" id="nsm-close">&times;</button>
            <div class="nsm-wrapper">
                <div class="nsm-header-bar">
                    <span class="nsm-title-text">NORTHGATE TRUST // NETWORK SEGMENTATION MAP</span>
                    <span class="nsm-status-badge">ACTIVE INCIDENT</span>
                </div>
                <div class="nsm-body">
                    <div class="nsm-topology-area" id="nsm-topology-area">
                        <div class="nsm-zones">
                            <div class="nsm-zone nsm-zone-external" id="nsm-zone-external">
                                <div class="nsm-zone-label">EXTERNAL ZONE</div>
                                <div class="nsm-zone-devices">
                                    <div class="nsm-device">Internet</div>
                                    <div class="nsm-device">NHS HSCN Network</div>
                                    <div class="nsm-device">Vendor Remote Access</div>
                                </div>
                            </div>
                            <div class="nsm-zone nsm-zone-enterprise" id="nsm-zone-enterprise">
                                <div class="nsm-zone-label">ENTERPRISE IT ZONE</div>
                                <div class="nsm-zone-devices">
                                    <div class="nsm-device">Active Directory</div>
                                    <div class="nsm-device">Email Server</div>
                                    <div class="nsm-device">Electronic Health Records</div>
                                    <div class="nsm-device">File Servers</div>
                                    <div class="nsm-device">Admin Workstations</div>
                                    <div class="nsm-device">Backup Infrastructure</div>
                                    <div class="nsm-device">SIEM</div>
                                </div>
                            </div>
                            <div class="nsm-zone nsm-zone-clinical" id="nsm-zone-clinical">
                                <div class="nsm-zone-label">CLINICAL / DEVICE ZONE</div>
                                <div class="nsm-zone-devices">
                                    <div class="nsm-device">Infusion Pump Fleet Manager</div>
                                    <div class="nsm-device">Patient Monitors (480 units)</div>
                                    <div class="nsm-device">Bedside Monitors (320)</div>
                                    <div class="nsm-device">Ventilators (60)</div>
                                    <div class="nsm-device">PACS Server</div>
                                    <div class="nsm-device">Imaging Modalities</div>
                                </div>
                            </div>
                            <div class="nsm-zone nsm-zone-legacy" id="nsm-zone-legacy">
                                <div class="nsm-zone-label">LEGACY FLAT SEGMENT</div>
                                <div class="nsm-zone-devices">
                                    <div class="nsm-device">Patient Monitors (Legacy)</div>
                                    <div class="nsm-device">Ward Workstations</div>
                                    <div class="nsm-device">Infusion Pumps (Legacy)</div>
                                </div>
                            </div>
                        </div>
                        <svg class="nsm-svg" id="nsm-svg" xmlns="http://www.w3.org/2000/svg"></svg>
                    </div>
                    <div class="nsm-consequence-panel">
                        <div class="nsm-panel-title">CONSEQUENCE ASSESSMENT</div>
                        <div class="nsm-consequence-body" id="nsm-consequence-body"></div>
                    </div>
                </div>
                <div class="nsm-action-bar">
                    <div class="nsm-legend">
                        <span class="nsm-legend-item">
                            <span class="nsm-legend-line nsm-legend-white"></span>PERIMETER FIREWALL
                        </span>
                        <span class="nsm-legend-item">
                            <span class="nsm-legend-line nsm-legend-amber"></span>INTERNAL FIREWALL
                        </span>
                        <span class="nsm-legend-item">
                            <span class="nsm-legend-line nsm-legend-orange nsm-legend-dashed"></span>LEGACY EXCEPTION RULES
                        </span>
                    </div>
                    <button type="button" class="nsm-sever-btn" id="nsm-sever-btn" disabled>
                        SEVER ENTERPRISE &#x2192; CLINICAL LINK
                    </button>
                </div>
            </div>
            <div class="nsm-modal-overlay" id="nsm-modal-overlay">
                <div class="nsm-modal">
                    <div class="nsm-modal-icon">&#9888;</div>
                    <div class="nsm-modal-title">CONFIRM NETWORK ISOLATION</div>
                    <div class="nsm-modal-body">
                        This will disconnect all clinical zone systems from the enterprise network.
                        <br/><br/>
                        <strong>CLINICAL CONSEQUENCES:</strong>
                        <br/>• EHR offline → paper-based prescribing
                        <br/>• Fleet console offline → manual bedside pump entry
                        <br/>• Backup access blocked → recovery delayed
                        <br/><br/>
                        Confirm isolation?
                    </div>
                    <div class="nsm-modal-actions">
                        <button type="button" class="nsm-modal-btn nsm-modal-no" id="nsm-modal-no">NO — CANCEL</button>
                        <button type="button" class="nsm-modal-btn nsm-modal-yes" id="nsm-modal-yes">YES — SEVER LINK</button>
                    </div>
                </div>
            </div>
        `;

        this._updateConsequencePanel();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    start() {
        super.start(); // sets up ESC-to-close handler

        this.addEventListener(this.container.querySelector('#nsm-close'), 'click',
            (event) => {
                event.preventDefault();
                event.stopPropagation();
                this.complete(false);
            });
        this.addEventListener(this.container.querySelector('#nsm-sever-btn'), 'click',
            (event) => {
                event.preventDefault();
                event.stopPropagation();
                this._openModal();
            });
        this.addEventListener(this.container.querySelector('#nsm-modal-yes'), 'click',
            (event) => {
                event.preventDefault();
                event.stopPropagation();
                this._confirmSever();
            });
        this.addEventListener(this.container.querySelector('#nsm-modal-no'), 'click',
            (event) => {
                event.preventDefault();
                event.stopPropagation();
                this._closeModal();
            });

        // Check if prior isolation and disable SEVER button if already severed
        if (this.severed) {
            const btn = this.container.querySelector('#nsm-sever-btn');
            if (btn) {
                btn.disabled = true;
                btn.textContent = 'LINK ALREADY SEVERED';
                btn.classList.add('nsm-sever-btn-done');
            }
        }

        this._resizeHandler = () => this._drawConnections();
        window.addEventListener('resize', this._resizeHandler);

        // Draw after the browser has laid out the zones
        requestAnimationFrame(() => this._drawConnections());
    }

    cleanup() {
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
            this._resizeHandler = null;
        }
        super.cleanup();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Modal
    // ─────────────────────────────────────────────────────────────────────────

    _openModal() {
        this.container.querySelector('#nsm-modal-overlay').classList.add('nsm-modal-visible');
        if (window.playUISound) window.playUISound('alert');
    }

    _closeModal() {
        this.container.querySelector('#nsm-modal-overlay').classList.remove('nsm-modal-visible');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SEVER action
    // ─────────────────────────────────────────────────────────────────────────

    _confirmSever() {
        this.severed = true;
        this._closeModal();

        // Write global state — downstream logic drives EHR/fleet-console transitions
        if (window.npcManager && window.npcManager.setGlobalVariable) {
            window.npcManager.setGlobalVariable('network_isolated', true);
        } else if (window.gameState?.globalVariables) {
            // Fallback: write directly and emit the change event
            window.gameState.globalVariables['network_isolated'] = true;
            if (window.eventDispatcher) {
                window.eventDispatcher.emit('global_variable_changed:network_isolated', {
                    name: 'network_isolated', value: true, oldValue: false
                });
            }
        }

        this._drawConnections();
        this._updateConsequencePanel();

        const btn = this.container.querySelector('#nsm-sever-btn');
        if (btn) {
            btn.disabled = true;
            btn.textContent = 'LINK SEVERED';
            btn.classList.add('nsm-sever-btn-done');
        }

        if (window.playUISound) window.playUISound('confirm');

        setTimeout(() => this.complete(true), 2000);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Rule toggle interaction
    // ─────────────────────────────────────────────────────────────────────────

    _toggleRule(ruleId) {
        // Gate SEVER button on first interaction
        if (!this.rulesReviewedSet) {
            this.rulesReviewedSet = true;
            if (window.npcManager && window.npcManager.setGlobalVariable) {
                window.npcManager.setGlobalVariable('network_rules_reviewed', true);
            } else if (window.gameState?.globalVariables) {
                window.gameState.globalVariables['network_rules_reviewed'] = true;
                if (window.eventDispatcher) {
                    window.eventDispatcher.emit('global_variable_changed:network_rules_reviewed', {
                        name: 'network_rules_reviewed', value: true, oldValue: false
                    });
                }
            }
            // Enable SEVER button
            const btn = this.container.querySelector('#nsm-sever-btn');
            if (btn && !this.severed) {
                btn.disabled = false;
            }
        }

        // Toggle rule state
        this.ruleStates[ruleId] = !this.ruleStates[ruleId];

        // Redraw with attack paths
        this._drawConnections();
        this._updateConsequencePanel();

        if (window.playUISound) window.playUISound('toggle');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Reactive consequence panel
    // ─────────────────────────────────────────────────────────────────────────

    _updateConsequencePanel() {
        const body = this.container.querySelector('#nsm-consequence-body');
        if (!body) return;

        if (this.severed) {
            body.innerHTML = `
                <div class="nsm-cons-severed">NETWORK ISOLATED</div>
                <ul class="nsm-cons-list">
                    <li class="nsm-cons-item nsm-impact-high">EHR OFFLINE — wards on paper records</li>
                    <li class="nsm-cons-item nsm-impact-high">FLEET CONSOLE OFFLINE — manual operation required</li>
                    <li class="nsm-cons-item nsm-impact-positive">Enterprise-to-clinical link SEVERED</li>
                    <li class="nsm-cons-item nsm-impact-positive">Attacker propagation route blocked</li>
                </ul>
            `;
            return;
        }

        let html = '';

        // Header
        if (!this.rulesReviewedSet) {
            html += `
                <div class="nsm-cons-intro">
                    <span class="nsm-warn-text">3 legacy exception rules</span>
                    currently bridge enterprise and clinical zones.
                    <br/><br/>
                    Review the highlighted risk paths before deciding whether to isolate the link.
                </div>
            `;
        }

        // Per-rule consequences
        if (this.ruleStates.rule1) {
            html += `
                <div class="nsm-cons-rule">
                    <div class="nsm-cons-rule-title">▪ Ward 5 Dual-Homed Workstations</div>
                    <ul class="nsm-cons-list">
                        <li class="nsm-cons-item nsm-impact-high">Ward 5 clinical workstations lose EHR access</li>
                        <li class="nsm-cons-item nsm-impact-high">Prescriptions must be transcribed to paper</li>
                        <li class="nsm-cons-item nsm-impact-med">Manual entry increases medication error risk</li>
                        <li class="nsm-cons-item nsm-impact-positive nsm-attack-path">
                            <strong>ATTACK VECTOR:</strong> Compromised enterprise account → dual-homed bridge → clinical zone devices
                        </li>
                    </ul>
                </div>
            `;
        }

        if (this.ruleStates.rule2) {
            html += `
                <div class="nsm-cons-rule">
                    <div class="nsm-cons-rule-title">▪ Ward 7 Enterprise Domain Join</div>
                    <ul class="nsm-cons-list">
                        <li class="nsm-cons-item nsm-impact-high">Ward 7 nursing station cannot authenticate to enterprise</li>
                        <li class="nsm-cons-item nsm-impact-high">Loss of email and file server access</li>
                        <li class="nsm-cons-item nsm-impact-med">Clinical staff cannot access shift schedules during outage</li>
                        <li class="nsm-cons-item nsm-impact-positive nsm-attack-path">
                            <strong>ATTACK VECTOR:</strong> Enterprise AD compromise → bidirectional domain link → Ward 7 systems
                        </li>
                    </ul>
                </div>
            `;
        }

        if (this.ruleStates.rule3) {
            html += `
                <div class="nsm-cons-rule">
                    <div class="nsm-cons-rule-title">▪ Fleet Management Admin Access</div>
                    <ul class="nsm-cons-list">
                        <li class="nsm-cons-item nsm-impact-high">Infusion pump fleet console reverts to bedside manual entry</li>
                        <li class="nsm-cons-item nsm-impact-high">Drug library updates unavailable</li>
                        <li class="nsm-cons-item nsm-impact-med">All dose programming becomes manual operation risk</li>
                        <li class="nsm-cons-item nsm-impact-positive nsm-attack-path">
                            <strong>ATTACK VECTOR:</strong> Compromised admin workstation → permitted firewall rule → fleet management console
                        </li>
                    </ul>
                </div>
            `;
        }

        // Generic consequence if no rules toggled yet
        if (!this.ruleStates.rule1 && !this.ruleStates.rule2 && !this.ruleStates.rule3) {
            html += `
                <div class="nsm-cons-section">IF SEVER IS CONFIRMED:</div>
                <ul class="nsm-cons-list">
                    <li class="nsm-cons-item nsm-impact-high">EHR access lost on affected wards — prescribing reverts to paper</li>
                    <li class="nsm-cons-item nsm-impact-high">Fleet management console offline — manual bedside dose entry required</li>
                    <li class="nsm-cons-item nsm-impact-med">Clinical workstation remote management unavailable</li>
                </ul>
                <div class="nsm-cons-section">SECURITY BENEFIT:</div>
                <ul class="nsm-cons-list">
                    <li class="nsm-cons-item nsm-impact-positive">Attacker lateral movement from enterprise blocked</li>
                    <li class="nsm-cons-item nsm-impact-positive">Safety-critical devices isolated from ransomware propagation</li>
                </ul>
            `;
        }

        body.innerHTML = html;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SVG connection drawing with four zones and toggleable rules
    // ─────────────────────────────────────────────────────────────────────────

    _drawConnections() {
        const svg    = this.container.querySelector('#nsm-svg');
        const area   = this.container.querySelector('#nsm-topology-area');
        const extEl  = this.container.querySelector('#nsm-zone-external');
        const entEl  = this.container.querySelector('#nsm-zone-enterprise');
        const clinEl = this.container.querySelector('#nsm-zone-clinical');
        const legEl  = this.container.querySelector('#nsm-zone-legacy');

        if (!svg || !area || !extEl || !entEl || !clinEl || !legEl) return;

        const aRect = area.getBoundingClientRect();
        if (aRect.width === 0 || aRect.height === 0) return;

        // Convert a DOMRect to topology-area-local coordinates
        const local = (el) => {
            const b = el.getBoundingClientRect();
            return {
                left:  b.left   - aRect.left,
                right: b.right  - aRect.left,
                top:   b.top    - aRect.top,
                bot:   b.bottom - aRect.top,
                midX: (b.left  + b.right)  / 2 - aRect.left,
                midY: (b.top   + b.bottom) / 2 - aRect.top,
            };
        };

        const ext  = local(extEl);
        const ent  = local(entEl);
        const clin = local(clinEl);
        const leg  = local(legEl);
        const W    = aRect.width;
        const H    = aRect.height;

        svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
        svg.setAttribute('width',   W);
        svg.setAttribute('height',  H);
        svg.innerHTML = '';

        const ns = 'http://www.w3.org/2000/svg';

        // Legacy bridge: a dedicated curved path from top-center of enterprise
        // to top-center of legacy, arching above the clinical zone.
        const entTopCenterX = ent.midX;
        const legTopCenterX = leg.midX;
        const legacyStartY = ent.top;
        const legacyEndY = leg.top;
        const legacyArcPeakY = Math.max(10, Math.min(ent.top, clin.top, leg.top) - 30);

        // Midpoint x-coordinates for icon placement
        const pfMidX = (ext.right  + ent.left)  / 2;  // perimeter FW midpoint
        const ecMidX = (ent.right  + clin.left) / 2;  // enterprise↔clinical midpoint
        const elMidX = (ent.right  + leg.left)  / 2;  // enterprise↔legacy midpoint

        // Vertically centered lanes for all non-curved links.
        const centerY = ent.midY;
        const pfY = centerY;
        const ifY = centerY - 32;
        const r1Y = centerY;
        const r3Y = centerY + 32;
        const legacyWarnY = legacyArcPeakY + 2;

        if (!this.severed) {
            // ── Perimeter firewall: External → Enterprise (white, solid) ──────────
            this._svgLine(svg, ns, ext.right, pfY, ent.left, pfY, '#ffffff', 3, null);
            this._svgPadlock(svg, ns, pfMidX, pfY, '#ffffff');

            // ── Internal firewall: Enterprise → Clinical (amber, solid) ─────────
            this._svgLine(svg, ns, ent.right, ifY, clin.left, ifY, '#ffb300', 3, null);
            this._svgPadlock(svg, ns, ecMidX, ifY, '#ffb300');

            // ── Rule 1: Ward 5 dual-homed workstations (orange, dashed) ─────────
            const rule1Line = this._svgLine(svg, ns, ent.right, r1Y, clin.left, r1Y, '#ff7700', 2, '8 5', this.ruleStates.rule1 ? 1 : 0.45);
            this._wireRuleToggle(rule1Line, 'rule1', 'Ward 5 dual-homed bridge');
            const rule1Hit = this._svgLine(svg, ns, ent.right, r1Y, clin.left, r1Y, '#ffffff', 16, null, 0);
            this._wireRuleToggle(rule1Hit, 'rule1', 'Ward 5 dual-homed bridge');
            this._svgWarning(svg, ns, ecMidX, r1Y);
            this._svgRuleLabel(svg, ns, ecMidX, r1Y + 16, 'WARD 5');
            if (this.ruleStates.rule1) {
                this._drawAttackPath(svg, ns, ent.right, r1Y, clin.left, r1Y);
            }

            // ── Rule 2: Ward 7 domain join (orange, dashed) ──────────────────────
            // Curved top-center enterprise → legacy connection.
            const rule2Path = this._svgPath(
                svg,
                ns,
                `M ${entTopCenterX} ${legacyStartY}
                 Q ${elMidX} ${legacyArcPeakY} ${legTopCenterX} ${legacyEndY}`,
                '#ff7700',
                2,
                '8 5',
                this.ruleStates.rule2 ? 1 : 0.45
            );
            this._wireRuleToggle(rule2Path, 'rule2', 'Ward 7 domain join bridge');
            const rule2Hit = this._svgPath(
                svg,
                ns,
                `M ${entTopCenterX} ${legacyStartY}
                 Q ${elMidX} ${legacyArcPeakY} ${legTopCenterX} ${legacyEndY}`,
                '#ffffff',
                18,
                null,
                0
            );
            this._wireRuleToggle(rule2Hit, 'rule2', 'Ward 7 domain join bridge');
            this._svgWarning(svg, ns, elMidX, legacyWarnY);
            this._svgRuleLabel(svg, ns, elMidX, legacyWarnY + 22, 'WARD 7');
            if (this.ruleStates.rule2) {
                this._drawAttackPathCurve(
                    svg,
                    ns,
                    `M ${entTopCenterX} ${legacyStartY}
                     Q ${elMidX} ${legacyArcPeakY} ${legTopCenterX} ${legacyEndY}`
                );
            }
            this._svgRuleLabel(svg, ns, elMidX, legacyArcPeakY - 10, 'NO SEGMENTATION');

            // ── Rule 3: Fleet management from admin subnet (orange, dashed) ────────
            const rule3Line = this._svgLine(svg, ns, ent.right, r3Y, clin.left, r3Y, '#ff7700', 2, '8 5', this.ruleStates.rule3 ? 1 : 0.45);
            this._wireRuleToggle(rule3Line, 'rule3', 'Fleet management bridge');
            const rule3Hit = this._svgLine(svg, ns, ent.right, r3Y, clin.left, r3Y, '#ffffff', 16, null, 0);
            this._wireRuleToggle(rule3Hit, 'rule3', 'Fleet management bridge');
            this._svgWarning(svg, ns, ecMidX, r3Y);
            this._svgRuleLabel(svg, ns, ecMidX, r3Y + 16, 'FLEET');
            if (this.ruleStates.rule3) {
                this._drawAttackPath(svg, ns, ent.right, r3Y, clin.left, r3Y);
            }

        } else {
            // ── Severed state: red X between enterprise and clinical ──────────────
            const sX = ecMidX;
            const sY = ent.midY;

            // Stub lines leading into the X
            this._svgLine(svg, ns, ent.right,  sY, sX - 22, sY, '#cc2200', 2, '5 4');
            this._svgLine(svg, ns, sX + 22,    sY, clin.left, sY, '#cc2200', 2, '5 4');

            // Red X
            this._svgLine(svg, ns, sX - 14, sY - 14, sX + 14, sY + 14, '#ff2200', 4, null);
            this._svgLine(svg, ns, sX + 14, sY - 14, sX - 14, sY + 14, '#ff2200', 4, null);

            // Label
            const t = document.createElementNS(ns, 'text');
            t.setAttribute('x',           sX);
            t.setAttribute('y',           sY + 32);
            t.setAttribute('text-anchor', 'middle');
            t.setAttribute('fill',        '#ff2200');
            t.setAttribute('font-size',   '14');
            t.setAttribute('font-family', "'VT323', monospace");
            t.textContent = 'LINK SEVERED';
            svg.appendChild(t);

        }
    }

    _drawAttackPath(svg, ns, x1, y1, x2, y2) {
        // Draw a red arrow/tracer along the line showing attack path
        const arrowY = (y1 + y2) / 2;

        // Animated red arrow marker
        const marker = document.createElementNS(ns, 'defs');
        const arrowMarker = document.createElementNS(ns, 'marker');
        arrowMarker.setAttribute('id', 'attack-arrow');
        arrowMarker.setAttribute('markerWidth', '10');
        arrowMarker.setAttribute('markerHeight', '10');
        arrowMarker.setAttribute('refX', '9');
        arrowMarker.setAttribute('refY', '3');
        arrowMarker.setAttribute('orient', 'auto');
        arrowMarker.setAttribute('markerUnits', 'strokeWidth');

        const poly = document.createElementNS(ns, 'polygon');
        poly.setAttribute('points', '0 0, 10 3, 0 6');
        poly.setAttribute('fill', '#ff2200');
        arrowMarker.appendChild(poly);
        marker.appendChild(arrowMarker);
        svg.appendChild(marker);

        // Draw red path with arrow
        const path = document.createElementNS(ns, 'line');
        path.setAttribute('x1', x1);
        path.setAttribute('y1', arrowY);
        path.setAttribute('x2', x2);
        path.setAttribute('y2', arrowY);
        path.setAttribute('stroke', '#ff2200');
        path.setAttribute('stroke-width', '2');
        path.setAttribute('marker-end', 'url(#attack-arrow)');
        path.setAttribute('opacity', '0.7');
        path.setAttribute('pointer-events', 'none');
        svg.appendChild(path);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SVG primitive helpers
    // ─────────────────────────────────────────────────────────────────────────

    _svgLine(svg, ns, x1, y1, x2, y2, stroke, width, dash, opacity = 1) {
        const el = document.createElementNS(ns, 'line');
        el.setAttribute('x1', x1);
        el.setAttribute('y1', y1);
        el.setAttribute('x2', x2);
        el.setAttribute('y2', y2);
        el.setAttribute('stroke', stroke);
        el.setAttribute('stroke-width', width);
        if (dash) el.setAttribute('stroke-dasharray', dash);
        el.setAttribute('opacity', opacity);
        svg.appendChild(el);
        return el;
    }

    _svgPath(svg, ns, d, stroke, width, dash, opacity = 1) {
        const el = document.createElementNS(ns, 'path');
        el.setAttribute('d', d.replace(/\s+/g, ' ').trim());
        el.setAttribute('fill', 'none');
        el.setAttribute('stroke', stroke);
        el.setAttribute('stroke-width', width);
        el.setAttribute('stroke-linecap', 'round');
        el.setAttribute('stroke-linejoin', 'round');
        if (dash) el.setAttribute('stroke-dasharray', dash);
        el.setAttribute('opacity', opacity);
        svg.appendChild(el);
        return el;
    }

    _wireRuleToggle(el, ruleId, label) {
        if (!el || this.severed) return;
        el.style.pointerEvents = 'stroke';
        el.style.cursor = 'pointer';
        el.setAttribute('aria-label', `${label} toggle`);
        this.addEventListener(el, 'click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            this._toggleRule(ruleId);
        });
    }

    _drawAttackPathCurve(svg, ns, d) {
        const marker = document.createElementNS(ns, 'defs');
        const arrowMarker = document.createElementNS(ns, 'marker');
        arrowMarker.setAttribute('id', 'attack-arrow-curve');
        arrowMarker.setAttribute('markerWidth', '10');
        arrowMarker.setAttribute('markerHeight', '10');
        arrowMarker.setAttribute('refX', '9');
        arrowMarker.setAttribute('refY', '3');
        arrowMarker.setAttribute('orient', 'auto');
        arrowMarker.setAttribute('markerUnits', 'strokeWidth');

        const poly = document.createElementNS(ns, 'polygon');
        poly.setAttribute('points', '0 0, 10 3, 0 6');
        poly.setAttribute('fill', '#ff2200');
        arrowMarker.appendChild(poly);
        marker.appendChild(arrowMarker);
        svg.appendChild(marker);

        const path = document.createElementNS(ns, 'path');
        path.setAttribute('d', d.replace(/\s+/g, ' ').trim());
        path.setAttribute('fill', 'none');
        path.setAttribute('stroke', '#ff2200');
        path.setAttribute('stroke-width', '2');
        path.setAttribute('marker-end', 'url(#attack-arrow-curve)');
        path.setAttribute('opacity', '0.75');
        path.setAttribute('pointer-events', 'none');
        svg.appendChild(path);
    }

    _svgRuleLabel(svg, ns, x, y, text) {
        const t = document.createElementNS(ns, 'text');
        t.setAttribute('x', x);
        t.setAttribute('y', y);
        t.setAttribute('text-anchor', 'middle');
        t.setAttribute('fill', '#d0d6ff');
        t.setAttribute('font-size', '11');
        t.setAttribute('font-family', "'VT323', monospace");
        t.setAttribute('font-weight', 'bold');
        t.setAttribute('pointer-events', 'none');
        t.textContent = text;
        svg.appendChild(t);
    }

    _svgPadlock(svg, ns, x, y, color) {
        const g = document.createElementNS(ns, 'g');

        const arc = document.createElementNS(ns, 'path');
        arc.setAttribute('d', `M ${x-6} ${y-2} Q ${x-6} ${y-14} ${x} ${y-14} Q ${x+6} ${y-14} ${x+6} ${y-2}`);
        arc.setAttribute('stroke', color);
        arc.setAttribute('stroke-width', '2.5');
        arc.setAttribute('fill', 'none');
        g.appendChild(arc);

        const body = document.createElementNS(ns, 'rect');
        body.setAttribute('x', x - 8);
        body.setAttribute('y', y - 2);
        body.setAttribute('width',  '16');
        body.setAttribute('height', '12');
        body.setAttribute('fill',   '#0d0d1a');
        body.setAttribute('stroke', color);
        body.setAttribute('stroke-width', '2');
        g.appendChild(body);

        const dot = document.createElementNS(ns, 'circle');
        dot.setAttribute('cx', x);
        dot.setAttribute('cy', y + 4);
        dot.setAttribute('r',  '2.5');
        dot.setAttribute('fill', color);
        g.appendChild(dot);

        g.setAttribute('pointer-events', 'none');
        svg.appendChild(g);
    }

    _svgWarning(svg, ns, x, y) {
        const g = document.createElementNS(ns, 'g');

        const tri = document.createElementNS(ns, 'polygon');
        tri.setAttribute('points', `${x},${y-9} ${x-8},${y+5} ${x+8},${y+5}`);
        tri.setAttribute('fill',   '#1a0a00');
        tri.setAttribute('stroke', '#ff7700');
        tri.setAttribute('stroke-width', '1.5');
        g.appendChild(tri);

        const t = document.createElementNS(ns, 'text');
        t.setAttribute('x',           x);
        t.setAttribute('y',           y + 4);
        t.setAttribute('text-anchor', 'middle');
        t.setAttribute('fill',        '#ff7700');
        t.setAttribute('font-size',   '9');
        t.setAttribute('font-family', 'monospace');
        t.setAttribute('font-weight', 'bold');
        t.textContent = '!';
        g.appendChild(t);

        g.setAttribute('pointer-events', 'none');
        svg.appendChild(g);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Starter helper
// ─────────────────────────────────────────────────────────────────────────────

export function startNetworkSegmentationMapMinigame(params = {}) {
    if (!window.MinigameFramework) {
        console.error('[NSM] MinigameFramework not available');
        return;
    }
    window.MinigameFramework.startMinigame('network-segmentation-map', null, {
        showCancel: false,
        ...params,
        onComplete: (success, result) => {
            console.log('[NSM] Network segmentation map completed, network_isolated:', success);
            if (params.onComplete) params.onComplete(success, result);
        }
    });
}
