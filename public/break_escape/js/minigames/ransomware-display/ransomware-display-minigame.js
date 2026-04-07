import { MinigameScene } from '../framework/base-minigame.js';

const TIMER_DURATION_MS = 72 * 60 * 60 * 1000;

function parseTimestamp(value) {
    if (typeof value === 'number' && Number.isFinite(value)) {
        return value;
    }

    if (typeof value === 'string') {
        const asNumber = Number(value);
        if (Number.isFinite(asNumber)) {
            return asNumber;
        }

        const asDate = Date.parse(value);
        if (Number.isFinite(asDate)) {
            return asDate;
        }
    }

    return null;
}

function formatCountdown(remainingMs) {
    const totalSeconds = Math.max(0, Math.floor(remainingMs / 1000));
    const hours = Math.floor(totalSeconds / 3600).toString().padStart(2, '0');
    const minutes = Math.floor((totalSeconds % 3600) / 60).toString().padStart(2, '0');
    const seconds = (totalSeconds % 60).toString().padStart(2, '0');
    return `${hours}:${minutes}:${seconds}`;
}

export class RansomwareDisplayMinigame extends MinigameScene {
    constructor(container, params) {
        params = params || {};
        params.title = params.title || 'Ransomware Impact Display';
        params.showCancel = true;
        params.cancelText = params.cancelText || 'Close';

        super(container, params);

        this.timerInterval = null;
        this.deadlineAt = null;
        this.actionTaken = null;
        this.actionTakenList = [];
    }

    init() {
        super.init();

        this.container.className += ' ransomware-display-minigame-container';
        this.gameContainer.className += ' ransomware-display-game-container';
        this.headerElement.style.display = 'none';

        this.render();

        // Resolve and persist timer state during init so re-opens are consistent.
        this.ensureDeadlineTimestamp();
        this.updateTimerDisplay();
    }

    start() {
        super.start();

        const contactBtn = this.gameContainer.querySelector('#ransomware-contact-btn');
        const reportBtn = this.gameContainer.querySelector('#ransomware-report-btn');
        const recoveryBtn = this.gameContainer.querySelector('#ransomware-recovery-btn');

        if (contactBtn) {
            this.addEventListener(contactBtn, 'click', () => this.handleDecision('contact_attackers'));
        }

        if (reportBtn) {
            this.addEventListener(reportBtn, 'click', () => this.handleDecision('ncsc_notified'));
        }

        if (recoveryBtn) {
            this.addEventListener(recoveryBtn, 'click', () => this.handleDecision('recovery_started'));
        }

        if (this.isRansomwareDeployed()) {
            this.timerInterval = setInterval(() => {
                this.updateTimerDisplay();
            }, 1000);
        }
    }

    isRansomwareDeployed() {
        return !!window.gameState?.globalVariables?.ransomware_deployed;
    }

    getActionState() {
        const vars = window.gameState?.globalVariables || {};
        const taken = [];

        if (vars.contact_attackers === true) {
            taken.push('contact_attackers');
        }
        if (vars.ncsc_notified === true) {
            taken.push('ncsc_notified');
        }
        if (vars.recovery_started === true) {
            taken.push('recovery_started');
        }

        return taken;
    }

    getScenarioStartTimestamp() {
        const vars = window.gameState?.globalVariables || {};
        const fromGlobals = parseTimestamp(vars.scenario_start_time) || parseTimestamp(vars.scenarioStartTime);
        const fromState = parseTimestamp(window.gameState?.startTime);

        return fromGlobals || fromState || Date.now();
    }

    ensureDeadlineTimestamp() {
        const vars = window.gameState?.globalVariables || {};
        const existingDeadline = parseTimestamp(vars.ransomware_deadline_at);

        if (existingDeadline) {
            this.deadlineAt = existingDeadline;
            return;
        }

        const scenarioStart = this.getScenarioStartTimestamp();
        const deadlineAt = scenarioStart + TIMER_DURATION_MS;
        this.setGlobalAndNotify('ransomware_deadline_at', deadlineAt);
        this.deadlineAt = deadlineAt;
    }

    setGlobalAndNotify(varName, value) {
        if (!window.gameState) {
            window.gameState = {};
        }

        if (!window.gameState.globalVariables) {
            window.gameState.globalVariables = {};
        }

        if (window.npcManager && typeof window.npcManager.setGlobalVariable === 'function') {
            window.npcManager.setGlobalVariable(varName, value);
            return;
        }

        const oldValue = window.gameState.globalVariables[varName];
        window.gameState.globalVariables[varName] = value;

        if (window.npcConversationStateManager) {
            window.npcConversationStateManager.broadcastGlobalVariableChange(varName, value, null);
        }

        if (window.eventDispatcher) {
            window.eventDispatcher.emit(`global_variable_changed:${varName}`, {
                name: varName,
                value: value,
                oldValue: oldValue
            });
        }
    }

