import { exec as bridgeExec } from 'kernelsu-alt'
import type { ExecOptions } from 'kernelsu-alt'

export interface ExecResult {
  errno: number
  stdout: string
  stderr: string
}

/**
 * Timeout-wrapped exec.
 *
 * The WebUI bridge delivers exec() results through a callback that has to make
 * it back into the page (the root manager evaluates javascript with the
 * callback name). If that callback is ever lost - busy WebView, manager quirk -
 * the promise from kernelsu-alt never settles and everything awaiting it hangs
 * forever. That is exactly how the page got stuck on its loading placeholder
 * and the enhanced panel on "loading". Every exec therefore gets a hard
 * timeout; on expiry it resolves with errno 124 so callers take their normal
 * error / fallback paths instead of blocking the UI.
 */
export function exec(cmd: string, timeoutMs = 8000, options?: ExecOptions): Promise<ExecResult> {
  return new Promise(resolve => {
    let settled = false
    const timer = setTimeout(() => {
      if (settled) return
      settled = true
      resolve({ errno: 124, stdout: '', stderr: `exec timed out after ${timeoutMs}ms` })
    }, timeoutMs)
    bridgeExec(cmd, options).then(
      result => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve(result)
      },
      error => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve({ errno: 1, stdout: '', stderr: String(error) })
      },
    )
  })
}

/**
 * Resolve with the promise's value, or undefined when it takes too long or
 * rejects. Used to hard-bound startup steps so a stalled bridge or fetch can
 * never keep the loading spinner on screen.
 */
export function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T | undefined> {
  return new Promise(resolve => {
    let settled = false
    const timer = setTimeout(() => {
      if (settled) return
      settled = true
      resolve(undefined)
    }, timeoutMs)
    promise.then(
      value => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve(value)
      },
      () => {
        if (settled) return
        settled = true
        clearTimeout(timer)
        resolve(undefined)
      },
    )
  })
}
