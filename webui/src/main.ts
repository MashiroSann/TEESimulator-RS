import '@material/web/all'
import type { MdOutlinedTextField, MdDialog, MdFab, MdFilledButton, MdIconButton } from '@material/web/all'
import { i18n } from './i18n'
import { MainMenu } from './main_menu/main_menu'
import { Cli } from './cli'
import { Config } from './config'
import { ConfigLegacy } from './config_legacy'
import { ConfigOhMyKeyMint } from './config_ohmykeymint'
import { ConfigTeeSimulator } from './config_teesimulator'
import { AppList } from './app_list/app_list'
import { Snackbar } from './snackbar/snackbar'
import { FileSelector } from './file_selector/file_selector'
import { History } from './history'
import { Keybox } from './keybox/keybox'
import { KeyboxRepo } from './keybox/repo/repo'
import { DialogController } from './dialog/dialog'
import { SearchBar } from './search_bar/search_bar'
import { Keybind } from './keybind'
import { MOD_ID, OMK_MOD_ID, TEES_MOD_ID, TS_MOD_ID } from './constant'
import { File } from './file'
import './style.scss'
import { isDev } from './utils/dev'

await i18n.init()

const snackbar = new Snackbar()
const fileSelector = new FileSelector()
const cli = new Cli()
const history = new History()
const keybind = new Keybind()

let config: Config
try {
  const tsInfo = await cli.getTrickyStoreInfo()
  config = await createConfig(tsInfo)
} catch {
  config = new Config()
}

async function createConfig(tsInfo: Record<string, string>): Promise<Config> {
  const modId = tsInfo.id
  const versionCode = parseInt(tsInfo.versionCode, 10)
  switch (true) {
    case modId === OMK_MOD_ID:
      return new ConfigOhMyKeyMint()    // Oh My Keymint
    case modId === TEES_MOD_ID:
      return new ConfigTeeSimulator()   // Tee Simulator
    case modId === TS_MOD_ID:
      // TEESimulator-RS always uses the legacy target.txt + security_patch.txt
      // surface. A leftover config.ini from stock TrickyStore must not flip the
      // WebUI into stock mode — it would silently save policies to config.ini,
      // which the app-side ConfigurationManager never reads.
      return new ConfigLegacy()
    case Config.support(versionCode):
      return new Config()               // config.ini
    default:
      return new ConfigLegacy()         // target.txt + security_patch.txt
  }
}

document.querySelector<HTMLDivElement>('#app')!.innerHTML = /* html */ `
  <section class="header">
    <div id="title" class="search-hide">${i18n.t('header_title')}</div>
    <div class="spacer"></div>
    <md-icon-button id="search-button" class="search-hide"><md-icon>search</md-icon></md-icon-button>
    <md-outlined-text-field class="search-bar hide">
      <md-icon-button slot="trailing-icon" id="search-close"><md-icon>close</md-icon></md-icon-button>
    </md-outlined-text-field>
    <div class="main-menu">
      <md-icon-button id="menu-button">
        <md-icon>more_vert</md-icon>
      </md-icon-button>
    </div>
  </section>

  <section class="body-content">
    <div class="app-list">
      <div class="loading"><md-circular-progress indeterminate></md-circular-progress></div>
    </div>
    <div class="uninstall">
      <md-filled-button id="uninstall">
        <md-icon slot="icon">delete</md-icon>
        ${i18n.t('functional_button_uninstall_webui')}
      </md-filled-button>
    </div>
    <div class="bottom-safe-inset"></div>
  </section>

  <section class="floating-content fab-hide">
    ${snackbar.html()}
    <div class="fab-container">
      <md-fab variant="primary" class="fab fab-hide" id="save" label="${i18n.t('functional_button_save')}">
        <md-icon slot="icon">edit_note</md-icon>
      </md-fab>
    </div>
  </section>

  <section class="dialog-content"></section>
`

// App List
const appList = new AppList(config, cli)
await config.read()
await appList.fetch()
appList.syncSystemAppsWithConfig()
const appListContainer = document.querySelector<HTMLElement>('.app-list')!
appList.renderAppList(appListContainer)
float(false)

// Search bar
const searchBar = new SearchBar(history)
const searchBarEl = document.querySelector<MdOutlinedTextField>('.search-bar')!
const searchHide = document.querySelectorAll<HTMLElement>('.search-hide')
const searchButton = document.getElementById('search-button') as MdIconButton
searchBar.init(searchBarEl, searchHide, appListContainer)
searchButton.onclick = () => searchBar.show()

