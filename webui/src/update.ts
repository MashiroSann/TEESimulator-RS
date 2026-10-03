import { Cli } from './cli'
import { File } from './file'
import { GITHUB_REPO, TS_MOD_ID } from './constant'

const BOT_BASE = `https://raw.githubusercontent.com/${GITHUB_REPO}/bot`
const MIRROR_BASE = 'https://gh.sevencdn.com/'

export class UpdateManager {
  readonly #cli: Cli

  constructor(cli: Cli) {
    this.#cli = cli
  }

  // The bundled Tricky Addon WebUI has no self-update path in this fork: module
  // updates arrive through the module's own updateJson (checked by the root
  // manager). Only the translation bundle can still be refreshed from upstream,
  // and the About dialog keeps that button disabled by default.
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
      const moduleUpdateDir = `/data/adb/modules_update/${TS_MOD_ID}/webroot/locales`
      const zipPath = `${tmpDir}/locales.zip`

      await File.createDirectory(tmpDir)
      await this.#downloadFile(`${BOT_BASE}/locales.zip`, zipPath)
      await this.#cli.unzip(zipPath, localesDir)
      if (await File.isDirectory(moduleUpdateDir)) {
        await this.#cli.unzip(zipPath, moduleUpdateDir)
      }
      await File.write(`${localesDir}/version`, remoteVersion)
      await File.delete(zipPath)
      return true
    } catch {
      throw new Error('Failed to update locales')
    }
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
}
