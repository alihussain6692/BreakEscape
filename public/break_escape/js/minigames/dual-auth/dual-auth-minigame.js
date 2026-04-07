import { MinigameScene } from '../framework/base-minigame.js';
import { notifyServerUnlock } from '../../systems/unlock-system.js';

export class DualAuthMinigame extends MinigameScene {
    constructor(container, params = {}) {
        super(container, {
            ...params,
            title: 'Dual Authorisation Panel',
            showCancel: true,
            cancelText: 'Close'
        });

        this.itsecPin    = String(params.lockable?.scenarioData?.itsec_pin    || '');
        this.clinicalPin = String(params.lockable?.scenarioData?.clinical_pin || '');

        this.remainingSec      = 300;
        this.itsecConfirmed    = false;
        this.clinicalConfirmed = false;
        this.finished          = false;
        this.itsecInput        = '';
        this.clinicalInput     = '';
        this._timerId          = null;
    }

    init() {
        super.init();
        // Hide the base framework header — we render our own
        if (this.headerElement) {
            this.headerElement.style.display = 'none';
        }
        this.gameContainer.classList.add('da-game-container');
        this.renderLayout();
    }

    start() {
        super.start();
        this._startCountdown();
    }

    renderLayout() {
        this.gameContainer.innerHTML = `
<div class="da-panel-wrap">
  <div class="da-header">
    <div class="da-title">NETWORK ISOLATION — DUAL AUTHORISATION REQUIRED</div>
    <div class="da-timer" id="da-timer">05:00</div>
  </div>
  <div class="da-panels">
    <div class="da-panel" id="da-panel-itsec">
      <div class="da-panel-label">IT SECURITY MANAGER</div>
      <div class="da-panel-name">Ravi Anand</div>
      <div class="da-display" id="da-display-itsec">____</div>
      <div class="da-keypad" id="da-keypad-itsec"></div>
      <div class="da-status pending" id="da-status-itsec">PENDING</div>
    </div>
    <div class="da-panel" id="da-panel-clinical">
      <div class="da-panel-label">CLINICAL ENGINEERING</div>
      <div class="da-panel-name">David Osei</div>
      <div class="da-display" id="da-display-clinical">____</div>
      <div class="da-keypad" id="da-keypad-clinical"></div>
      <div class="da-status pending" id="da-status-clinical">PENDING</div>
    </div>
  </div>
  <button class="da-authorise-btn" id="da-authorise" disabled>
    AUTHORISE NETWORK ISOLATION
  </button>
</div>`;

        this._buildKeypad('itsec');
        this._buildKeypad('clinical');

        this.addEventListener(
            this.gameContainer.querySelector('#da-authorise'),
            'click',
            () => this.handleAuthorise()
        );
    }

    _buildKeypad(side) {
        const container = this.gameContainer.querySelector(`#da-keypad-${side}`);
        if (!container) return;

        // Digits 1-9 in rows of 3, then CLEAR / 0 / SUBMIT
        const keys = ['1','2','3','4','5','6','7','8','9','CLEAR','0','SUBMIT'];
        keys.forEach(k => {
            const btn = document.createElement('button');
            btn.className = k === 'SUBMIT' ? 'da-key da-key-submit' :
                            k === 'CLEAR'  ? 'da-key da-key-clear'  :
                            'da-key';
            btn.textContent = k;
            btn.dataset.side = side;
            btn.dataset.key  = k;

            this.addEventListener(btn, 'click', () => {
                if (k === 'CLEAR')  this.handleClear(side);
                else if (k === 'SUBMIT') this.handleSubmit(side);
                else this.handleDigit(side, k);
            });

            container.appendChild(btn);
        });
    }

    _updateDisplay(side) {
        const input = side === 'itsec' ? this.itsecInput : this.clinicalInput;
        const display = this.gameContainer.querySelector(`#da-display-${side}`);
        if (!display) return;
        // Show entered digits, pad remainder with underscores (up to 4 visible slots)
        const slots = Math.max(4, input.length);
        display.textContent = input.padEnd(slots, '_');
    }

    handleDigit(side, digit) {
        if (this.finished) return;
        if (side === 'itsec') {
            if (this.itsecConfirmed) return;
            if (this.itsecInput.length >= 6) return;
            this.itsecInput += digit;
        } else {
            if (this.clinicalConfirmed) return;
            if (this.clinicalInput.length >= 6) return;
            this.clinicalInput += digit;
        }
        this._updateDisplay(side);
    }

    handleClear(side) {
        if (this.finished) return;
        if (side === 'itsec') {
            if (this.itsecConfirmed) return;
            this.itsecInput = '';
        } else {
            if (this.clinicalConfirmed) return;
            this.clinicalInput = '';
        }
        this._updateDisplay(side);
    }

