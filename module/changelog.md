## TEESimulator-RS v6.0.1-360

**English** — The module now bundles the Tricky Addon Enhanced automation backend with its own control panel.

- **Enhanced automation backend (optional, arm64).** The release zip embeds the Tricky Addon Enhanced daemon (by Enginex0, GPL-3.0, built from pinned source): keybox rotation, security-patch auto-update, VBHash spoofing, live module description, automatic target-list maintenance and conflict detection — controlled from the new "Enhanced" panel in the WebUI. A `-NoEnhanced` zip is published alongside the regular one; each build tracks its own update channel.
- **Keybox fetching works with real-world keyboxes again.** The fetch-time validator accepts common community keyboxes (SEC1 private keys and P-256/P-384 ECDSA certificate chains), so "Fetch now" and automatic rotation succeed instead of rejecting valid files.
- **Security patch control.** The Enhanced panel can toggle the daily Google-bulletin auto-update and pin a custom date; reinstalling the module no longer overwrites your date, and a failed bulletin fetch keeps the current date instead of inventing one.
- **Daemon reliability.** The enhanced daemon now starts reliably after every reboot (a stale PID file could previously make it skip startup), and turning off the live module description restores the original description immediately.
- **Panel fixes.** The Enhanced panel opens instantly and scrolls in a single swipe.

**简体中文** — 模块现已内置 Tricky Addon Enhanced 自动化后端，并提供独立控制面板。

- **内置增强自动化后端（可选，arm64）。** Release 包内置 Tricky Addon Enhanced 守护进程（Enginex0 开发，GPL-3.0，按固定版本源码构建）：keybox 轮换、安全补丁自动更新、VBHash 伪装、模块描述实时状态、目标列表自动维护与冲突检测，全部由 WebUI 新增的"Enhanced"面板控制。同时发布不含后端的 `-NoEnhanced` 包，两种包各自更新各自的分支。
- **keybox 获取恢复正常。** 校验器现在接受常见的真实 keybox（SEC1 私钥与 P-256/P-384 ECDSA 证书链），"立即获取"和自动轮换不再误判有效文件。
- **安全补丁可控。** Enhanced 面板可开关"跟随 Google 公告自动更新"并固定自定义日期；重装模块不再覆盖你的日期；公告抓取失败时保留现有日期，不再凭空生成。
- **守护进程可靠性。** 修复重启后 daemon 可能不启动的问题；关闭"实时状态"后立即恢复模块原始描述。
- **面板体验修复。** Enhanced 面板即时打开，一次滑动即可到底。

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
