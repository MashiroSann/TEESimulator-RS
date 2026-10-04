import { exec } from 'kernelsu-alt'
import type { Cli } from '../cli'

/** POSIX single-quote a value so it survives the root shell verbatim. */
function shQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`
}

/** State returned by `ta-enhanced webui-init` (top-level keys are camelCase). */
export interface TaEnhancedInit {
  module: {
    id: string
    name: string
    version: string
    versionCode: number
    author: string
  }
  // Config keeps the backend's snake_case field names.
  config: {
    keybox: { enabled: boolean; interval: number; source: string; custom_url: string }
    security_patch: { auto_update: boolean; interval: number; custom_date: string }
    automation: { enabled: boolean; interval: number; use_inotify: boolean; merge_denylist: boolean }
    health: { enabled: boolean; interval: number; grace_period: number; max_restarts: number }
    status: { enabled: boolean; interval: number; emoji: boolean }
    vbhash: { enabled: boolean }
    conflict: { enabled: boolean; auto_remove: boolean }
    [section: string]: unknown
  }
  status: {
    engine: string
    engineRunning: boolean
    activeApps: number
    totalTargeted: number
    keyboxLabel: string
    patchLevel: string
    vbhashActive: boolean
    restartCount: number
    tsForkSupported: boolean
    tsJamesFork: boolean
    magiskAvailable: boolean
    isAospDevice: boolean
  }
  conflicts: {
    modules: Array<{ id: string; name: string; reason: string }>
    apps: Array<{ packageName: string; name: string; reason: string }>
  }
  keybox: {
    valid: boolean
    source: string
    rootType: string
    lastFetch: string | null
    validationErrors: string[]
  }
  securityPatch: {
    system: string
    boot: string
    vendor: string
    latest: string | null
    autoUpdate: boolean
  }
}

/**
 * Thin wrapper around the embedded Tricky Addon Enhanced CLI
 * (module/taenh/arm64-v8a/ta-enhanced, engineered by Enginex0, GPLv3).
 * Controls are executed through the root shell bridge; the daemon watches
 * config.toml via inotify, so `config set` takes effect immediately.
 */
export class TaEnhanced {
  #cli: Cli
  #binaryPromise: Promise<string> | null = null
  #initCache: TaEnhancedInit | null = null
  #hashCache: string | null = null

  constructor(cli: Cli) {
    this.#cli = cli
  }

  /** Last successfully fetched webui-init payload, for instant dialog rendering. */
  get cachedInit(): TaEnhancedInit | null {
    return this.#initCache
  }

  /** Last successfully fetched VBHash value, for instant dialog rendering. */
  get cachedHash(): string | null {
    return this.#hashCache
  }

  /** Warm the caches so the enhanced dialog can paint instantly on first open. */
  async preload(): Promise<void> {
    try {
      await this.init()
      await this.vbhashShow()
    } catch {}
  }

  async #binary(): Promise<string> {
    if (!this.#binaryPromise) {
      this.#binaryPromise = this.#cli.getBasePath().then(base => `${base}/taenh/arm64-v8a/ta-enhanced`)
    }
    return this.#binaryPromise
  }

  async available(): Promise<boolean> {
    const bin = await this.#binary()
    try {
      const result = await exec(`[ -x '${bin}' ] && echo ok`)
      return result.errno === 0 && result.stdout.trim() === 'ok'
    } catch {
      return false
    }
  }

  async init(): Promise<TaEnhancedInit | null> {
    const bin = await this.#binary()
    try {
      const result = await exec(`'${bin}' webui-init 2>/dev/null`)
      if (result.errno !== 0) return null
      const raw = result.stdout.trim()
      if (!raw) return null
      const parsed = JSON.parse(raw) as TaEnhancedInit
      this.#initCache = parsed
      return parsed
    } catch {
      return null
    }
  }

  async configSet(key: string, value: string): Promise<boolean> {
    const bin = await this.#binary()
    try {
      const result = await exec(`'${bin}' config set ${shQuote(key)} ${shQuote(value)} 2>&1`)
      return result.errno === 0
    } catch {
      return false
    }
  }

  /**
   * Manual keybox fetch. Exit code 0 with "keybox fetched from existing" means
   * every remote source failed and the daemon kept the current keybox, so that
   * must be reported as a failure with the failing sources for context.
   */
  async keyboxFetch(): Promise<{ ok: boolean; detail?: string }> {
    const bin = await this.#binary()
    try {
      const result = await exec(`'${bin}' keybox fetch 2>&1`)
      const output = result.stdout
      if (result.errno !== 0) {
        const line = output.trim().split('\n').filter(Boolean).pop()
        return { ok: false, detail: line }
      }
      if (output.includes('fetched from existing')) {
        const failed = [...output.matchAll(/keybox from (\w+) (?:rejected|parse failed)/g)].map(m => m[1])
        return { ok: false, detail: failed.length ? failed.join(', ') : 'all remote sources failed' }
      }
      const source = output.match(/keybox fetched from (\w+)/)?.[1]
      return { ok: true, detail: source }
    } catch (e) {
      return { ok: false, detail: String(e) }
    }
  }

  async vbhashShow(): Promise<string | null> {
    const bin = await this.#binary()
    try {
      const result = await exec(`'${bin}' vbhash show 2>/dev/null`)
      if (result.errno !== 0) return null
      const value = result.stdout.trim()
      const hash = value && value !== 'no valid hash stored' ? value : null
      this.#hashCache = hash
      return hash
    } catch {
      return null
    }
  }

  async vbhashExtract(): Promise<boolean> {
    const bin = await this.#binary()
    try {
      const result = await exec(`'${bin}' vbhash extract 2>&1`)
      return result.errno === 0
    } catch {
      return false
    }
  }

  async vbhashPass(): Promise<boolean> {
    const bin = await this.#binary()
    try {
      const result = await exec(`'${bin}' vbhash pass 2>&1`)
      return result.errno === 0
    } catch {
      return false
    }
  }
}