// Save App List
const saveFab = document.getElementById('save') as MdFab
saveFab.onclick = () => saveTarget()
async function saveTarget(): Promise<void> {
  try {
    await appList.save()
    await appList.refresh()
    snackbar.show(i18n.t('prompt_saved_target'))
  } catch (e) {
    snackbar.show(i18n.t('prompt_save_error'), false)
  }
}

/**
 * Toggle visibility of floating content
 * @param hide True to hide, false to show
 */
function float(hide: boolean): void {
  document.querySelectorAll('.floating-content, .fab').forEach(el => el.classList.toggle('fab-hide', hide))
}

// Main Menu events
const mainMenu = new MainMenu()
const keybox = new Keybox(cli, config, fileSelector, snackbar)
const keyboxRepo = new KeyboxRepo(keybox, history, snackbar)
const mainMenuContainer = document.querySelector<HTMLElement>('.main-menu')!
mainMenu.appendTo(mainMenuContainer)
mainMenu.on('menu-open', () => appList.menuOpen = true)
mainMenu.on('menu-close', () => appList.menuOpen = false)
mainMenu.on('menu-refresh', async () => await appList.refresh())
mainMenu.on('menu-select-all', () => appList.selectAll())
mainMenu.on('menu-deselect-all', () => appList.deselectAll())
mainMenu.on('menu-keybox-aosp', async () => await keybox.setAospKey())
mainMenu.on('menu-keybox-unknown', async () => await keybox.setUnknownKey())
mainMenu.on('menu-keybox-local', async () => await keybox.setLocalKey())
mainMenu.on('menu-keybox-repo', () => keyboxRepo.show())
mainMenu.on('menu-add-system-app', () => dialogController.showSystemApp())
mainMenu.on('menu-select-denylist', async () => appList.fetchDenyList())
mainMenu.on('menu-deselect-unnecessary', async () => appList.deselectUnnecessary())
mainMenu.on('menu-prop-setting', () => dialogController.showProp())
mainMenu.on('menu-default-policy', () => dialogController.showDefaultPolicy())
mainMenu.on('menu-help', () => dialogController.showHelp())
mainMenu.on('menu-about', () => dialogController.showAbout())
mainMenu.on('menu-i18n-guide', () => dialogController.showI18nDialog())
if ((await cli.getManager()) !== 'MAGISK' && !isDev()) {
  mainMenu.hideItem('select-denylist') // Hide 'select from denylist'
}
if (!Keybox.isKeygenAvailable() && !isDev()) {
  mainMenu.hideItem('keybox-unknown') // Hide 'Unknown keybox'
}

// The bundled Tricky Addon WebUI has no self-update path in this fork; module
// updates are checked by the root manager via the module's updateJson.

// Keyboard shortcut events
keybind.on('keybind-select-all', () => appList.selectAll())
keybind.on('keybind-deselect-all', () => appList.deselectAll())
keybind.on('keybind-search', () => searchBar.show())
keybind.on('keybind-save', () => saveTarget())
keybind.on('keybind-esc', () => history.back())

// Dialog
const dialogController = new DialogController(cli, config, snackbar, appList)
const dialogContent = document.querySelector<HTMLElement>('.dialog-content')!
fileSelector.appendTo(dialogContent)
keybox.appendTo(dialogContent)
keyboxRepo.appendTo(dialogContent)
keybox.custom.renderEntries()
dialogController.appendAll(dialogContent)
dialogContent.querySelectorAll<MdDialog>('md-dialog').forEach((dialog, i) => {
  const id = dialog.id || `md-dialog-${i}`
  dialog.addEventListener('open', () => history.push(id, () => dialog.close()))
  dialog.addEventListener('closed', () => history.consume(id))
})

// Uninstall webui: only meaningful when this WebUI is installed as a separate Tricky Addon
// module next to the host. When bundled with the host module there is nothing to uninstall.
const uninstallBtn = document.getElementById('uninstall') as MdFilledButton
if (await File.exist(`/data/adb/modules/${MOD_ID}`)) {
  uninstallBtn.onclick = async () => {
    dialogController.showUninstall()
  }
} else {
  document.querySelector('.uninstall')?.classList.add('hide')
}

// Scroll event
let lastScrollY = window.scrollY
window.onscroll = () => {
  document.querySelectorAll('md-menu').forEach(menu => menu.close())
  float(window.scrollY > lastScrollY && window.scrollY > 48)
  document.querySelector('.header')?.classList.toggle('scroll', window.scrollY > 10)
  lastScrollY = window.scrollY
}
