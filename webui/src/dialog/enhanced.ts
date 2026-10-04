import type { MdDialog, MdOutlinedButton, MdOutlinedSelect, MdOutlinedTextField, MdSwitch } from '@material/web/all'
import { i18n } from '../i18n'
import type { Cli } from '../cli'
import type { Snackbar } from '../snackbar/snackbar'
import { TaEnhanced, type TaEnhancedInit } from '../api/taEnhanced'
import { applyDialogAnimation } from './animation'

const INTERVAL_PRESETS: Array<[string, number]> = [
  ['1h', 3600],
  ['6h', 21600],
  ['12h', 43200],
  ['1d', 86400],
  ['3d', 259200],
  ['7d', 604800],
]

/** Enhanced automation controls backed by the embedded Tricky Addon Enhanced daemon. */
export class EnhancedDialog {
  #dialog: MdDialog | null = null
  #snackbar: Snackbar
  #api: TaEnhanced

  constructor(cli: Cli, snackbar: Snackbar) {
    this.#snackbar = snackbar
    this.#api = new TaEnhanced(cli)
  }

  getElement(): DocumentFragment {
    const template = document.createElement('template')
    template.innerHTML = /* html */ `
      <md-dialog id="enhanced-dialog">
        <div slot="headline">${i18n.t('enhanced_title')}</div>
        <div slot="content" class="enhanced-content">
          <div id="enh-unavailable" class="enhanced-unavailable" hidden>
            ${i18n.t('enhanced_unavailable')}
          </div>
          <div id="enh-loading" class="enhanced-loading" hidden>
            ${i18n.t('enhanced_loading')}
          </div>
          <div id="enh-body" hidden>
            <section class="enhanced-section">
              <h4>${i18n.t('enhanced_section_status')}</h4>
              <div id="enh-status" class="enhanced-grid"></div>
            </section>
            <section class="enhanced-section">
              <h4>${i18n.t('enhanced_section_keybox')}</h4>
              <label class="switch-item outlined" for="enh-kb-enabled">
                <md-ripple></md-ripple>
                <span>${i18n.t('enhanced_kb_auto')}</span>
                <md-switch icons="true" id="enh-kb-enabled" class="enh-switch" data-key="keybox.enabled"></md-switch>
              </label>
              <md-outlined-select id="enh-kb-source" label="${i18n.t('enhanced_kb_source')}">
                <md-select-option value="yurikey"><div slot="headline">Yurikey</div></md-select-option>
                <md-select-option value="upstream"><div slot="headline">Upstream (KOW)</div></md-select-option>
                <md-select-option value="custom"><div slot="headline">Custom</div></md-select-option>
              </md-outlined-select>
              <div id="enh-kb-status" class="enhanced-grid"></div>
              <md-outlined-text-field id="enh-kb-url" label="${i18n.t('enhanced_kb_url')}" autocapitalize="none"></md-outlined-text-field>
              <div class="enhanced-label">${i18n.t('enhanced_kb_interval')}</div>
              <div id="enh-kb-chips" class="enhanced-chip-row"></div>
              <md-outlined-text-field id="enh-kb-interval" label="${i18n.t('enhanced_kb_interval_custom')}" type="number" min="60"></md-outlined-text-field>
              <div class="enhanced-actions">
                <md-filled-tonal-button id="enh-kb-fetch">${i18n.t('enhanced_kb_fetch')}</md-filled-tonal-button>
              </div>
            </section>
            <section class="enhanced-section">
              <h4>${i18n.t('enhanced_section_vbhash')}</h4>
              <label class="switch-item outlined" for="enh-vb-enabled">
                <md-ripple></md-ripple>
                <span>${i18n.t('enhanced_vb_enabled')}</span>
                <md-switch icons="true" id="enh-vb-enabled" class="enh-switch" data-key="vbhash.enabled"></md-switch>
              </label>
              <div id="enh-vb-status" class="enhanced-grid"></div>
              <div class="enhanced-actions">
                <md-filled-tonal-button id="enh-vb-extract">${i18n.t('enhanced_vb_extract')}</md-filled-tonal-button>
                <md-filled-tonal-button id="enh-vb-pass">${i18n.t('enhanced_vb_pass')}</md-filled-tonal-button>
              </div>
            </section>
            <section class="enhanced-section">
              <h4>${i18n.t('enhanced_section_advanced')}</h4>
              <label class="switch-item outlined" for="enh-status-enabled">
                <md-ripple></md-ripple>
                <span>${i18n.t('enhanced_status_takeover')}</span>
                <md-switch icons="true" id="enh-status-enabled" class="enh-switch" data-key="status.enabled"></md-switch>
              </label>
              <label class="switch-item outlined" for="enh-health-enabled">
                <md-ripple></md-ripple>
                <span>${i18n.t('enhanced_health')}</span>
                <md-switch icons="true" id="enh-health-enabled" class="enh-switch" data-key="health.enabled"></md-switch>
              </label>
              <label class="switch-item outlined" for="enh-automation-enabled">
                <md-ripple></md-ripple>
                <span>${i18n.t('enhanced_automation')}</span>
                <md-switch icons="true" id="enh-automation-enabled" class="enh-switch" data-key="automation.enabled"></md-switch>
              </label>
              <label class="switch-item outlined" for="enh-conflict-auto">
                <md-ripple></md-ripple>
                <span>${i18n.t('enhanced_conflict_auto')}</span>
                <md-switch icons="true" id="enh-conflict-auto" class="enh-switch" data-key="conflict.auto_remove"></md-switch>
              </label>
              <div class="enhanced-label">${i18n.t('enhanced_conflicts_title')}</div>
              <div id="enh-conflicts" class="enhanced-grid"></div>
            </section>
          </div>
        </div>
        <div slot="actions">
          <md-outlined-button id="enh-refresh">${i18n.t('enhanced_refresh')}</md-outlined-button>
          <md-outlined-button id="close-enhanced">${i18n.t('functional_button_close')}</md-outlined-button>
        </div>
      </md-dialog>
    `

    const fragment = template.content
    this.#dialog = fragment.querySelector<MdDialog>('#enhanced-dialog')

    // Interval preset chips
    const chipRow = fragment.querySelector<HTMLElement>('#enh-kb-chips')!
    for (const [label, seconds] of INTERVAL_PRESETS) {
      const chip = document.createElement('md-text-button')
      chip.textContent = label
      chip.classList.add('enh-chip')
      chip.dataset.seconds = String(seconds)
      chip.onclick = () => this.#saveConfig('keybox.interval', String(seconds))
      chipRow.appendChild(chip)
    }

    // Boolean switches share one handler: write config and refresh.
    fragment.querySelectorAll<MdSwitch>('.enh-switch').forEach(sw => {
      sw.addEventListener('change', async () => {
        const key = sw.dataset.key!
        const ok = await this.#api.configSet(key, sw.selected ? 'true' : 'false')
        this.#snackbar.show(i18n.t(ok ? 'enhanced_saved' : 'enhanced_save_failed'), ok)
        await this.refresh()
      })
    })

    const sourceSelect = fragment.querySelector<MdOutlinedSelect>('#enh-kb-source')!
    sourceSelect.addEventListener('change', () => this.#saveConfig('keybox.source', sourceSelect.value))

    const urlInput = fragment.querySelector<MdOutlinedTextField>('#enh-kb-url')!
    urlInput.addEventListener('change', () => this.#saveConfig('keybox.custom_url', urlInput.value.trim()))

    const intervalInput = fragment.querySelector<MdOutlinedTextField>('#enh-kb-interval')!
    intervalInput.addEventListener('change', () => {
      const seconds = parseInt(intervalInput.value, 10)
      if (Number.isFinite(seconds) && seconds >= 60) this.#saveConfig('keybox.interval', String(seconds))
    })

    fragment.querySelector<HTMLElement>('#enh-kb-fetch')!.onclick = async () => {
      this.#snackbar.show(i18n.t('enhanced_kb_fetching'))
      const result = await this.#api.keyboxFetch()
      if (result.ok) {
        this.#snackbar.show(i18n.t('enhanced_keybox_ok'))
      } else {
        console.warn('[enhanced] keybox fetch failed:', result.detail)
        this.#snackbar.show(i18n.t('enhanced_kb_fetch_all_failed'), false)
      }
      await this.refresh()
    }

    fragment.querySelector<HTMLElement>('#enh-vb-extract')!.onclick = async () => {
      const ok = await this.#api.vbhashExtract()
      this.#snackbar.show(i18n.t(ok ? 'enhanced_action_ok' : 'enhanced_action_failed'), ok)
      await this.refresh()
    }

    fragment.querySelector<HTMLElement>('#enh-vb-pass')!.onclick = async () => {
      const ok = await this.#api.vbhashPass()
      this.#snackbar.show(i18n.t(ok ? 'enhanced_action_ok' : 'enhanced_action_failed'), ok)
      await this.refresh()
    }

    fragment.querySelector<HTMLElement>('#enh-refresh')!.onclick = () => this.refresh()
    fragment.querySelector<MdOutlinedButton>('#close-enhanced')!.onclick = () => this.close()

    return fragment
  }

  initAnimation(): void {
    if (this.#dialog) applyDialogAnimation(this.#dialog)
  }

  /** Warm the backend CLI caches so the next open paints instantly. */
  async preload(): Promise<void> {
    await this.#api.preload()
  }

  async show(): Promise<void> {
    this.#dialog?.show()
    const cached = this.#api.cachedInit
    if (cached) {
      // Paint the last known state immediately, then refresh in the background.
      this.#paint(cached, this.#api.cachedHash)
      void this.refresh()
    } else {
      await this.refresh()
    }
  }

  close(): void {
    this.#dialog?.close()
  }

  async refresh(): Promise<void> {
    const loading = this.#dialog?.querySelector<HTMLElement>('#enh-loading')
    const body = this.#dialog?.querySelector<HTMLElement>('#enh-body')
    if (!loading || !body) return

    if (body.hidden) loading.hidden = false
    const data = await this.#api.init()
    const hash = data ? await this.#api.vbhashShow() : null
    loading.hidden = true
    if (!data) {
      const unavailable = this.#dialog?.querySelector<HTMLElement>('#enh-unavailable')
      if (unavailable) unavailable.hidden = false
      body.hidden = true
      return
    }
    this.#paint(data, hash)
  }

  #paint(data: TaEnhancedInit, hash: string | null): void {
    const unavailable = this.#dialog?.querySelector<HTMLElement>('#enh-unavailable')
    const body = this.#dialog?.querySelector<HTMLElement>('#enh-body')
    if (!unavailable || !body) return
    unavailable.hidden = true
    body.hidden = false

    // Status
    const statusRows: Array<[string, string]> = [
      [i18n.t('enhanced_status_engine'), data.status.engineRunning ? `${data.status.engine} (running)` : `${data.status.engine} (stopped)`],
      [i18n.t('enhanced_status_keybox'), this.#keyboxLabel(data)],
      [i18n.t('enhanced_status_patch'), data.securityPatch.system || '-'],
      [i18n.t('enhanced_status_vbhash'), data.status.vbhashActive ? 'ON' : 'OFF'],
      [i18n.t('enhanced_status_apps'), `${data.status.activeApps}`],
      [i18n.t('enhanced_version'), `${data.module.version} (${data.module.versionCode})`],
    ]
    this.#renderGrid('#enh-status', statusRows)

    const kbValidRows: Array<[string, string]> = data.keybox.validationErrors.length
      ? [[i18n.t('enhanced_kb_errors'), data.keybox.validationErrors.join('; ')]]
      : []
    this.#renderGrid('#enh-kb-status', kbValidRows)

    // Keybox controls
    this.#setSwitch('#enh-kb-enabled', data.config.keybox.enabled)
    const sourceSelect = this.#dialog?.querySelector<MdOutlinedSelect>('#enh-kb-source')
    if (sourceSelect) sourceSelect.value = data.config.keybox.source
    const urlInput = this.#dialog?.querySelector<MdOutlinedTextField>('#enh-kb-url')
    if (urlInput) urlInput.value = data.config.keybox.custom_url ?? ''
    const intervalInput = this.#dialog?.querySelector<MdOutlinedTextField>('#enh-kb-interval')
    if (intervalInput) intervalInput.value = String(data.config.keybox.interval ?? 86400)

    // VBHash
    this.#setSwitch('#enh-vb-enabled', data.config.vbhash.enabled)
    this.#renderGrid('#enh-vb-status', [
      [i18n.t('enhanced_vb_hash'), hash ?? i18n.t('enhanced_vb_hash_none')],
    ])

    // Advanced
    this.#setSwitch('#enh-status-enabled', data.config.status.enabled)
    this.#setSwitch('#enh-health-enabled', data.config.health.enabled)
    this.#setSwitch('#enh-automation-enabled', data.config.automation.enabled)
    this.#setSwitch('#enh-conflict-auto', data.config.conflict.auto_remove)

    const conflicts: Array<[string, string]> = [
      ...data.conflicts.modules.map(m => [m.id, m.reason] as [string, string]),
      ...data.conflicts.apps.map(a => [a.packageName, a.reason] as [string, string]),
    ]
    const conflictRows: Array<[string, string]> = conflicts.length
      ? conflicts
      : [['-', i18n.t('enhanced_conflicts_none')]]
    this.#renderGrid('#enh-conflicts', conflictRows)
  }

  #keyboxLabel(data: TaEnhancedInit): string {
    if (!data.keybox.valid) return i18n.t('enhanced_kb_invalid')
    const root = data.keybox.rootType ? ` (${data.keybox.rootType})` : ''
    return `${data.keybox.source}${root}`
  }

  #setSwitch(selector: string, value: boolean): void {
    const sw = this.#dialog?.querySelector<MdSwitch>(selector)
    if (sw) sw.selected = !!value
  }

  #renderGrid(selector: string, rows: Array<[string, string]>): void {
    const el = this.#dialog?.querySelector<HTMLElement>(selector)
    if (!el) return
    el.innerHTML = ''
    for (const [key, value] of rows) {
      const row = document.createElement('div')
      row.className = 'enhanced-row'
      const k = document.createElement('span')
      k.className = 'enhanced-row-key'
      k.textContent = key
      const v = document.createElement('span')
      v.className = 'enhanced-row-value'
      v.textContent = value
      row.append(k, v)
      el.appendChild(row)
    }
  }

  async #saveConfig(key: string, value: string): Promise<void> {
    const ok = await this.#api.configSet(key, value)
    this.#snackbar.show(i18n.t(ok ? 'enhanced_saved' : 'enhanced_save_failed'), ok)
  }
}
