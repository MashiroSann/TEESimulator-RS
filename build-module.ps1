#Requires -Version 5.1
<#
.SYNOPSIS
    TEESimulator-RS 模块编译脚本（已含 "TEE 伪造(2)" 修复）。

.DESCRIPTION
    本脚本固定使用 G:\workenvironment 下的工具链，不依赖系统 PATH / 环境变量漂移：
      JDK 21 / Android SDK(platform 36 + build-tools 36 + NDK 27.3.13750724) /
      GNU host Rust 工具链 + cargo-ndk / Gradle 9.2（缓存于 gradle-home）
    修复对应源码：
      - KeyMintSecurityLevelInterceptor.kt : generateKey 拒绝 PURPOSE_ATTEST_KEY 混合用途（回 -3）
      - KeyMintSecurityLevelInterceptor.kt : 锻造异常不再一律压成 -49，SSE 错误码原样透传
      - SoftwareOperation.kt               : 修正 INCOMPATIBLE_PURPOSE / UNSUPPORTED_PURPOSE 兜底值

    产物：out\TEESimulator-RS-<版本>-<commit>-Release-Enhanced.zip（含增强后端）
          以及同名的 -Release-NoEnhanced.zip（不含增强后端）；默认同时编 Debug 的两种。

.PARAMETER ReleaseOnly
    只编 Release（默认 Release + Debug 都编）。

.PARAMETER Clean
    先执行 gradlew clean（全量重编，耗时较长）。

.PARAMETER Daemon
    允许使用常驻 Gradle 守护进程（默认 --no-daemon，环境隔离更可控）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build-module.ps1

.EXAMPLE
    # 只编 Release
    powershell -ExecutionPolicy Bypass -File .\build-module.ps1 -ReleaseOnly
#>
[CmdletBinding()]
param(
    [switch]$ReleaseOnly,
    [switch]$Clean,
    [switch]$Daemon,
    [switch]$SkipFetch,
    [switch]$SkipWebui,
    [switch]$SkipTaEnhanced,
    [switch]$NoProxy,
    [string]$JdkHome    = 'G:\workenvironment\jdk-21',
    [string]$SdkRoot    = 'G:\workenvironment\android-sdk',
    [string]$RustRoot   = 'G:\workenvironment\rust',
    [string]$GradleHome = 'G:\workenvironment\gradle-home',
    [string]$NodeRoot   = 'G:\workenvironment\nodejs',
    [string]$HttpProxy  = 'http://127.0.0.1:20721'
)

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
if (-not $projectRoot) { $projectRoot = (Get-Location).Path }

function Say { param([string]$Msg, [string]$Color = 'Gray') Write-Host $Msg -ForegroundColor $Color }

# ============================ 1. 环境固定 ============================

