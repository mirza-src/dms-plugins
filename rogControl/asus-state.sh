#!/bin/sh
# Dump everything asusd exposes as one JSON line:
#   {available, product, board, vendor, bios, onAc, battery, pendingReboot,
#    platform:{…Platform props}, aura:[{path,props}], slash:[{path,props}],
#    armoury:[{attr,props}], fans:[{profile,curves}]}
# One ObjectManager call returns every object + property; fan curves are the
# only thing that needs extra (method) calls. Then a single jq pass shapes it.
SVC=xyz.ljones.Asusd
DMI=/sys/class/dmi/id
FW=/sys/class/firmware-attributes/asus-armoury/attributes

read_file() { cat "$1" 2>/dev/null; }
product=$(read_file $DMI/product_family)
board=$(read_file $DMI/board_name)
vendor=$(read_file $DMI/sys_vendor)
bios=$(read_file $DMI/bios_version)
onac=true batcap=-1 batstatus=""
for ps in /sys/class/power_supply/*; do
    case "$(read_file "$ps/type")" in
    Mains) [ "$(read_file "$ps/online")" = 1 ] || onac=false ;;
    Battery) [ "$batcap" = -1 ] && batcap=$(read_file "$ps/capacity" || echo -1) && batstatus=$(read_file "$ps/status") ;;
    esac
done
pending=$(read_file $FW/pending_reboot || read_file $FW/pending_reboot/current_value || echo 0)

objects=$(busctl --system -j call "$SVC" / org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null)
[ -n "$objects" ] || objects='{"data":[{}]}'

# Fan curves per platform profile (method call, not a property).
fans=""
for prof in $(printf '%s' "$objects" | jq -r '.data[0]["/xyz/ljones"]["xyz.ljones.Platform"].PlatformProfileChoices.data[]? // empty'); do
    c=$(busctl --system -j call "$SVC" /xyz/ljones xyz.ljones.FanCurves FanCurveData u "$prof" 2>/dev/null) \
        && [ -n "$c" ] && fans="$fans{\"profile\":$prof,\"curves\":$(printf '%s' "$c" | jq -c '.data[0]')},"
done

printf '%s' "$objects" | jq -c \
    --arg p "$product" --arg b "$board" --arg v "$vendor" --arg bi "$bios" \
    --argjson ac "$onac" --argjson bc "${batcap:--1}" --arg bs "$batstatus" --arg pr "$pending" \
    --argjson fans "[${fans%,}]" '
    (.data[0]) as $o
    | def props($iface): [ $o | to_entries[] | select(.value[$iface])
                           | {path: .key, props: (.value[$iface] | map_values(.data))} ];
    {
      available: ($o | length > 0),
      product: $p, board: $b, vendor: $v, bios: $bi,
      onAc: $ac, battery: {capacity: $bc, status: $bs},
      pendingReboot: ($pr == "1"),
      platform: (($o["/xyz/ljones"]["xyz.ljones.Platform"] // {}) | map_values(.data)),
      aura: (props("xyz.ljones.Aura") | sort_by(.path)),
      slash: (props("xyz.ljones.Slash") | sort_by(.path)),
      armoury: [ props("xyz.ljones.AsusArmoury")[] | {attr: (.path | split("/") | last), props} ] | sort_by(.attr),
      fans: $fans
    }'
