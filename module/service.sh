MODDIR=${0%/*}
cd $MODDIR

# Fork-based supervisor for instant restart
./supervisor ./daemon "$MODDIR" &

# Sensitive props handling, imported from Tricky Addon (opt out: touch /data/adb/disable_prop_handler)
sh "$MODDIR/prop.sh" &

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
