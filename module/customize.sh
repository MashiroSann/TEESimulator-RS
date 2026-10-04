# shellcheck disable=SC2034
SKIPUNZIP=1
MIN_SDK=29
CONFIG_DIR=/data/adb/tricky_store

# --- Installer localization ---------------------------------------------------
# English is the fallback; Chinese is used when the device locale is zh*.
# Messages are printf templates consumed through `msg KEY [args...]`.
_ui_locale=$(getprop persist.sys.locale 2>/dev/null)
[ -z "$_ui_locale" ] && _ui_locale=$(getprop ro.product.locale 2>/dev/null)
[ -z "$_ui_locale" ] && _ui_locale=${LANG:-}
case "$_ui_locale" in
  zh*) _ui_lang=zh ;;
  *)   _ui_lang=en ;;
esac

if [ "$_ui_lang" = "zh" ]; then
  MSG_NEED_MGR="! 请在 Magisk / KernelSU 管理器中安装"
  MSG_NO_RECOVERY="! 不支持从 recovery 安装"
  MSG_UPDATE_KSU="! 请先更新 KernelSU 及管理器"
  MSG_INSTALLING="- 正在安装 TEESimulator-RS %s"
  MSG_PLATFORM="- 设备架构: %s"
  MSG_ABI="- 使用 ABI: %s"
  MSG_SDK="- 设备 SDK: %s"
  MSG_BAD_ARCH="! 不支持的架构: %s"
  MSG_BAD_SDK="! 不支持的 SDK: %s（最低要求 %s）"
  MSG_PKG_EXTRACT="- 正在解包模块文件"
  MSG_FAIL_EXTRACT="! 解包失败: %s"
  MSG_EXTRACTED="- 已解包 %s"
  MSG_NO_DEX="! 未找到 service.apk 或 classes.dex"
  MSG_WEBUI_OK="- 内置 WebUI 已解包"
  MSG_WEBUI_MISS="! zip 中缺少 WebUI 内容（打包前需先构建 webui/）"
  MSG_SUPPORT_OK="- 支持文件已解包"
  MSG_LIBS="- 正在解包 %s 库"
  MSG_DEBUG_ON="- 已启用调试诊断组件"
  MSG_RELEASE_SWEPT="- Release 版: 已清理残留诊断文件"
  MSG_MKDIR="- 正在创建配置目录"
  MSG_AOSP_KB="- 正在添加 AOSP 软件 keybox"
  MSG_DEF_TARGET="- 正在添加默认目标列表"
  MSG_DEF_SP="- 正在添加默认安全补丁配置（跟随设备属性）"
  MSG_HBK="- 正在生成设备唯一硬件绑定密钥种子"
  MSG_ENH_SKIP="- 已跳过增强后端（仅支持 arm64-v8a）"
  MSG_ENH_NOENH="- 此安装包不含增强后端（NoEnhanced）"
  MSG_ENH_MISS="! zip 中缺少增强后端（构建未包含？）"
  MSG_ENH_INSTALL="- 正在安装 Tricky Addon Enhanced 后端"
  MSG_ENH_FAIL="! 增强后端无法运行；跳过其配置"
  MSG_VBHASH="- 已从 bootloader 捕获 VBHash"
  MSG_TARGET_OFF="- 检测到现有目标列表；自动维护已关闭"
  MSG_TARGET_ON="- 未发现目标列表；启用自动目标维护"
  MSG_INIT_FAIL="! config init 失败；daemon 将在首次运行时创建默认配置"
  MSG_CFG_KEPT="- 保留现有增强配置（目标维护: %s）"
  MSG_FETCH_KB="- 正在获取 keybox"
  MSG_KB_FAIL="! keybox 获取失败（daemon 将在开机后重试）"
  MSG_CONFLICTS="! 检测到冲突模块（不会自动移除）:%s"
  MSG_CONFLICTS_HINT="  请手动移除，或在 WebUI 增强面板中启用自动移除"
  MSG_NO_CONFLICTS="- 未检测到冲突模块"
  MSG_ENH_DONE="- 增强后端安装完成（目标维护: %s）"
  MSG_ON="开"
  MSG_OFF="关"
