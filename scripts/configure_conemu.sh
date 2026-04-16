#!/usr/bin/env bash
set -euo pipefail
#
# Apply required ConEmu settings for Cursor Agent compatibility.
#
# Settings applied:
#   FixFarBorders    = OFF  (let font render box-drawing chars, not GDI)
#   EnhanceGraphics  = OFF  (stop replacing Unicode with ConEmu graphics)
#   chcp 65001             (UTF-8 console code page in EnvironmentSet)
#   WSL task command        (no Connector/p flag — use ConPTY)
#
# The first three can be changed at runtime via GuiMacro. The task command
# can ONLY be changed in the XML when ConEmu is not running, because ConEmu
# overwrites the XML with its in-memory state on exit.

CONEMU_XML="/mnt/c/Users/skyle/AppData/Roaming/ConEmu.xml"
CONEMU_EXE="/mnt/c/Program Files/ConEmu/ConEmu64.exe"
CONEMU_C="/mnt/c/Program Files/ConEmu/ConEmu/ConEmuC64.exe"

patch_xml() {
  [[ -f "$CONEMU_XML" ]] || { echo "SKIP  ConEmu.xml not found"; return 1; }

  local changed=0

  # FixFarBorders: 01 → 00
  if grep -q '"FixFarBorders" type="hex" data="01"' "$CONEMU_XML"; then
    sed -i 's/\("FixFarBorders" type="hex" data="\)01"/\100"/' "$CONEMU_XML"
    echo "FIX   FixFarBorders → OFF"
    changed=1
  fi

  # EnhanceGraphics: 01 → 00
  if grep -q '"EnhanceGraphics" type="hex" data="01"' "$CONEMU_XML"; then
    sed -i 's/\("EnhanceGraphics" type="hex" data="\)01"/\100"/' "$CONEMU_XML"
    echo "FIX   EnhanceGraphics → OFF"
    changed=1
  fi

  # chcp 65001 in EnvironmentSet
  if ! grep -q 'chcp 65001' "$CONEMU_XML"; then
    sed -i '/"EnvironmentSet" type="multi"/a\\t\t\t\t<line data="chcp 65001"/>' "$CONEMU_XML"
    echo "FIX   chcp 65001 added to EnvironmentSet"
    changed=1
  fi

  # WSL task: remove Connector flag (p), keep m:/mnt
  if grep -q 'cur_console:pm:/mnt' "$CONEMU_XML"; then
    sed -i 's/cur_console:pm:\/mnt/cur_console:m:\/mnt/g' "$CONEMU_XML"
    echo "FIX   WSL task: Connector mode (p flag) removed"
    changed=1
  fi

  [[ $changed -eq 0 ]] && echo "OK    ConEmu.xml already correct"
  return 0
}

apply_runtime_guimacro() {
  [[ -x "$CONEMU_C" ]] || return 1

  local pid
  pid="$(powershell.exe -NoProfile -Command \
    '(Get-Process ConEmu64 -ErrorAction SilentlyContinue | Select-Object -First 1).Id' \
    2>/dev/null | tr -d '\r\n')"
  [[ -n "$pid" ]] || return 1

  # cbFixFarBorders=1207, cbEnhanceGraphics=2289 (from resource.h)
  "$CONEMU_C" /GuiMacro:"$pid" SetOption Check 1207 0 >/dev/null 2>&1 || true
  "$CONEMU_C" /GuiMacro:"$pid" SetOption Check 2289 0 >/dev/null 2>&1 || true
  echo "OK    GuiMacro: FixFarBorders=OFF, EnhanceGraphics=OFF"
  echo "$pid"
}

schedule_task_fix() {
  # ConEmu overwrites the XML on exit, undoing our task command edit.
  # This drops a one-shot script that watches for ConEmu to close,
  # patches the XML, then relaunches ConEmu.
  local marker="/tmp/.conemu_task_fix_pending"
  if [[ -f "$marker" ]]; then
    echo "OK    Task fix already scheduled"
    return
  fi

  if ! grep -q 'cur_console:pm:/mnt' "$CONEMU_XML"; then
    echo "OK    WSL task already correct (no Connector flag)"
    return
  fi

  touch "$marker"
  (
    # Wait for ConEmu to exit
    while powershell.exe -NoProfile -Command \
      'if (Get-Process ConEmu64 -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }' \
      2>/dev/null; do
      sleep 2
    done

    sleep 1  # let file handles release

    # Now ConEmu is closed — patch the XML safely
    if [[ -f "$CONEMU_XML" ]] && grep -q 'cur_console:pm:/mnt' "$CONEMU_XML"; then
      sed -i 's/cur_console:pm:\/mnt/cur_console:m:\/mnt/g' "$CONEMU_XML"
    fi

    rm -f "$marker"
  ) &
  disown

  echo "SCHED Task fix: will patch XML and after ConEmu closes"
  echo "      (just close and reopen ConEmu when ready)"
}

echo "── ConEmu configuration ──"

if [[ "${1:-}" == "--offline" ]]; then
  # Direct XML edit — use when ConEmu is NOT running
  patch_xml
  exit 0
fi

# Runtime: apply what we can via GuiMacro
if pid=$(apply_runtime_guimacro 2>/dev/null) && [[ -n "$pid" ]]; then
  # Schedule the task command fix for when ConEmu closes
  schedule_task_fix
else
  # ConEmu not running — edit XML directly
  patch_xml
fi