$env:JAVA_HOME        = $JdkHome
$env:ANDROID_HOME     = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:ANDROID_NDK_HOME = Join-Path $SdkRoot 'ndk\27.3.13750724'
$env:GRADLE_USER_HOME = $GradleHome
$env:CARGO_HOME       = Join-Path $RustRoot 'cargo'
$env:RUSTUP_HOME      = Join-Path $RustRoot 'rustup'
# 覆盖 native-certgen\rust-toolchain.toml 的 "stable"，防止 rustup 解析成 msvc 后现场下载
$env:RUSTUP_TOOLCHAIN   = 'stable-x86_64-pc-windows-gnu'
$env:RUSTUP_AUTO_INSTALL = '0'
# crates.io 下载容错：慢速连接不轻易判死、自动重试
$env:CARGO_HTTP_TIMEOUT          = '120'
$env:CARGO_HTTP_LOW_SPEED_LIMIT  = '1'
$env:CARGO_HTTP_MULTIPLEXING     = 'false'
$env:CARGO_NET_RETRY             = '10'
# 工具链置于 PATH 最前，避免命中其它位置的 rustup/cargo/node
$env:Path = $NodeRoot + ';' +
            (Join-Path $env:CARGO_HOME 'bin') + ';' +
            (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:Path

Say "项目根目录 : $projectRoot" 'Cyan'
Say "JAVA_HOME  : $env:JAVA_HOME"
Say "ANDROID_HOME: $env:ANDROID_HOME"
Say "GRADLE_HOME : $env:GRADLE_USER_HOME"
Say "RUST        : $env:CARGO_HOME ($env:RUSTUP_TOOLCHAIN)"

# ============================ 2. 预检 ============================

$missing = @()
$checks = @(
    @{ N = 'JDK 21';            P = (Join-Path $env:JAVA_HOME 'bin\java.exe') },
    @{ N = 'Android platform 36'; P = (Join-Path $SdkRoot 'platforms\android-36\android.jar') },
    @{ N = 'build-tools 36';    P = (Join-Path $SdkRoot 'build-tools\36.0.0\aapt2.exe') },
    @{ N = 'NDK 27.3';          P = (Join-Path $env:ANDROID_NDK_HOME 'source.properties') },
    @{ N = 'rustup';            P = (Join-Path $env:CARGO_HOME 'bin\rustup.exe') },
    @{ N = 'cargo-ndk';         P = (Join-Path $env:CARGO_HOME 'bin\cargo-ndk.exe') }
)
foreach ($c in $checks) {
    if (Test-Path -LiteralPath $c.P) {
        Say "  [OK] $($c.N)"
    } else {
        Say "  [X]  缺失 $($c.N)：$($c.P)" 'Red'
        $missing += $c.N
    }
}
if (-not $SkipWebui) {
    $webuiChecks = @(
        @{ N = 'Node.js (webui)'; P = (Join-Path $NodeRoot 'node.exe') },
        @{ N = 'pnpm (webui)';    P = (Join-Path $NodeRoot 'pnpm.cmd') }
    )
    foreach ($c in $webuiChecks) {
        if (Test-Path -LiteralPath $c.P) {
            Say "  [OK] $($c.N)"
        } else {
            Say "  [X]  缺失 $($c.N)：$($c.P)" 'Red'
            $missing += $c.N
        }
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'gradlew.bat'))) {
    Say '  [X]  当前目录不是项目根（找不到 gradlew.bat）' 'Red'
    $missing += 'gradlew.bat'
}
if ($missing.Count -gt 0) {
    throw "环境预检失败：$($missing -join '、')。请先运行 G:\workenvironment\scripts\install.ps1 补齐。"
}

# git 历史：build.gradle.kts 用 git rev-list 计算 versionCode
& git -C $projectRoot rev-parse --verify --quiet HEAD | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'git 仓库没有提交历史（versionCode 依赖 git）。请先执行： git init; git add -A; git commit -m init'
}

# Rust target 自检，缺失自动补装
$rustup = Join-Path $env:CARGO_HOME 'bin\rustup.exe'
$installedTargets = @(& $rustup target list --installed)
foreach ($t in @('aarch64-linux-android', 'armv7-linux-androideabi', 'i686-linux-android', 'x86_64-linux-android')) {
    if ($installedTargets -notcontains $t) {
        Say "  [补装] rust target $t" 'Yellow'
        & $rustup target add $t
        if ($LASTEXITCODE -ne 0) { throw "rustup target add $t 失败" }
    }
}
Say '  [OK] rust android targets'

# --- Rust 依赖预取：crates.io 在国内直连很慢（实测约 30 KB/s），放在 Gradle 里
#     会长时间无输出、看起来像卡死；这里单独跑，有进度条、可随时 Ctrl+C 再续传。
if (-not $SkipFetch) {
    Say ''
    Say '==== 预取 Rust 依赖（首次/未下完时会较久，可中断后重跑续传）====' 'Cyan'
    Push-Location (Join-Path $projectRoot 'native-certgen')
    try {
        & (Join-Path $env:CARGO_HOME 'bin\cargo.exe') fetch --locked --target aarch64-linux-android
    } finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0) { throw "cargo fetch 失败（退出码 $LASTEXITCODE）" }
    Say '  [OK] Rust 依赖已就绪（后续构建不会再走 crates.io）'
}

