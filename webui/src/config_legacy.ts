import { File } from './file'
import { isDev } from './utils/dev'
import { Config } from './config'
import type { ConfigData, Policy } from './config'

function parseTarget(raw: string): string[] {
  const targets: string[] = []
  for (const line of raw.split('\n')) {
    const trimmed = line.trim()
    if (trimmed === '' || trimmed.startsWith('#')) continue
    targets.push(trimmed)
  }
  return targets
}

function stripDay(value: string): string {
  return /^\d{8}$/.test(value) ? value.slice(0, 6) : value
}

function parseSecurityPatch(raw: string): { policy: Policy; sections: string[] } {
  const policy: Policy = {}
  const sections: string[] = []
  let inSection = false
  for (const line of raw.split('\n')) {
    const trimmed = line.trim()
    if (trimmed === '' || trimmed.startsWith('#')) continue

    // Per-package sections ([pkg]) belong to TEESimulator-RS; keep them verbatim so a
    // global-policy edit in the WebUI does not drop them.
    if (trimmed.startsWith('[')) {
      inSection = true
      sections.push(trimmed)
      continue
    }
    if (inSection) {
      sections.push(trimmed)
      continue
    }

    const eqIdx = trimmed.indexOf('=')
    if (eqIdx === 0) continue

    const key = eqIdx > 0 ? trimmed.slice(0, eqIdx).trim() : 'all'
    const value = eqIdx > 0 ? trimmed.slice(eqIdx + 1).trim() : trimmed

    switch (key) {
      case 'system':
        policy.os_patch = value
        break
      case 'boot':
        policy.boot_patch = value
        break
      case 'vendor':
        policy.vendor_patch = value
        break
      case 'all': {
        policy.os_patch = stripDay(value)
        policy.boot_patch = value
        policy.vendor_patch = value
        break
      }
    }
  }
  return { policy, sections }
}

function serializeTarget(target: string[]): string {
  return target.join('\n')
}

function isNoOpPolicy(policy: Policy | undefined | null): boolean {
  if (!policy) return true
  return [policy.os_patch, policy.vendor_patch, policy.boot_patch]
    .every(v => v === undefined || v === 'no')
}

function serializeSecurityPatch(policy: Policy): string {
  const lines: string[] = []
  if (policy.os_patch !== undefined) lines.push(`system=${policy.os_patch}`)
  if (policy.boot_patch !== undefined) lines.push(`boot=${policy.boot_patch}`)
  if (policy.vendor_patch !== undefined) lines.push(`vendor=${policy.vendor_patch}`)
  return lines.join('\n')
}

export class ConfigLegacy extends Config {
  override readonly identity: string = 'TS-L'

  protected override readonly CONFIG_FILE = this.CONFIG_PATH + '/target.txt'
  protected readonly SECURITY_PATCH_FILE = this.CONFIG_PATH + '/security_patch.txt'

  protected readonly perAppConfig: boolean = false

  // Per-package `[pkg]` sections from security_patch.txt, preserved verbatim on write.
  #patchSections: string[] = []

  override async read(): Promise<void> {
    if (isDev()) {
      this.set({
        default_policy: { os_patch: 'no', vendor_patch: 'no', boot_patch: 'no' },
        target: [
          'io.github.vvb2060.keyattestation',
          'io.github.vvb2060.mahoshojo?',
          'com.google.android.gms!',
        ],
      })
      return
    }

    const data: ConfigData = {}

    try {
      const targetRaw = await File.read(this.CONFIG_FILE)
      data.target = parseTarget(targetRaw)
    } catch {
      data.target = []
    }

    try {
      const spRaw = await File.read(this.SECURITY_PATCH_FILE)
      const { policy, sections } = parseSecurityPatch(spRaw)
      this.#patchSections = sections
      if (Object.keys(policy).length > 0) data.default_policy = policy
    } catch {
      // security_patch.txt missing — leave default_policy unset
    }

    if (!data.default_policy) {
      data.default_policy = { os_patch: 'no', vendor_patch: 'no', boot_patch: 'no' }
    }

    this.set(data)
  }

  override async write(): Promise<void> {
    const data = this.get()

    const writeTasks: Promise<void>[] = []

    if (data.target) {
      writeTasks.push(File.write(this.CONFIG_FILE, serializeTarget(data.target)))
    }

    const parts: string[] = []
    if (data.default_policy && !isNoOpPolicy(data.default_policy)) {
      parts.push(serializeSecurityPatch(data.default_policy))
    }
    if (this.#patchSections.length > 0) {
      if (parts.length > 0) parts.push('')
      parts.push(...this.#patchSections)
    }

    if (parts.length > 0) {
      writeTasks.push(File.write(this.SECURITY_PATCH_FILE, parts.join('\n')))
    } else {
      writeTasks.push(File.delete(this.SECURITY_PATCH_FILE))
    }

    await Promise.all(writeTasks)
  }
}
