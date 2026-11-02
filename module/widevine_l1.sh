#!/system/bin/sh
# Widevine L1 restore for unlocked-bootloader Qualcomm devices
# (Nothing / OPPO / OnePlus / Realme and similar). Unlocking the bootloader
# switches these phones to an alternate keystore that carries no attestation
# key, so the TEE refuses to provision and Widevine drops to L3. Installing an
# attestation key into that alternate keystore lets provisioning hand out an L1
# key again. Method and keybox from the public tutorial:
#   https://xdaforums.com/t/fix-widevine-l1-unlocked-bootloader.4731374/
# The KmInstallKeybox tool ships on the supported devices themselves (stock),
# so this only runs where it is present.
#
# WARNING: enrolling the key into the alternate keystore is PERMANENT. It
# survives root removal and re-unlocking and, per the tutorial, cannot be
# reverted even by flashing. The WebUI only triggers --run behind an explicit
# confirmation; this script never runs on its own.

case "$0" in
    */*) MODPATH=$(cd "${0%/*}" 2>/dev/null && pwd) ;;
    *)   MODPATH="$PWD" ;;
esac
[ -z "$MODPATH" ] && MODPATH="$PWD"
[ -f "$MODPATH/module.prop" ] || MODPATH=/data/adb/modules/tricky_store

KEYBOX="$MODPATH/widevine_l1_attestation.xml"
TMP=/data/local/tmp/attestation
LDP=/vendor/lib64/hw:/vendor/lib/hw

# Locate the stock KmInstallKeybox tool. Bare name first (it is normally on the
# PATH of supported devices), then the usual vendor/system/odm bins.
find_tool() {
    if command -v KmInstallKeybox >/dev/null 2>&1; then
        echo KmInstallKeybox; return 0
    fi
    for p in /vendor/bin/KmInstallKeybox /system/bin/KmInstallKeybox \
             /odm/bin/KmInstallKeybox /vendor/bin/hw/KmInstallKeybox; do
        [ -x "$p" ] && { echo "$p"; return 0; }
    done
    return 1
}

case "$1" in
    --check)
        # Report whether this device can run the fix, for the WebUI to gate on.
        plat=$(getprop ro.board.platform 2>/dev/null)
        if [ ! -f "$KEYBOX" ]; then
            echo "unsupported: attestation keybox missing"; exit 1
        fi
        tool=$(find_tool) || { echo "unsupported: KmInstallKeybox not present (needs a stock Qualcomm keystore tool)"; exit 1; }
        echo "supported: $tool platform=$plat"
        ;;
    --run)
        tool=$(find_tool) || { echo "ERROR: KmInstallKeybox not present on this device"; exit 1; }
        [ -f "$KEYBOX" ] || { echo "ERROR: attestation keybox missing"; exit 1; }
        cp -f "$KEYBOX" "$TMP" 2>/dev/null || { echo "ERROR: cannot stage keybox to $TMP"; exit 1; }
        chmod 600 "$TMP" 2>/dev/null
        # Second arg "attestation" is the DeviceID inside the keybox.
        out=$(LD_LIBRARY_PATH="$LDP" "$tool" "$TMP" attestation true 2>&1)
        rc=$?
        rm -f "$TMP" 2>/dev/null
        [ -n "$out" ] && echo "$out"
        if echo "$out" | grep -qi "done"; then
            echo "RESULT: ok"
        elif echo "$out" | grep -q -- "-2000"; then
            # Documented as normal on some devices; the install still takes.
            echo "RESULT: ok (-2000 is expected on some devices)"
        elif [ "$rc" = 0 ]; then
            echo "RESULT: ok"
        else
            echo "RESULT: failed (rc=$rc)"
        fi
        ;;
    *)
        echo "usage: widevine_l1.sh --check|--run"; exit 2 ;;
esac
