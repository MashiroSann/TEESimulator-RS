<h1 align="center">TEESimulator-RS</h1>
<p align="center"><b>让已 root 的安卓手机通过硬件安全检测</b></p>
<p align="center">
  <a href="https://github.com/Enginex0/TEESimulator-RS/actions/workflows/build.yml"><img src="https://github.com/Enginex0/TEESimulator-RS/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/Android-10%2B-green?logo=android" alt="Android 10+">
  <a href="https://t.me/superpowers9"><img src="https://img.shields.io/badge/Telegram-community-blue?logo=telegram" alt="Telegram"></a>
</p>

<p align="center">
  <b><a href="README.md">English</a></b> | 简体中文
</p>

---

> [!NOTE]
> 本项目是 [JingMatrix/TEESimulator](https://github.com/JingMatrix/TEESimulator) 的 fork。在原项目基础上加入了 Rust 实现的证书生成、密钥重启持久化，以及与原生 Android 一致的认证行为。原项目请见上游仓库。

## 本 fork 的改动

在上游之外，本 fork 让模拟器在 app 探测伪造安全芯片时表现得和真实 KeyMint 硬件一致：

- **混合用途认证密钥会被拒绝。** `generateKey` 请求若将 `ATTEST_KEY` 与其他用途组合，现在会以 `INCOMPATIBLE_PURPOSE`（`-3`）失败——与真实硬件行为完全一致。上游则会直接创建该密钥。
- **主动拒绝的错误保留真实错误码。** 模拟器内部产生的拒绝会返回真实芯片会给出的 KeyMint 错误码，而不是一律折叠成 `SECURE_HW_COMMUNICATION_FAILED`（`-49`）。
- **错误名称与回退逻辑对齐 AOSP。** 返回给 app 的错误码与文案已按官方 KeyMint `ErrorCode` AIDL 表逐一校正。
- **RSA-OAEP MGF1 遵循规范。** 省略 MGF1 digest 的操作默认使用 SHA-1；当密钥授权的 digest 集不含该值时，返回 `INCOMPATIBLE_MGF_DIGEST`（`-78`）；`Digest.NONE` 返回 `UNSUPPORTED_MGF_DIGEST`（`-79`）。对真实硬件密钥，生成时缓存其允许的 MGF1 digest 并在操作中执行同样规则，使宽松的厂商实现与严格的实现不可区分。
- **内置 Tricky Addon WebUI。** 模块现捆绑 [Tricky Addon](https://github.com/KOWX712/Tricky-Addon-Update-Target-List) 的 WebUI（上游 `cf16784`，v5.0-beta.4，Apache-2.0）。支持模块 WebUI 的 root 管理器（KernelSU、KernelSU Next、APatch）会在 Action 按钮旁显示第二个按钮，从 `webroot/` 提供：编辑目标列表、管理 `keybox.xml`（AOSP / 本地文件 / 社区仓库）、查看安全补丁设置。Action 按钮保留原有的持久化密钥管理。WebUI 能识别本 fork 并使用其 `target.txt` + `security_patch.txt` 布局，保存时保留每应用的 `[pkg]` 补丁段落。
- **应用认证密钥由 keybox 签发。** 仅含 `PURPOSE_ATTEST_KEY` 的密钥即使没有 challenge 也由 keybox 签发（与真实硬件一致）。应用使用自生成的认证密钥对自身密钥认证时，证书链仍然连接到 Google 根，而不是自签的"未知根"。
- **内置自动化后端。** 模块 zip 现内置 [Tricky Addon Enhanced](https://github.com/Enginex0/tricky-addon-enhanced) 后端（GPL-3.0，固定 `v5.53.1`，打包时从源码交叉编译 arm64-v8a；见 `.github/ta-enhanced.json`）。安装后它作为守护进程运行在引擎旁边，自动化 keybox 轮换（Yurikey / KOW / 自定义）、安全补丁日期、VBHash 伪装、基于 inotify 的目标列表管理与冲突报告，还能在管理器的模块描述里实时显示状态。全部功能在自带 WebUI 中控制（⋮ 菜单 → **Enhanced**）。它对冲突模块只报告、绝不自动删除。

## 它做什么

部分 Android 应用拒绝在已 root 的手机上运行。它们要求手机证明自己仍拥有真实的安全芯片——这叫硬件认证（hardware attestation）。已 root 的手机通常过不了这道检查。

TEESimulator 让它通过。Android 里有一个系统进程 `keystore2` 负责应答这类证明请求。TEESimulator 站在 `keystore2` 前面，监视 app 创建密钥、读取证书的请求，并自己构建证明：一条由你的 `keybox.xml` 签名的完整证书链。在 app 眼里，这台手机就是正版。

它完全取代 TrickyStore 及其各 fork。配置文件路径与 TrickyStore 相同，可以直接切换，无需迁移任何数据；但内部实现已全部重写：证书由 Rust 生成、密钥重启后依然有效，且每个 app 都有独立的硬件密钥请求频率限制。

## 环境要求

> [!IMPORTANT]
> 你需要一个有效的 `keybox.xml`——它是给证明签名的文件。没有它，TEESimulator 只能生成软件级证书，严格的应用会拒绝。

1. Android 10 或更新
2. root 管理器：KernelSU、Magisk 或 APatch
3. `keybox.xml` 放在 `/data/adb/tricky_store/keybox.xml`

## 快速开始

1. 从 [Releases](https://github.com/MashiroSann/TEESimulator-RS/releases) 下载最新的 ZIP。
2. 用 root 管理器刷入，然后重启。
3. 把你的 `keybox.xml` 放到 `/data/adb/tricky_store/keybox.xml`。
4. 在 `/data/adb/tricky_store/target.txt` 里列出要覆盖的 app——或点模块的 Action 按钮打开内置 WebUI。
5. 用 Play Integrity 或 Key Attestation Demo 验证效果。

## 工作原理

```
   App（应用）
    |  要求手机证明自己有真实的安全硬件
    v
+----------------------------------------------------+
| keystore2（负责应答的 Android 系统进程）             |
|                                                    |
|   ioctl  <- TEESimulator 在这里挂钩                 |
|     |                                              |
|     v                                              |
|   构建证书链并用你的 keybox.xml 签名                |
+----------------------------------------------------+
    |  签好的证书链返回给 app
    v
   App  ->  看到的是一台真实的、硬件加密的设备
```

**Rust 证书生成。** 原生库 `libcertgen.so` 用 Rust + `ring` 加密库构建 X.509 证书链，并按标准证书格式 DER 手工编码字节。三种密钥类型超出 `ring` 的支持范围（P-224、P-521、Curve25519 曲线），这些会回退到 Java 的 BouncyCastle。

**挂钩 keystore2。** 在 `keystore2` 进程内，TEESimulator 重定向 `ioctl`——Android 用于进程间通信的底层系统调用——使用 `lsplt` 挂钩库完成。由此可以读取并应答三类请求：创建密钥、导入密钥、获取密钥证书。

**对齐原生 Android。** 输出与真实设备一致：未认证的密钥得到自签名证书；认证记录里的字段保持相同顺序；只在特定 Android 版本存在的字段只在那些版本出现；密钥使用前执行同样的用途检查。

**密钥重启持久化。** 生成的密钥写入磁盘，重启后依然有效。文件锁防止两个写入者破坏密钥库。

**每应用频率限制。** 每个 app 每 30 秒最多请求 2 把硬件密钥，同时最多持有 2 把。超限后返回软件级证书。

## 配置

所有配置文件位于 `/data/adb/tricky_store/`。TEESimulator 在你保存的瞬间就会重新加载，无需重启。

### target.txt

列出 TEESimulator 处理的 app，每行一个包名。后缀决定处理方式：

| 后缀 | 行为 |
|--------|--------------|
| `!` | 总是生成软件密钥 |
| `?` | 保留真实硬件密钥，仅修补其证书 |
| 无 | 自动决定 |

使用多个 keybox 时，在对应 app 上方加 `[文件名.xml]` 头：

```
com.google.android.gms!
io.github.vvb2060.keyattestation?

[aosp_keybox.xml]
com.google.android.gsf
```

### security_patch.txt

设置认证证书里报告的安全补丁日期。全局默认写在顶部；用 `[包名]` 头为单个 app 覆盖。

| 键 | 设置的对象 |
|-----|--------------|
| `system` | OS 补丁级别 |
| `vendor` | Vendor 补丁级别 |
| `boot` | Boot 与内核补丁级别 |
| `all` | 三者同时 |

可接受的值：`today`、`YYYY-MM-DD` 模板、`no`（省略该字段）、`device_default`、`prop`（读取系统属性值）。

```
system=YYYY-MM-05
vendor=device_default
boot=no

[com.google.android.gms]
system=2025-10-01
```

### boot_props_mode

控制全局 `ro.boot.*` 属性伪装。取值：`auto`（默认）、`force`、`disable`。

在 `auto` 下，Oplus 系设备（一加/OPPO/realme/Oplus）跳过 boot 状态属性伪装，避免与厂商 TEE 服务（如超声波指纹校准）冲突。创建 `/data/adb/tricky_store/boot_props_mode` 写入 `force` 可恢复旧行为；任何设备写入 `disable` 可关闭该伪装。

## 从源码构建

需要 JDK 21、Android SDK 与 NDK 29、Rust（stable，含 `aarch64-linux-android` target）和 `cargo-ndk`。

```bash
git clone --recursive https://github.com/MashiroSann/TEESimulator-RS.git
cd TEESimulator-RS
cd webui && pnpm install --frozen-lockfile && pnpm run build && cd ..   # 输出 module/webroot
./gradlew zipRelease zipDebug
```

ZIP 产物在 `out/`。Gradle 会自动调用 `cargo ndk` 交叉编译 `libcertgen.so`，原生库只构建 `arm64-v8a`。内置 WebUI 是 `webui/` 下的 Vite/TypeScript 应用（需要 Node.js 20+ 和 pnpm），必须先构建再打包，否则 `customize.sh` 会因缺少 `webroot/index.html` 而中止。也可以用 CI 构建：推送到 `main` 或运行 Actions > Build > Run workflow。

Windows 上可用 `build-module.ps1`，它固定了 JDK、SDK、NDK、Rust 和 Node 工具链路径，包含 WebUI 在内完成同样的构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\build-module.ps1              # Release + Debug
powershell -ExecutionPolicy Bypass -File .\build-module.ps1 -ReleaseOnly # 仅 Release
powershell -ExecutionPolicy Bypass -File .\build-module.ps1 -SkipWebui   # 复用 module\webroot
```

## 自动上游同步与发版

本 fork 用 GitHub Actions 跟踪两个上游，并固定一个内置后端：

- [Enginex0/TEESimulator-RS](https://github.com/Enginex0/TEESimulator-RS) —— 本 fork 基于的核心模拟器。
- [KOWX712/Tricky-Addon-Update-Target-List](https://github.com/KOWX712/Tricky-Addon-Update-Target-List) —— 捆绑的 `webui/` 源码与支持文件。
- [Enginex0/tricky-addon-enhanced](https://github.com/Enginex0/tricky-addon-enhanced) —— 内置自动化后端，pin 记录在 `.github/ta-enhanced.json`。打包时按固定 commit 拉取源码并交叉编译；每日检查发现上游发布新版本时会提醒升级 pin。

| 工作流 | 触发方式 | 作用 |
|---|---|---|
| `Build` | 推送到 `main`（模块相关路径）、PR、手动 | 仅编译检查——构建 WebUI、内置后端与模块 zip，不发布 |
| `Check Upstream Updates` | 每日定时 + 手动 | 上游有新提交或后端有新版本时开/更新 `upstream-sync` issue；全部同步后自动关闭 |
| `Sync Upstreams` | **手动** | 将两个上游合并到重建的 `debug` 分支并构建，开/更新到 `main` 的 PR，发布 pre-release（`v6.0.1-<n>-pre`，含 Release + Debug zip） |
| `Release` | **手动**（从 `main`） | 构建 `main`，发布 latest 正式版，并把重新生成的 `module/update.json` 以 `[skip ci]` 提交回去 |

版本号规则为 `v6.0.1-<提交数 + 5>`；tag、zip 内版本号与 `module/update.json` 三者始终一致。只有正式发版才会修改 `module/update.json`，pre-release 不会进入用户的更新通道。

### 同步流程

1. Actions → **Sync Upstreams** → Run workflow。`dry_run` 只构建并推送草稿 `debug` 分支，不开 PR、不发 pre-release。
2. 工作流合并 Enginex0（`.github/**`、`build-module.ps1`、`module/update.json` 等仓库自有文件冲突时取本 fork 版本），并 overlay 同步 Tricky Addon：`webui/` 与 `module` 支持文件直接复制，六个定制过的 `webui` 源文件做三方合并。其他位置出现冲突则终止运行。
3. 构建通过后，审阅 PR 与 pre-release，需要真机验证就刷 pre-release zip，然后合并 PR。
4. Actions → **Release** → Run workflow 发布正式版（标记 Latest）。

发布日志分两节——`### TEESimulator-RS 更新` 与 `### Tricky Addon 更新`——只在对应上游确实有新提交时输出。

### 出问题时怎么办

- 冲突或构建失败会开/更新一个带 `upstream-sync` 标签的 issue 并附运行链接；`main` 与更新通道永远不受影响。
- 重试：修复原因（或在 `debug` 分支上解决冲突），再运行 **Sync Upstreams**。
- 撤回 pre-release：`gh release delete v6.0.1-<n>-pre --yes --cleanup-tag`，必要时关闭对应 PR。
- 正式版：对已存在的 tag 重跑 `Release` 是无操作；要替换请先删除 release 和 tag 再重跑。

## 兼容性

| Root 管理器 | 状态 |
|---|---|
| KernelSU | 已测试，包括 Action 按钮与生命周期脚本 |
| Magisk | 支持 |
| APatch | 支持 |

## 社区

<p align="center">
  <a href="https://t.me/superpowers9">
    <img src="https://img.shields.io/badge/SuperPowers_Telegram-Join-blue?style=for-the-badge&logo=telegram" alt="Telegram">
  </a>
</p>

## 致谢

- [JingMatrix](https://github.com/JingMatrix/TEESimulator) —— 原版 TEESimulator 与其拦截设计
- [KOWX712](https://github.com/KOWX712/Tricky-Addon-Update-Target-List) —— 捆绑的 Tricky Addon WebUI（Apache-2.0）
- [Enginex0](https://github.com/Enginex0/tricky-addon-enhanced) —— 本 fork 内置的 Tricky Addon Enhanced 后端（GPL-3.0）
- [ring](https://github.com/briansmith/ring) —— Rust 加密库
- [fatalcoder524](https://github.com/fatalcoder524) —— 贡献与协作
- [huguangares](https://github.com/huguangares) —— 贡献与测试

## 许可证

[GNU General Public License v3.0](LICENSE)
