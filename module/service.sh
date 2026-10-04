MODDIR=${0%/*}
cd $MODDIR

# Fork-based supervisor for instant restart. Guarded so a re-run of this
# script (e.g. by the enhanced health monitor) does not double-start it.
if ! pidof supervisor >/dev/null 2>&1 && ! pidof TEESimulator >/dev/null 2>&1; then
  ./supervisor ./daemon "$MODDIR" &
fi

# --- Embedded Tricky Addon Enhanced backend (arm64-v8a only) -----------------
TAENH_BIN="$MODDIR/taenh/arm64-v8a/ta-enhanced"
TAENH_PROP="$MODDIR/taenh/prop.sh"
TA_STATE="/data/adb/tricky_store/ta-enhanced"
_ta_ok=0
if [ -x "$TAENH_BIN" ] && [ "$(uname -m)" = "aarch64" ]; then
  _ta_ok=1
fi

# Property handling. The enhanced prop.sh is a superset of the classic one
# (resetprop-rs persistence + LineageOS identity scrub); fall back to the
# classic prop.sh when the backend is unavailable. Both honor the
# /data/adb/disable_prop_handler opt-out.
if [ "$_ta_ok" = "1" ] && [ -f "$TAENH_PROP" ]; then
  mkdir -p "$TA_STATE/bin"
  cp -f "$MODDIR/taenh/arm64-v8a/resetprop-rs" "$TA_STATE/bin/resetprop-rs" 2>/dev/null || true
  chmod 755 "$TA_STATE/bin/resetprop-rs" 2>/dev/null || true
  RP_BIN="$TA_STATE/bin/resetprop-rs" sh "$TAENH_PROP" &
else
  # Sensitive props handling, imported from Tricky Addon (opt out: touch /data/adb/disable_prop_handler)
  sh "$MODDIR/prop.sh" &
fi

# Keep TSupport-A from overwriting the target list maintained by the bundled WebUI
TSPA="/data/adb/modules/tsupport-advance"
if [ -d "$TSPA" ]; then
  touch /storage/emulated/0/stop-tspa-auto-target
elif [ -f /storage/emulated/0/stop-tspa-auto-target ]; then
  rm -f /storage/emulated/0/stop-tspa-auto-target
fi

# Debug builds ship diag.sh; its presence enables the external-storage diagnostic plane.
if [ -f "$MODDIR/diag.sh" ]; then
  . "$MODDIR/diag.sh"
  diag_setup
fi

# Clear logd size persist properties once boot completes
(
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
  done
  setprop persist.logd.size ""
  setprop persist.logd.size.crash ""
  setprop persist.logd.size.system ""
  setprop persist.logd.size.main ""
) &

# Enhanced daemon. Crash-restarts of the engine stay with our own supervisor;
# the enhanced health monitor is off by default and can be enabled from the
# WebUI Enhanced panel.
if [ "$_ta_ok" = "1" ]; then
  if [ -n "$APATCH" ]; then
    MANAGER="APATCH"
  elif [ -n "$KSU" ]; then
    MANAGER="KSU"
  else
    MANAGER="MAGISK"
  fi

  # Boot-completion background tasks (parity with the upstream service).
  (
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
      sleep 5
    done
    pm list packages -s 2>/dev/null | sed 's/^package://' | sort > "$TA_STATE/system_packages.txt" 2>/dev/null
    if [ "$("$TAENH_BIN" config get vbhash.enabled 2>/dev/null)" != "false" ]; then
      "$TAENH_BIN" vbhash extract >/dev/null 2>&1 || true
    fi
    "$TAENH_BIN" conflict check >/dev/null 2>&1 || true
    "$TAENH_BIN" status xposed-scan >/dev/null 2>&1 || true
  ) &

  # Single-instance guard: service.sh can be re-run (health monitor restarts
  # the engine by re-running this script), so only start when none is alive.
  # The daemon camouflages its process name, so pidof cannot see it; verify
  # the recorded PID through /proc/<pid>/exe instead. After a reboot the PID
  # file is stale and kill -0 can succeed on an unrelated recycled PID, so a
  # PID that does not point at our binary is dropped.
  _ta_running=0
  TA_PIDF="$TA_STATE/daemon.pid"
  if [ -f "$TA_PIDF" ]; then
    _ta_pid=$(cat "$TA_PIDF" 2>/dev/null)
    if [ -n "$_ta_pid" ] && [ "$(readlink "/proc/$_ta_pid/exe" 2>/dev/null)" = "$TAENH_BIN" ]; then
      _ta_running=1
    else
      rm -f "$TA_PIDF"
    fi
  fi
  if [ "$_ta_running" = "0" ]; then
    "$TAENH_BIN" daemon --manager "$MANAGER" &
  fi
fi
