#!/system/bin/sh
MODDIR=${0%/*}
CONFIG_DIR=/data/adb/tricky_store

# Kill daemon and supervisor
for pid in $(pidof TEESimulator) $(pidof supervisor) $(pidof daemon) $(pidof ta-enhanced); do
    kill -9 "$pid" 2>/dev/null
done

# Stop the embedded Tricky Addon Enhanced backend gracefully and clean its
# engine-side state. keybox.xml / target.txt are user data and are preserved.
TA_STATE="$CONFIG_DIR/ta-enhanced"
if [ -f "$TA_STATE/daemon.pid" ]; then
    _ta_pid=$(cat "$TA_STATE/daemon.pid" 2>/dev/null)
    # Only signal the PID when /proc/<pid>/exe still points at our backend;
    # a stale PID file after a reboot may reference an unrelated process.
    if [ -n "$_ta_pid" ] && [ "$(readlink "/proc/$_ta_pid/exe" 2>/dev/null)" = "$MODDIR/taenh/arm64-v8a/ta-enhanced" ]; then
        kill "$_ta_pid" 2>/dev/null
    fi
fi
if [ -x "$MODDIR/taenh/arm64-v8a/ta-enhanced" ]; then
    "$MODDIR/taenh/arm64-v8a/ta-enhanced" daemon-stop >/dev/null 2>&1 || true
fi
rm -rf "$TA_STATE"
rm -rf "$CONFIG_DIR/.automation"
rm -f "$CONFIG_DIR/.health_state" "$CONFIG_DIR/system_app" "$CONFIG_DIR/target_from_denylist"
rm -f /data/adb/boot_hash

rm -rf "$CONFIG_DIR/persistent_keys"
rm -f "$CONFIG_DIR/tee_status.txt"
rm -f "$CONFIG_DIR/boot_hash.bin" "$CONFIG_DIR/boot_key.bin"
rm -f "$CONFIG_DIR/security_patch.txt" "$CONFIG_DIR/security_patch.txt.next" "$CONFIG_DIR/last_bulletin_fetch.json"

# Debug diagnostics live on external storage; remove them on uninstall.
rm -rf /data/media/0/TEESimulator
