#!/bin/sh
# Usage: tools/apply-profile.sh <install|stable|nvidia>
# Copies profiles/<name>.plist to EFI/OC/config.plist, keeping the SMBIOS values
# (serial, MLB, UUID, ROM) of the config.plist that is already there.
set -eu
cd "$(dirname "$0")/.."
P="${1:?usage: $0 install|stable|nvidia}"
SRC="profiles/$P.plist"; DST="EFI/OC/config.plist"
[ -f "$SRC" ] || { echo "no such profile: $P" >&2; exit 1; }
PB=/usr/libexec/PlistBuddy; G=:PlatformInfo:Generic
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$SRC" "$TMP/new.plist"
if [ -f "$DST" ]; then
  for k in SystemSerialNumber MLB SystemUUID; do
    v="$($PB -c "Print $G:$k" "$DST")"; $PB -c "Set $G:$k $v" "$TMP/new.plist"
  done
  plutil -extract PlatformInfo.Generic.ROM raw -o - "$DST" | base64 -D > "$TMP/rom.bin"
  $PB -c "Import $G:ROM $TMP/rom.bin" "$TMP/new.plist"
fi
cp "$TMP/new.plist" "$DST"
echo "applied profile '$P' -> $DST"
[ "$($PB -c "Print $G:SystemSerialNumber" "$DST")" != "CHANGE_ME" ] || echo "WARNING: SMBIOS is still the placeholder. Generate your own (GenSMBIOS, iMacPro1,1) and set serial/MLB/UUID/ROM in $DST before booting." >&2