else
  MSG_NEED_MGR="! Please install in Magisk Manager or KernelSU Manager"
  MSG_NO_RECOVERY="! Install from recovery is NOT supported"
  MSG_UPDATE_KSU="! Please update your KernelSU and KernelSU Manager"
  MSG_INSTALLING="- Installing TEESimulator-RS %s"
  MSG_PLATFORM="- Device platform: %s"
  MSG_ABI="- Using ABI dir: %s"
  MSG_SDK="- Device SDK: %s"
  MSG_BAD_ARCH="! Unsupported architecture: %s"
  MSG_BAD_SDK="! Unsupported SDK: %s (minimum required is %s)"
  MSG_PKG_EXTRACT="- Extracting module files"
  MSG_FAIL_EXTRACT="! Failed to extract %s"
  MSG_EXTRACTED="- Extracted %s"
  MSG_NO_DEX="! Neither service.apk nor classes.dex found"
  MSG_WEBUI_OK="- Bundled WebUI extracted"
  MSG_WEBUI_MISS="! WebUI payload missing from the zip (build webui/ before packaging)"
  MSG_SUPPORT_OK="- Support files extracted"
  MSG_LIBS="- Extracting %s libraries"
  MSG_DEBUG_ON="- Debug diagnostic plane enabled"
  MSG_RELEASE_SWEPT="- Release build: swept stale diagnostics"
  MSG_MKDIR="- Creating configuration directory"
  MSG_AOSP_KB="- Adding AOSP software keybox"
  MSG_DEF_TARGET="- Adding default target scope"
  MSG_DEF_SP="- Adding default security patch config (mirror device props)"
  MSG_HBK="- Generating device-unique hardware-bound key seed"
  MSG_ENH_SKIP="- Enhanced backend skipped (arm64-v8a only)"
  MSG_ENH_NOENH="- This package does not include the enhanced backend (NoEnhanced)"
  MSG_ENH_MISS="! Enhanced backend missing from zip (built without backend?)"
  MSG_ENH_INSTALL="- Installing Tricky Addon Enhanced backend"
  MSG_ENH_FAIL="! Enhanced backend failed to run; skipping its setup"
  MSG_VBHASH="- VBHash captured from bootloader"
  MSG_TARGET_OFF="- Detected existing target list; automatic target management is OFF"
  MSG_TARGET_ON="- No target list found; enabling automatic target management"
  MSG_INIT_FAIL="! config init failed; daemon will create defaults at first run"
  MSG_CFG_KEPT="- Existing enhanced config kept (target management: %s)"
  MSG_FETCH_KB="- Fetching keybox"
  MSG_KB_FAIL="! Keybox fetch failed (daemon retries at boot)"
  MSG_CONFLICTS="! Conflicting modules detected (NOT removed):%s"
  MSG_CONFLICTS_HINT="  Remove them manually, or enable auto-remove in the WebUI Enhanced panel."
  MSG_NO_CONFLICTS="- No conflicting modules detected"
  MSG_ENH_DONE="- Enhanced backend installed (target management: %s)"
  MSG_ON="ON"
  MSG_OFF="OFF"
fi

msg() {
  _msg_key=$1
  shift
  eval "_msg_tpl=\${MSG_$_msg_key}"
  # A template that starts with "-" would be parsed as a printf option, so
  # the "- "/"! " marker is printed separately with a constant format.
  case "$_msg_tpl" in
    "- "*) _msg_mark="-"; _msg_tpl=${_msg_tpl#- } ;;
    "! "*) _msg_mark="!"; _msg_tpl=${_msg_tpl#! } ;;
    *)     _msg_mark="" ;;
  esac
  if [ -n "$_msg_mark" ]; then
    printf '%s %s' "$_msg_mark" "$(printf "$_msg_tpl" "$@")"
  else
    # shellcheck disable=SC2059
    printf "$_msg_tpl" "$@"
  fi
}

# --- Installation Context Check ---
if [ "$BOOTMODE" != true ]; then
  ui_print "$(msg NEED_MGR)"
  abort "$(msg NO_RECOVERY)"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "$(msg UPDATE_KSU)"
fi

# --- Version Info ---
VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "$(msg INSTALLING "$VERSION")"
ui_print ""

# --- Architecture Handling ---
case "$ARCH" in
  arm64) ABI_DIR="arm64-v8a" ;;
  arm)   ABI_DIR="armeabi-v7a" ;;
  x64)   ABI_DIR="x86_64" ;;
  x86)   ABI_DIR="x86" ;;
  *)     abort "$(msg BAD_ARCH "$ARCH")" ;;
esac