# ============================ 2.5 WebUI 构建 ============================
if (-not $SkipWebui) {
    Say ''
    Say '==== 构建 WebUI（Tricky Addon, vite）====' 'Cyan'
    $webuiDir = Join-Path $projectRoot 'webui'
    if (-not (Test-Path -LiteralPath (Join-Path $webuiDir 'package.json'))) {
        throw '找不到 webui\package.json（-SkipWebui 可跳过 WebUI 构建）'
    }
    Push-Location $webuiDir
    $oldHttp = $env:HTTP_PROXY; $oldHttps = $env:HTTPS_PROXY
    if (-not $NoProxy) { $env:HTTP_PROXY = $HttpProxy; $env:HTTPS_PROXY = $HttpProxy }
    try {
        & (Join-Path $NodeRoot 'pnpm.cmd') install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw "pnpm install 失败（退出码 $LASTEXITCODE）" }
        & (Join-Path $NodeRoot 'pnpm.cmd') run build
        if ($LASTEXITCODE -ne 0) { throw "pnpm build 失败（退出码 $LASTEXITCODE）" }
    } finally {
        Pop-Location
        $env:HTTP_PROXY = $oldHttp; $env:HTTPS_PROXY = $oldHttps
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'module\webroot\index.html'))) {
        throw 'WebUI 构建产物缺失：module\webroot\index.html'
    }
    Say '  [OK] WebUI -> module\webroot' 'Green'
} else {
    Say '  [跳过] WebUI 构建（-SkipWebui），直接使用现有 module\webroot' 'Yellow'
}

# ============================ 2.6 内置增强后端 ============================
# 从固定版本（.github\ta-enhanced.json）的源码构建 Tricky Addon Enhanced
# 的 arm64 后端，落到 module\taenh 供打包进模块 zip。
if (-not $SkipTaEnhanced) {
    Say ''
    Say '==== 构建内置增强后端（Tricky Addon Enhanced, arm64）====' 'Cyan'
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw '找不到 python，无法构建增强后端；可用 -SkipTaEnhanced 跳过。'
    }
    $oldHttp = $env:HTTP_PROXY; $oldHttps = $env:HTTPS_PROXY
    if (-not $NoProxy) { $env:HTTP_PROXY = $HttpProxy; $env:HTTPS_PROXY = $HttpProxy }
    try {
        & python (Join-Path $projectRoot 'scripts\build-ta-enhanced.py')
        if ($LASTEXITCODE -ne 0) { throw "增强后端构建失败（退出码 $LASTEXITCODE）" }
    } finally {
        $env:HTTP_PROXY = $oldHttp; $env:HTTPS_PROXY = $oldHttps
    }
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'module\taenh\arm64-v8a\ta-enhanced'))) {
        throw '增强后端产物缺失：module\taenh\arm64-v8a\ta-enhanced'
    }
    Say '  [OK] 增强后端 -> module\taenh' 'Green'
} else {
    Say '  [跳过] 增强后端（-SkipTaEnhanced），zip 将不包含后端' 'Yellow'
}

# ============================ 3. 编译 ============================

$tasks = @()
if ($Clean) { $tasks += 'clean' }
if ($ReleaseOnly) {
    $tasks += @('zipRelease', 'zipReleaseNoEnhanced')
} else {
    $tasks += @('zipRelease', 'zipDebug', 'zipReleaseNoEnhanced', 'zipDebugNoEnhanced')
}

$gradleArgs = $tasks + @('--console=plain')
if (-not $Daemon) { $gradleArgs += '--no-daemon' }

Say ''
Say ("==== 开始编译：gradlew " + ($tasks -join ' ') + " ====") 'Cyan'
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# 临时放宽 EAP：PS 5.1 下 Gradle 写 stderr 可能抛 NativeCommandError
$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& (Join-Path $projectRoot 'gradlew.bat') @gradleArgs
$buildExit = $LASTEXITCODE
$ErrorActionPreference = $oldEap
$sw.Stop()

if ($buildExit -ne 0) {
    Say ("`n编译失败（退出码 $buildExit，耗时 {0:hh\:mm\:ss}）" -f $sw.Elapsed) 'Red'
    exit $buildExit
}

# ============================ 4. 结果 ============================

Say ''
Say ("==== 编译成功（耗时 {0:hh\:mm\:ss}）====" -f $sw.Elapsed) 'Green'
Say '产物：' 'Green'
$outDir = Join-Path $projectRoot 'out'
Get-ChildItem -LiteralPath $outDir -Filter '*.zip' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5 |
    ForEach-Object { Say ("  " + $_.FullName + "  (" + [math]::Round($_.Length / 1MB, 1) + " MB)") 'Green' }

Say ''
Say '安装到设备（可选）：' 'Cyan'
Say '  adb push out\<zip> /data/local/tmp/'
Say '  adb shell su -c "ksud module install /data/local/tmp/<zip>"   # KernelSU'
Say '  adb shell su -c "magisk --install-module /data/local/tmp/<zip>"  # Magisk'
Say '  重启后复测检测项。'
