# shellcheck disable=SC2034
SKIPUNZIP=1
MIN_SDK=29
CONFIG_DIR=/data/adb/tricky_store

# --- Installation Context Check ---
if [ "$BOOTMODE" != true ]; then
  ui_print "! Please install in Magisk Manager or KernelSU Manager"
  abort "! Install from recovery is NOT supported"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "! Please update your KernelSU and KernelSU Manager"
fi

# --- Version Info ---
VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "- Installing TEESimulator-RS $VERSION"
ui_print ""

# --- Architecture Handling ---
case "$ARCH" in
  arm64) ABI_DIR="arm64-v8a" ;;
  arm)   ABI_DIR="armeabi-v7a" ;;
  x64)   ABI_DIR="x86_64" ;;
  x86)   ABI_DIR="x86" ;;
  *)     abort "! Unsupported architecture: $ARCH" ;;
esac

ui_print "- Device platform: $ARCH"
ui_print "- Using ABI dir: $ABI_DIR"

# --- SDK Check ---
if [ "$API" -lt "$MIN_SDK" ]; then
  abort "! Unsupported SDK: $API. Minimum required is $MIN_SDK"
else
  ui_print "- Device SDK: $API"
fi
ui_print ""

# --- Helper to install files ---
install_file() {
  if ! unzip -qqjo "$ZIPFILE" "$1" -d "$2"; then
    abort "! Failed to extract $1"
  fi
  ui_print "- Extracted $1"
}

# --- Installation ---
ui_print "- Extracting module files"
for file in customize.sh module.prop service.sh sepolicy.rule daemon action.sh action_i18n.sh prop.sh uninstall.sh; do
  install_file "$file" "$MODPATH"
done

# Handle service.apk or classes.dex
if unzip -l "$ZIPFILE" | grep -q "service.apk"; then
  install_file "service.apk" "$MODPATH"
elif unzip -l "$ZIPFILE" | grep -q "classes.dex"; then
  install_file "classes.dex" "$MODPATH"
else
  abort "! Neither service.apk nor classes.dex found"
fi

chmod 755 "$MODPATH/daemon"
chmod 755 "$MODPATH/prop.sh"
ui_print ""

# Bundled Tricky Addon WebUI (built by `pnpm build` in webui/ before packaging).
# KSUWebUIStandalone / WebUI X load <module>/webroot/index.html.
mkdir -p "$MODPATH/webroot"
unzip -qqo "$ZIPFILE" "webroot/*" -d "$MODPATH" 2>/dev/null
if [ ! -f "$MODPATH/webroot/index.html" ]; then
  abort "! WebUI payload missing from the zip (build webui/ before packaging)"
fi
chmod -R 755 "$MODPATH/webroot"
ui_print "- Bundled WebUI extracted"

# Tricky Addon support files: AOSP keybox blob + xposed scan backend.
mkdir -p "$MODPATH/common"
unzip -qqjo "$ZIPFILE" "common/.default" "common/get_extra.sh" -d "$MODPATH/common" 2>/dev/null
if [ -f "$MODPATH/common/get_extra.sh" ]; then
  chmod 755 "$MODPATH/common/get_extra.sh"
fi
ui_print "- Support files extracted"
ui_print ""

ui_print "- Extracting $ARCH libraries"
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
  ui_print "- Debug diagnostic plane enabled"
else
  rm -rf /data/media/0/TEESimulator /data/local/tmp/teesim
  ui_print "- Release build: swept stale diagnostics"
fi

# --- Configuration Files ---
if [ ! -d "$CONFIG_DIR" ]; then
  ui_print "- Creating configuration directory"
  mkdir -p "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/keybox.xml" ]; then
  ui_print "- Adding AOSP software keybox"
  install_file "keybox.xml" "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/target.txt" ]; then
  ui_print "- Adding default target scope"
  install_file "target.txt" "$CONFIG_DIR"
fi

if [ ! -f "$CONFIG_DIR/security_patch.txt" ]; then
  ui_print "- Adding default security patch config (mirror device props)"
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
  ui_print "- Generating device-unique hardware-bound key seed"
  head -c 32 /dev/random > "$CONFIG_DIR/hbk"
fi

# --- Embedded Tricky Addon Enhanced backend (arm64-v8a only) -----------------
# Built from pinned sources at packaging time; see .github/ta-enhanced.json.
# The backend attaches to this module's config dir (/data/adb/tricky_store)
# and is controlled from the WebUI's Enhanced panel.
TAENH_DIR="$MODPATH/taenh"
TAENH_BIN="$TAENH_DIR/arm64-v8a/ta-enhanced"
if [ "$ARCH" != "arm64" ]; then
  ui_print "- Enhanced backend skipped (arm64-v8a only)"
elif ! unzip -l "$ZIPFILE" | grep -q "taenh/arm64-v8a/ta-enhanced"; then
  ui_print "! Enhanced backend missing from zip (built without backend?)"
else
  ui_print ""
  ui_print "- Installing Tricky Addon Enhanced backend"
  unzip -qqo "$ZIPFILE" "taenh/*" -d "$MODPATH" 2>/dev/null
  chmod -R 755 "$TAENH_DIR"

  if ! "$TAENH_BIN" version >/dev/null 2>&1; then
    ui_print "! Enhanced backend failed to run; skipping its setup"
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
        ui_print "- VBHash captured from bootloader"
      fi
    fi

    # Automation decision: an existing target list is preserved as-is and
    # automatic target management is left off.
    if [ -f "$CONFIG_DIR/target.txt" ] && [ -s "$CONFIG_DIR/target.txt" ]; then
      ui_print "- Detected existing target list; automatic target management is OFF"
      ui_print "  (检测到 target list，自动管理已关闭)"
      _automation=0
    else
      ui_print "- No target list found; enabling automatic target management"
      _automation=1
    fi

    if [ ! -f "$TA_STATE/config.toml" ]; then
      "$TAENH_BIN" config init --automation="$_automation" 2>/dev/null \
        || ui_print "! config init failed; daemon will create defaults at first run"
      # Instant crash-restarts stay with the engine supervisor; the enhanced
      # health monitor can be enabled from the WebUI Enhanced panel.
      "$TAENH_BIN" config set health.enabled false 2>/dev/null || true
    else
      "$TAENH_BIN" config set automation.enabled "$_automation" 2>/dev/null || true
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

    # Initial target generation (reuses the upstream installer helpers).
    if [ "$_automation" = "1" ] && [ -f "$TAENH_DIR/install_func.sh" ]; then
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

    if [ ! -f "$CONFIG_DIR/keybox.xml" ]; then
      if timeout 3 ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        ui_print "- Fetching keybox"
        _kb_ok=0
        for _attempt in 1 2 3; do
          if timeout 5 "$TAENH_BIN" keybox fetch 2>/dev/null; then _kb_ok=1; break; fi
          sleep 1
        done
        [ "$_kb_ok" = "1" ] || ui_print "! Keybox fetch failed (daemon retries at boot)"
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
      ui_print "! Conflicting modules detected (NOT removed):$_conflicts"
      ui_print "  Remove them manually, or enable auto-remove in the WebUI Enhanced panel."
    else
      ui_print "- No conflicting modules detected"
    fi

    ui_print "- Enhanced backend installed (target management: $([ "$_automation" = 1 ] && echo ON || echo OFF))"
  fi
fi