ui_print "$(msg PLATFORM "$ARCH")"
ui_print "$(msg ABI "$ABI_DIR")"

# --- SDK Check ---
if [ "$API" -lt "$MIN_SDK" ]; then
  abort "$(msg BAD_SDK "$API" "$MIN_SDK")"
else
  ui_print "$(msg SDK "$API")"
fi
ui_print ""

# --- Helper to install files ---
install_file() {
  if ! unzip -qqjo "$ZIPFILE" "$1" -d "$2"; then
    abort "$(msg FAIL_EXTRACT "$1")"
  fi
  ui_print "$(msg EXTRACTED "$1")"
}

# --- Installation ---
ui_print "$(msg PKG_EXTRACT)"
for file in customize.sh module.prop service.sh sepolicy.rule daemon action.sh action_i18n.sh prop.sh uninstall.sh; do
  install_file "$file" "$MODPATH"
done

# Handle service.apk or classes.dex
if unzip -l "$ZIPFILE" | grep -q "service.apk"; then
  install_file "service.apk" "$MODPATH"
elif unzip -l "$ZIPFILE" | grep -q "classes.dex"; then
  install_file "classes.dex" "$MODPATH"
else
  abort "$(msg NO_DEX)"
fi

chmod 755 "$MODPATH/daemon"
chmod 755 "$MODPATH/prop.sh"
ui_print ""

# Bundled Tricky Addon WebUI (built by `pnpm build` in webui/ before packaging).
# KSUWebUIStandalone / WebUI X load <module>/webroot/index.html.
mkdir -p "$MODPATH/webroot"
unzip -qqo "$ZIPFILE" "webroot/*" -d "$MODPATH" 2>/dev/null
if [ ! -f "$MODPATH/webroot/index.html" ]; then
  abort "$(msg WEBUI_MISS)"
fi
chmod -R 755 "$MODPATH/webroot"
ui_print "$(msg WEBUI_OK)"

# Tricky Addon support files: AOSP keybox blob + xposed scan backend.
mkdir -p "$MODPATH/common"
unzip -qqjo "$ZIPFILE" "common/.default" "common/get_extra.sh" -d "$MODPATH/common" 2>/dev/null
if [ -f "$MODPATH/common/get_extra.sh" ]; then
  chmod 755 "$MODPATH/common/get_extra.sh"
fi
ui_print "$(msg SUPPORT_OK)"
ui_print ""

ui_print "$(msg LIBS "$ARCH")"
install_file "lib/$ABI_DIR/libTEESimulator.so" "$MODPATH"
install_file "lib/$ABI_DIR/libinject.so" "$MODPATH"
install_file "lib/$ABI_DIR/libsupervisor.so" "$MODPATH"
install_file "lib/$ABI_DIR/libcertgen.so" "$MODPATH"
ui_print ""

mv "$MODPATH/libinject.so" "$MODPATH/inject"
mv "$MODPATH/libsupervisor.so" "$MODPATH/supervisor"
chmod 755 "$MODPATH/inject"
chmod 755 "$MODPATH/supervisor"

# Debug builds carry diag.sh (the diagnostic plane); release builds do not. Extract it when
# present; otherwise sweep any external-storage diagnostics a prior debug install left behind,
# since the release keystore domain has no grant to remove them itself.
# Detect presence by the extracted FILE, not unzip's exit code: the busybox/toybox unzip in
# the install environment exits 0 even when the entry is absent, so the sweep never ran.
unzip -qqjo "$ZIPFILE" "diag.sh" -d "$MODPATH" 2>/dev/null
if [ -f "$MODPATH/diag.sh" ]; then
  chmod 644 "$MODPATH/diag.sh"
  ui_print "$(msg DEBUG_ON)"
else
  rm -rf /data/media/0/TEESimulator /data/local/tmp/teesim
  ui_print "$(msg RELEASE_SWEPT)"
fi

# --- Configuration Files ---
if [ ! -d "$CONFIG_DIR" ]; then
  ui_print "$(msg MKDIR)"
  mkdir -p "$CONFIG_DIR"
fi

# Snapshot the pre-install state. The default files extracted below would
# otherwise mask it: the shipped target.txt has entries, and an AOSP
# keybox.xml is always installed when missing.
_TA_HAD_KEYBOX=0; [ -f "$CONFIG_DIR/keybox.xml" ] && _TA_HAD_KEYBOX=1
_TA_HAD_TARGET=0; [ -s "$CONFIG_DIR/target.txt" ] && _TA_HAD_TARGET=1

