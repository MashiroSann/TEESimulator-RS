import { exec } from 'kernelsu-alt'
import { isSupported, renderBlockingPage, UPDATE_URL } from './webview/webview'

// The root manager exposes its theme variables (system colors, window insets)
// under the WebUI virtual host. Load them asynchronously with a timeout: as a
// CSS @import they were render-blocking, so whenever the manager did not serve
// them and the (virtual) host was unreachable, the whole page stayed stuck on
// its loading placeholder (observed on networks without a proxy).
for (const name of ['insets.css', 'colors.css']) {
  fetch(`https://mui.kernelsu.org/internal/${name}`, { signal: AbortSignal.timeout(8000) })
    .then(response => (response.ok ? response.text() : ''))
    .then(css => {
      if (!css) return
      const style = document.createElement('style')
      style.textContent = css
      document.head.appendChild(style)
    })
    .catch(() => {})
}

// Check is webview version met requirement
if (!isSupported()) {
  document.querySelector<HTMLDivElement>('#app')!.innerHTML = renderBlockingPage()
  document.getElementById('update-webview')!.onclick = async () => {
    const result = await exec(`am start -a android.intent.action.VIEW -d '${UPDATE_URL}'`)
    if (result.errno !== 0) window.open(UPDATE_URL, '_blank')
  }
} else {
  try {
    await import('./main')
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e)
    document.querySelector<HTMLDivElement>('#app')!.innerHTML = `<p id="load-error">Failed to load app: ${msg}</p>`
  }
}
