#!/usr/bin/env bash
set -euo pipefail
#
# Apply required ConEmu settings for Cursor Agent compatibility.
# Run from WSL while ConEmu is open, or standalone against the XML.
#
# Settings applied:
#   FixFarBorders    = OFF  (let font render box-drawing chars, not GDI)
#   EnhanceGraphics  = OFF  (stop replacing Unicode with ConEmu graphics)
#   chcp 65001             (UTF-8 console code page in EnvironmentSet)
#   WSL task command        (no Connector/p flag — use ConPTY)

CONEMU_XML="/mnt/c/Users/skyle/AppData/Roaming/ConEmu.xml"

apply_via_guimacro() {
  local conemu_c="/mnt/c/Program Files/ConEmu/ConEmu/ConEmuC64.exe"
  [[ -x "$conemu_c" ]] || return 1

  local pid
  pid="$(powershell.exe -NoProfile -Command \
    '(Get-Process ConEmu64 -ErrorAction SilentlyContinue | Select-Object -First 1).Id' \
    2>/dev/null | tr -d '\r\n')"
  [[ -n "$pid" ]] || return 1

  # cbFixFarBorders=1207, cbEnhanceGraphics=2289 (from resource.h)
  "$conemu_c" /GuiMacro:"$pid" SetOption Check 1207 0 >/dev/null 2>&1
  "$conemu_c" /GuiMacro:"$pid" SetOption Check 2289 0 >/dev/null 2>&1
  echo "OK    GuiMacro: FixFarBorders=OFF, EnhanceGraphics=OFF (pid $pid)"
  return 0
}

apply_via_xml() {
  [[ -f "$CONEMU_XML" ]] || { echo "SKIP  ConEmu.xml not found at $CONEMU_XML"; return 1; }

  local tmp
  tmp="$(mktemp)"
  cp "$CONEMU_XML" "$tmp"

  # FixFarBorders: 01 → 00
  sed -i 's/\(<value name="FixFarBorders" type="hex" data="\)01"/\100"/' "$tmp"
  # EnhanceGraphics: 01 → 00
  sed -i 's/\(<value name="EnhanceGraphics" type="hex" data="\)01"/\100"/' "$tmp"

  # Ensure chcp 65001 is in EnvironmentSet (idempotent)
  if ! grep -q 'chcp 65001' "$tmp"; then
    sed -i '/<value name="EnvironmentSet" type="multi">/a\\t\t\t\t<line data="chcp 65001"/>' "$tmp"
  fi

  # WSL task: remove Connector flag (p) if present, keep m:/mnt
  sed -i 's/wsl\.exe -cur_console:pm:\/mnt/wsl.exe -cur_console:m:\/mnt/g' "$tmp"

  if diff -q "$CONEMU_XML" "$tmp" >/dev/null 2>&1; then
    echo "OK    ConEmu.xml already correct"
    rm "$tmp"
  else
    cp "$tmp" "$CONEMU_XML"
    rm "$tmp"
    echo "OK    ConEmu.xml updated (close ConEmu fully before reopening)"
  fi
}

echo "── ConEmu configuration ──"

if apply_via_guimacro 2>/dev/null; then
  echo "       (GuiMacro applied to running instance; XML also updated for persistence)"
fi

apply_via_xml