if [ ! -f "$CONFIG_DIR/keybox.xml" ]; then
  ui_print "$(msg AOSP_KB)"
  install_file "keybox.xml" "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/target.txt" ]; then
  ui_print "$(msg DEF_TARGET)"
  install_file "target.txt" "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/security_patch.txt" ]; then
  ui_print "$(msg DEF_SP)"
  printf '%s\n' \
    '# TEESimulator default: mirror live device props.' \
    '# system=prop reads ro.build.version.security_patch at cert-gen time;' \
    '# boot and vendor are auto-forced to prop too (ConfigurationManager.kt:253-256).' \
    '# Override with explicit YYYY-MM-DD dates if you want active spoofing.' \
    'system=prop' > "$CONFIG_DIR/security_patch.txt"
  chmod 644 "$CONFIG_DIR/security_patch.txt"
fi

rm -f "$CONFIG_DIR/tee_status.txt"

if [ ! -f "$CONFIG_DIR/hbk" ]; then
  ui_print "$(msg HBK)"
  head -c 32 /dev/random > "$CONFIG_DIR/hbk"
fi

# --- Embedded Tricky Addon Enhanced backend (arm64-v8a only) -----------------
# Built from pinned sources at packaging time; see .github/ta-enhanced.json.
# The backend attaches to this module's config dir (/data/adb/tricky_store)
# and is controlled from the WebUI's Enhanced panel.
#
# Note: install_func.sh (upstream, sha256-pinned) prints its own progress in
# English and is intentionally left untouched.
TAENH_DIR="$MODPATH/taenh"
TAENH_BIN="$TAENH_DIR/arm64-v8a/ta-enhanced"

# The NoEnhanced build intentionally ships without module/taenh and drops a
# marker so the absence is reported as a variant, not as a broken build.
unzip -qqjo "$ZIPFILE" ".noenhanced" -d "$MODPATH" 2>/dev/null
_NOENH=0; [ -f "$MODPATH/.noenhanced" ] && _NOENH=1
rm -f "$MODPATH/.noenhanced"

if [ "$ARCH" != "arm64" ]; then
  ui_print "$(msg ENH_SKIP)"
elif ! unzip -l "$ZIPFILE" | grep -q "taenh/arm64-v8a/ta-enhanced"; then
  if [ "$_NOENH" = "1" ]; then
    ui_print "$(msg ENH_NOENH)"
  else
    ui_print "$(msg ENH_MISS)"
  fi