    handleSubmit(side) {
        if (this.finished) return;

        const input   = side === 'itsec' ? this.itsecInput   : this.clinicalInput;
        const correct = side === 'itsec' ? this.itsecPin      : this.clinicalPin;
        const display = this.gameContainer.querySelector(`#da-display-${side}`);
        const panel   = this.gameContainer.querySelector(`#da-panel-${side}`);
        const status  = this.gameContainer.querySelector(`#da-status-${side}`);

        if (input !== correct) {
            // Flash denied
            if (display) {
                display.textContent = 'ACCESS DENIED';
                display.classList.add('da-display-denied');
            }
            if (status) {
                status.textContent = 'ACCESS DENIED';
                status.className = 'da-status denied';
            }
            setTimeout(() => {
                if (side === 'itsec') this.itsecInput = '';
                else this.clinicalInput = '';
                this._updateDisplay(side);
                if (display) display.classList.remove('da-display-denied');
                if (status && !this.itsecConfirmed && side === 'itsec') {
                    status.textContent = 'PENDING';
                    status.className = 'da-status pending';
                }
                if (status && !this.clinicalConfirmed && side === 'clinical') {
                    status.textContent = 'PENDING';
                    status.className = 'da-status pending';
                }
            }, 1500);
            return;
        }

        // Correct PIN
        if (side === 'itsec') {
            this.itsecConfirmed = true;
            this.setGlobalAndNotify('itsec_authorised', true);
        } else {
            this.clinicalConfirmed = true;
            this.setGlobalAndNotify('clinical_eng_authorised', true);
        }

        // Update panel appearance
        if (panel)   panel.classList.add('da-panel-authorised');
        if (display) display.textContent = 'AUTHORISED';
        if (status) {
            status.textContent = 'AUTHORISED';
            status.className = 'da-status authorised';
        }

        // Disable all buttons on this panel
        const buttons = this.gameContainer.querySelectorAll(`#da-keypad-${side} button`);
        buttons.forEach(b => { b.disabled = true; });

        this._checkBothConfirmed();
    }

    _checkBothConfirmed() {
        if (this.itsecConfirmed && this.clinicalConfirmed) {
            const btn = this.gameContainer.querySelector('#da-authorise');
            if (btn) btn.disabled = false;
        }
    }

    async handleAuthorise() {
        if (this.finished) return;
        this.finished = true;
        this._stopCountdown();

        this.setGlobalAndNotify('network_isolation_authorised', true);
        this.setGlobalAndNotify('network_isolated', true);

        try {
            const serverResponse = await notifyServerUnlock(
                this.params.lockable, this.params.type || 'object', 'dual_auth'
            );
            this.complete(true, { serverResponse });
        } catch (e) {
            console.error('DualAuth: server unlock notification failed', e);
            this.complete(true, {});
        }
    }

    _startCountdown() {
        const timerEl = () => this.gameContainer.querySelector('#da-timer');

        this._timerId = setInterval(() => {
            if (this.finished) {
                this._stopCountdown();
                return;
            }
            this.remainingSec--;

            const el = timerEl();
            if (el) {
                const m = Math.floor(this.remainingSec / 60);
                const s = this.remainingSec % 60;
                el.textContent = `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
                el.classList.remove('warning', 'critical');
                if (this.remainingSec < 10)      el.classList.add('critical');
                else if (this.remainingSec < 60) el.classList.add('warning');
            }

            if (this.remainingSec <= 0) {
                this._stopCountdown();
                this._onTimeout();
            }
        }, 1000);
    }

    _stopCountdown() {
        if (this._timerId !== null) {
            clearInterval(this._timerId);
            this._timerId = null;
        }
    }

    _onTimeout() {
        if (this.finished) return;
        this.finished = true;
        this.setGlobalAndNotify('dual_auth_failed', true);

        const wrap = this.gameContainer.querySelector('.da-panel-wrap');
        if (wrap) {
            const banner = document.createElement('div');
            banner.className = 'da-timeout-banner';
            banner.textContent = 'AUTHORISATION TIMED OUT';
            wrap.appendChild(banner);
        }

        setTimeout(() => this.complete(false), 1500);
    }

    setGlobalAndNotify(name, value) {
        if (window.npcManager?.setGlobalVariable) {
            window.npcManager.setGlobalVariable(name, value);
            return;
        }
        const oldValue = window.gameState?.globalVariables?.[name];
        if (window.gameState?.globalVariables) {
            window.gameState.globalVariables[name] = value;
        }
        window.npcConversationStateManager?.broadcastGlobalVariableChange(name, value, null);
        window.eventDispatcher?.emit(`global_variable_changed:${name}`, { name, value, oldValue });
    }

    cleanup() {
        this._stopCountdown();
        super.cleanup();
    }
}