    updateTimerDisplay() {
        const timerEl = this.gameContainer.querySelector('#ransomware-timer-value');
        if (!timerEl || !this.deadlineAt) {
            return;
        }

        const remainingMs = this.deadlineAt - Date.now();
        const expired = remainingMs <= 0;

        timerEl.textContent = formatCountdown(remainingMs);
        timerEl.classList.toggle('expired', expired);

        const timerLabelEl = this.gameContainer.querySelector('#ransomware-timer-label');
        if (timerLabelEl) {
            timerLabelEl.textContent = expired ? 'TIME EXPIRED:' : 'TIME REMAINING:';
        }
    }

    handleDecision(varName) {
        if (!this.isRansomwareDeployed()) {
            return;
        }

        // If an action has already been taken in this scenario, do nothing.
        if (this.actionTakenList.length > 0) {
            return;
        }

        this.setGlobalAndNotify(varName, true);
        this.actionTakenList = [varName];
        this.actionTaken = varName;

        const actionToButtonId = {
            contact_attackers: 'ransomware-contact-btn',
            ncsc_notified: 'ransomware-report-btn',
            recovery_started: 'ransomware-recovery-btn'
        };

        const selectedButtonId = actionToButtonId[varName];
        const allButtons = this.gameContainer.querySelectorAll('.ransomware-display-btn');

        allButtons.forEach((btn) => {
            btn.disabled = true;
            btn.classList.remove('selected');
        });

        if (selectedButtonId) {
            const selectedButton = this.gameContainer.querySelector(`#${selectedButtonId}`);
            if (selectedButton) {
                selectedButton.classList.add('selected');
            }
        }

        const statusEl = this.gameContainer.querySelector('#ransomware-action-status');
        if (statusEl) {
            statusEl.textContent = `Action recorded: ${this.getActionLabel(varName)}`;
            statusEl.classList.remove('warning');
        }
    }

    getActionLabel(actionKey) {
        const map = {
            contact_attackers: 'CONTACT ATTACKERS',
            ncsc_notified: 'REPORT TO NCSC',
            recovery_started: 'BEGIN RECOVERY PROCESS'
        };
        return map[actionKey] || actionKey;
    }

    render() {
        this.actionTakenList = this.getActionState();
        this.actionTaken = this.actionTakenList.length > 0 ? this.actionTakenList[0] : null;
        const deployed = this.isRansomwareDeployed();
        const hasPriorAction = this.actionTakenList.length > 0;

        const selectedLabel = this.actionTaken ? this.getActionLabel(this.actionTaken) : null;
        const multiActionLabel = this.actionTakenList.map((key) => this.getActionLabel(key)).join(', ');

        this.gameContainer.innerHTML = `
            <div class="ransomware-display-bg">
                <div class="ransomware-display-panel">
                    <div class="ransomware-display-icon">☠️ // 🔒</div>
                    <h2 class="ransomware-display-title">YOUR FILES HAVE BEEN ENCRYPTED</h2>
                    <pre class="ransomware-display-body">NORTHGATE GENERAL HOSPITAL NHS TRUST
312 workstations | 4 file servers | EHR database
1.2 BITCOIN - 1,200,000 GBP
Wallet: darkvault-ops-onion-wallet
DO NOT attempt recovery - encrypted files will be destroyed</pre>

                    <div class="ransomware-display-timer-row">
                        <span id="ransomware-timer-label">TIME REMAINING:</span>
                        <span id="ransomware-timer-value">72:00:00</span>
                    </div>

                    <div id="ransomware-action-status" class="ransomware-display-note ${(!deployed || this.actionTakenList.length > 1) ? 'warning' : ''}">${!deployed ? 'Ransomware event is not currently deployed in global state.' : (hasPriorAction && this.actionTakenList.length === 1 ? `Action already taken: ${selectedLabel}` : (hasPriorAction && this.actionTakenList.length > 1 ? `Multiple actions already recorded: ${multiActionLabel}` : 'Choose one response action. You can close the window when done.'))}</div>

                    <div class="ransomware-display-actions">
                        <button id="ransomware-contact-btn" class="ransomware-display-btn contact ${this.actionTaken === 'contact_attackers' ? 'selected' : ''}" ${!deployed || hasPriorAction ? 'disabled' : ''}>
                            <span class="icon">☠️</span>
                            <span class="label">CONTACT ATTACKERS</span>
                        </button>
                        <button id="ransomware-report-btn" class="ransomware-display-btn report ${this.actionTaken === 'ncsc_notified' ? 'selected' : ''}" ${!deployed || hasPriorAction ? 'disabled' : ''}>
                            <span class="icon">🛡️</span>
                            <span class="label">REPORT TO NCSC</span>
                        </button>
                        <button id="ransomware-recovery-btn" class="ransomware-display-btn recovery ${this.actionTaken === 'recovery_started' ? 'selected' : ''}" ${!deployed || hasPriorAction ? 'disabled' : ''}>
                            <span class="icon">🔧</span>
                            <span class="label">BEGIN RECOVERY PROCESS</span>
                        </button>
                    </div>
                </div>
            </div>
        `;
    }

    cleanup() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
        super.cleanup();
    }
}