else
  ui_print ""
  ui_print "$(msg ENH_INSTALL)"
  unzip -qqo "$ZIPFILE" "taenh/*" -d "$MODPATH" 2>/dev/null
  chmod -R 755 "$TAENH_DIR"

  if ! "$TAENH_BIN" version >/dev/null 2>&1; then
    ui_print "$(msg ENH_FAIL)"
    rm -rf "$TAENH_DIR"
  else
    TA_STATE="$CONFIG_DIR/ta-enhanced"
    mkdir -p "$TA_STATE/logs" "$TA_STATE/bin"

    # VBHash: capture the bootloader digest before any module can tamper with it.
    _vbhash=$(getprop ro.boot.vbmeta.digest 2>/dev/null \
      | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | grep -oE '^[a-f0-9]{64}$')
    if [ -n "$_vbhash" ]; then
      _old_hash=""
      [ -f "/data/adb/boot_hash" ] && _old_hash=$(cat /data/adb/boot_hash 2>/dev/null)
      if [ "$_vbhash" != "$_old_hash" ]; then
        echo "$_vbhash" > /data/adb/boot_hash.tmp && mv -f /data/adb/boot_hash.tmp /data/adb/boot_hash
        chmod 644 /data/adb/boot_hash
        ui_print "$(msg VBHASH)"
      fi
    fi

    # Automation decision. Only a first-time setup derives it from the target
    # list (an existing list is preserved and automatic management left off);
    # reinstalls keep whatever the user configured in the WebUI panel.
    if [ ! -f "$TA_STATE/config.toml" ]; then
      if [ "$_TA_HAD_TARGET" = "1" ]; then
        ui_print "$(msg TARGET_OFF)"
        _automation=0
      else
        ui_print "$(msg TARGET_ON)"
        _automation=1
      fi
      "$TAENH_BIN" config init --automation="$_automation" 2>/dev/null \
        || ui_print "$(msg INIT_FAIL)"
      # Instant crash-restarts stay with the engine supervisor; the enhanced
      # health monitor can be enabled from the WebUI Enhanced panel.
      "$TAENH_BIN" config set health.enabled false 2>/dev/null || true
    else
      _automation=$("$TAENH_BIN" config get automation.enabled 2>/dev/null)
      case "$_automation" in
        true|1) _automation=1 ;;
        *)      _automation=0 ;;
      esac
      ui_print "$(msg CFG_KEPT "$([ "$_automation" = 1 ] && echo "$MSG_ON" || echo "$MSG_OFF")")"
    fi

    # Region snapshot (only when unset; never overwrite user overrides).
    if [ -z "$("$TAENH_BIN" config get region.hwc 2>/dev/null)" ]; then
      for pair in \
        "region.hwc:ro.boot.hwc" \
        "region.hwcountry:ro.boot.hwcountry" \
        "region.mod_device:ro.product.mod_device" \
        "region.hardware_sku:ro.boot.product.hardware.sku"; do
        _k=${pair%%:*}; _p=${pair#*:}
        _v=$(getprop "$_p" 2>/dev/null)
        [ -n "$_v" ] && "$TAENH_BIN" config set "$_k" "$_v" 2>/dev/null
      done
    fi

    # resetprop-rs is published where the daemon expects it.
    cp -f "$TAENH_DIR/arm64-v8a/resetprop-rs" "$TA_STATE/bin/resetprop-rs" 2>/dev/null || true
    chmod 755 "$TA_STATE/bin/resetprop-rs" 2>/dev/null || true

    # Initial target generation (reuses the upstream installer helpers). Only
    # for a fresh setup where automation was just switched on -- regenerating
    # on reinstall would overwrite a curated list.
    if [ "$_TA_HAD_TARGET" = "0" ] && [ "$_automation" = "1" ] && [ -f "$TAENH_DIR/install_func.sh" ]; then
      cp -f "$TAENH_DIR/more-exclude.json" "$MODPATH/more-exclude.json" 2>/dev/null || true
      # shellcheck disable=SC1090
      . "$TAENH_DIR/install_func.sh"
      build_exclude_list 2>/dev/null || true
      generate_initial_target 2>/dev/null || true
      rm -f "$MODPATH/more-exclude.json"
    fi

    # Security patch dates are intentionally left as-is on (re)install: the
    # backend applies them per its own config (security_patch.auto_update /
    # custom_date) from the daemon at boot. A forced bulletin refresh here
    # used to clobber the user's chosen date on every reinstall.

    # First install only: try to fetch a real keybox to replace the AOSP
    # default that was extracted above. (Checking the file directly would
    # never fire, the default is always present by this point.)
    if [ "$_TA_HAD_KEYBOX" = "0" ]; then
      if timeout 3 ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        ui_print "$(msg FETCH_KB)"
        _kb_ok=0
        for _attempt in 1 2 3; do
          if timeout 5 "$TAENH_BIN" keybox fetch 2>/dev/null; then _kb_ok=1; break; fi
          sleep 1
        done
        [ "$_kb_ok" = "1" ] || ui_print "$(msg KB_FAIL)"
      fi
    fi

    # Conflict scan (report only; this fork never removes other modules).
    _conflicts=""
    for _mod in Yamabukiko TA_utl .TA_utl Yurikey xiaocaiye safetynet-fix \
      vbmeta-fixer playintegrity integrity_box SukiSU_module Reset_BootHash \
      Tricky_store-bm Hide_Bootloader ShamikoManager extreme_hide_root \
      Tricky_Store-xiaoyi tricky_store_assistant extreme_hide_bootloader \
      wjw_hiderootauxiliarymod PlayIntegrityFork; do
      [ -d "/data/adb/modules/$_mod" ] && _conflicts="$_conflicts $_mod"
    done
    if [ -n "$_conflicts" ]; then
      ui_print "$(msg CONFLICTS "$_conflicts")"
      ui_print "$(msg CONFLICTS_HINT)"
    else
      ui_print "$(msg NO_CONFLICTS)"
    fi

    ui_print "$(msg ENH_DONE "$([ "$_automation" = 1 ] && echo "$MSG_ON" || echo "$MSG_OFF")")"
  fi
fi
