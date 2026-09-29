import { Cli } from './cli'
import { File } from './file'
import type { Config } from './config'
import { GITHUB_REPO, TS_MOD_ID } from './constant'

const RAW_URL = `https://raw.githubusercontent.com/${GITHUB_REPO}`
// Module update metadata for this fork (module.prop updateJson points at the same file).
const UPDATE_JSON_URL = 'https://raw.githubusercontent.com/MashiroSann/TEESimulator-RS/main/module/update.json'
const BOT_BASE = `${RAW_URL}/bot`
const MIRROR_BASE = 'https://gh.sevencdn.com/'

export interface UpdateInfo {
  available: boolean
  version: string | null
  versionCode: number | null
}

export class UpdateManager {
  #cli: Cli

  constructor(cli: Cli, _config: Config) {
    this.#cli = cli
  }

  async #getLocalVersionCode(): Promise<number> {
    try {
      const info = await this.#cli.getTrickyStoreInfo()
      return parseInt(info.versionCode, 10) || 0
    } catch {
      return 0
    }
  }

  async checkUpdate(channel: 'stable' | 'canary'): Promise<UpdateInfo> {
    if (channel === 'stable') return this.#checkStableUpdate()
    return this.#checkCanaryUpdate()
  }

  async update(channel: 'stable' | 'canary'): Promise<boolean> {
    if (channel === 'stable') return this.#performStableUpdate()
    return this.#performCanaryUpdate()
  }

  async getChangelog(channel: 'stable' | 'canary', versionCode?: number | null): Promise<string> {
    if (channel === 'canary') return `A new version is available: ${versionCode ?? 'unknown'}`
    return this.#getStableChangelog()
  }

  async updateLocales(): Promise<boolean> {
    try {
      const response = await this.#fetchWithFallback(`${BOT_BASE}/locales_version`)
      if (!response.ok) return false
      const remoteVersion = (await response.text()).trim()

      const localResp = await fetch('./locales/version').catch(() => null)
      const localVersion = localResp ? (await localResp.text()).trim() : '0'

      if (Number(remoteVersion) <= Number(localVersion)) return false

      const basePath = await this.#cli.getBasePath()
      const tmpDir = `${basePath}/common/tmp`
      const localesDir = `${basePath}/webroot/locales`
      const localseUpdateDir = `/data/adb/modules_update/${TS_MOD_ID}/webroot/locales`
      const zipPath = `${tmpDir}/locales.zip`

      await File.createDirectory(tmpDir)
      await this.#downloadFile(`${BOT_BASE}/locales.zip`, zipPath)
      await this.#cli.unzip(zipPath, localesDir)
      if (await File.isDirectory(localseUpdateDir)) {
        await this.#cli.unzip(zipPath, localseUpdateDir)
      }
      await File.write(`${localesDir}/version`, remoteVersion)
      await File.delete(zipPath)
      return true
    } catch {
      throw new Error('Failed to update locales')
    }
  }

  async #checkStableUpdate(): Promise<UpdateInfo> {
    try {
      const response = await fetch(UPDATE_JSON_URL)
      if (!response.ok) return { available: false, version: null, versionCode: null }

      const data = (await response.json()) as { versionCode: number; version: string }
      const localVersionCode = await this.#getLocalVersionCode()

      return {
        available: data.versionCode > localVersionCode,
        version: data.version,
        versionCode: data.versionCode,
      }
    } catch {
      return { available: false, version: null, versionCode: null }
    }
  }

  async #performStableUpdate(): Promise<boolean> {
    const response = await fetch(UPDATE_JSON_URL)
    if (!response.ok) throw new Error('Failed to fetch stable update info')
    const data = (await response.json()) as { zipUrl: string }
    return this.#downloadAndInstall(data.zipUrl)
  }

  async #getStableChangelog(): Promise<string> {
    try {
      const response = await fetch(UPDATE_JSON_URL)
      if (!response.ok) return 'Failed to fetch changelog'
      const data = (await response.json()) as { version?: string; changelog?: string }
      if (!data.changelog || !data.version) return 'No changelog available'

      const changelogResp = await fetch(data.changelog)
      if (!changelogResp.ok) return 'Failed to fetch changelog'
      const fullChangelog = await changelogResp.text()

      const header = `### ${data.version}`
      const lines = fullChangelog.split('\n')
      let found = false
      const result: string[] = []

      for (const line of lines) {
        if (line === header) {
          found = true
          result.push(line)
          continue
        }
        if (found) {
          if (line.startsWith('### ')) break
          result.push(line)
        }
      }

      return found ? result.join('\n').trim() : fullChangelog
    } catch {
      return 'Failed to fetch changelog'
    }
  }

  async #checkCanaryUpdate(): Promise<UpdateInfo> {
    return { available: false, version: null, versionCode: null }
  }

  async #performCanaryUpdate(): Promise<boolean> {
    throw new Error('Canary channel is not available for this fork')
  }

  async #fetchWithFallback(url: string): Promise<Response> {
    let firstStatus: number | string = 'network error'

    try {
      const response = await fetch(url)
      if (response.ok) return response
      firstStatus = response.status
    } catch {}

    const mirrorUrl = `${MIRROR_BASE}${url}`
    try {
      const mirrorResponse = await fetch(mirrorUrl)
      if (mirrorResponse.ok) return mirrorResponse
      throw new Error(`Fetch failed: ${firstStatus} (direct), ${mirrorResponse.status} (mirror)`)
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('Fetch failed')) throw error
      throw new Error(`Fetch failed: ${firstStatus} (direct), network error (mirror)`)
    }
  }

  async #downloadFile(url: string, destPath: string): Promise<void> {
    try {
      await this.#cli.downloadFile(url, destPath)
    } catch {
      await this.#cli.downloadFile(`${MIRROR_BASE}${url}`, destPath)
    }
  }

  async #downloadAndInstall(url: string): Promise<boolean> {
    const basePath = await this.#cli.getBasePath()
    const tmpDir = `${basePath}/common/tmp`

    await File.createDirectory(tmpDir)
    await this.#downloadFile(url, `${tmpDir}/module.zip`)
    try {
      await this.#cli.installModule(`${tmpDir}/module.zip`)
    } catch {
      return false
    }
    await this.updateLocales().catch(() => {})
    return true
  }
}
