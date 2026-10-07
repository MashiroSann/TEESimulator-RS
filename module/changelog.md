## TEESimulator-RS v6.0.1-367

**English** — Fixed the WebUI getting stuck on its loading spinner and the Enhanced panel hanging on "Loading" when the network is unreachable (for example without a proxy).

- **The WebUI no longer touches the network while just opening.** The Enhanced panel's keybox status check fetched Google's attestation revocation list (`android.googleapis.com`); on blocked or unreachable networks that request stalled, and because root managers execute WebUI bridge commands synchronously, one stalled request froze the entire page. Panel validation now uses only the embedded revocation list and opens instantly offline — the online list is still used when actually fetching or installing a keybox. In addition, every bridge call and locale request in the startup path now has a hard timeout with fallback rendering, so a stalled command can never keep the loading spinner on screen again.

**简体中文** — 修复无代理/网络不通时 WebUI 卡在加载转圈、Enhanced 面板卡在"加载中"的问题。

- **WebUI 仅打开页面时不再联网。** Enhanced 面板的 keybox 状态校验会请求 Google 吊销名单（`android.googleapis.com`），网络被墙时该请求长时间挂起；而 root 管理器对 WebUI 桥接命令是同步执行，一条挂起的命令就会冻结整个页面。现在面板校验只使用内置吊销名单，离线也能秒开——在线名单仍用于真正获取/安装 keybox 的流程。此外，启动链路上的所有桥接调用与语言文件请求都加了硬超时和回退渲染，卡住的命令不会再让加载转圈无限持续。

## TEESimulator-RS v6.0.1-360

**English** — The module now bundles the Tricky Addon Enhanced automation backend with its own control panel.

- **Enhanced automation backend (optional, arm64).** The release zip embeds the Tricky Addon Enhanced daemon (by Enginex0, GPL-3.0, built from pinned source): keybox rotation, security-patch auto-update, VBHash spoofing, live module description, automatic target-list maintenance and conflict detection — controlled from the new "Enhanced" panel in the WebUI. A `-NoEnhanced` zip is published alongside the regular one; each build tracks its own update channel.

**简体中文** — 模块现已内置 Tricky Addon Enhanced 自动化后端，并提供独立控制面板。

- **内置增强自动化后端（可选，arm64）。** Release 包内置 Tricky Addon Enhanced 守护进程（Enginex0 开发，GPL-3.0，按固定版本源码构建）：keybox 轮换、安全补丁自动更新、VBHash 伪装、模块描述实时状态、目标列表自动维护与冲突检测，全部由 WebUI 新增的"Enhanced"面板控制。同时发布不含后端的 `-NoEnhanced` 包，两种包各自更新各自的分支。

## TEESimulator-RS v6.0.1-338

**English** — WebUI cleanup: the bundled Tricky Addon WebUI no longer carries its own update machinery.

- **The WebUI's self-update is gone.** The About dialog no longer shows the update-channel selector, the canary-update button, or the translation-bundle button. Module updates are checked exclusively by your root manager through `module/update.json` — the WebUI will no longer display its own "new version" banner or install updates by itself.
- **About links updated.** The GitHub button now points at this fork (MashiroSann/TEESimulator-RS); the Telegram button is explicitly labeled as the original Tricky Addon upstream channel.

**简体中文** — WebUI 清理：内置的 Tricky Addon WebUI 不再带有自己的更新机制。

- **WebUI 自更新功能整体移除。** “关于”弹窗不再有更新通道选择器、测试版更新按钮和翻译包更新按钮。模块更新完全由 root 管理器通过 `module/update.json` 检查——WebUI 不再显示自己的“有新版本”横幅，也不会自行下载安装更新。
- **“关于”按钮指向更新。** GitHub 按钮改指向本 fork（MashiroSann/TEESimulator-RS）；Telegram 按钮明确标注为 Tricky Addon 原版频道。

## TEESimulator-RS v6.0.1-327

**English** — WebUI save fix.

- **The WebUI no longer writes the target list into `config.ini`.** A leftover stock TrickyStore `config.ini` made the WebUI fall back to stock mode, so target-list and default-policy saves silently did nothing (the app side only reads `target.txt`). The WebUI now always uses this fork's `target.txt` + `security_patch.txt` layout.
- If you previously saved the target list in the WebUI and interception never took effect, re-save the list once and verify `target.txt` contains your packages.

**简体中文** — WebUI 保存修复。

- **WebUI 不再把目标列表写进 `config.ini`。** 设备上残留的 stock TrickyStore `config.ini` 会让 WebUI 误判为 stock 模式，导致目标列表和“设置默认策略”的保存静默失效（App 端只读 `target.txt`）。现在 WebUI 永远使用本 fork 的 `target.txt` + `security_patch.txt` 布局。
- 如果你此前在 WebUI 里保存过目标列表但拦截未生效，请重新保存一次，并确认 `target.txt` 中包含需要的包名。

## TEESimulator-RS v6.0.1-312

Tricky Addon merged into the module: the WebUI now ships inside the zip next to the original Action button.

- Bundled the [Tricky Addon](https://github.com/KOWX712/Tricky-Addon-Update-Target-List) WebUI (upstream `cf16784`, v5.0-beta.4, Apache-2.0), served from `webroot/`. Root managers with WebUI support (KernelSU, KernelSU Next, APatch) show a WebUI button beside the Action button. Edit the target list, manage `keybox.xml` (AOSP / local file / community repo) and review security patch settings without installing a second module.
- The Action button is unchanged: persistent-key management plus the debug-build log export.
- The WebUI detects this fork and drives `target.txt` + `security_patch.txt`, preserving per-package `[pkg]` patch sections when the global policy is saved.
- Sensitive-prop handling imported from Tricky Addon (`prop.sh`, opt out with `/data/adb/disable_prop_handler`), plus the TSupport-A target-list guard.
- WebUI update checks now follow this fork's `module/update.json`; canary/nightly is disabled.
- Windows `build-module.ps1` builds the WebUI (Node.js + pnpm, proxy-aware) before packaging; `-SkipWebui` reuses an existing `module\webroot`.
- Fixed app attest-key chains: a key whose sole purpose is `PURPOSE_ATTEST_KEY` is now issued by the keybox even without an attestation challenge (real TEE behavior), instead of a self-signed certificate. Keys attested by an app-generated attest key chain to the Google root again — no more "unknown root certificate" and key-replacement detections.
- If you already installed the earlier v6.0.1-312 build, reinstall this one manually: the versionCode is unchanged.

---

> 更早的历史（fork 之前）见 [Enginex0/TEESimulator-RS Releases](https://github.com/Enginex0/TEESimulator-RS/releases)。
> Older history (pre-fork) lives in the upstream release page above.
