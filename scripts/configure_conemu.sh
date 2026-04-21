#!/usr/bin/env bash
set -euo pipefail
#
# Apply required ConEmu settings for Cursor Agent compatibility.
#
# Settings applied:
#   FixFarBorders    = OFF  (let font render box-drawing chars, not GDI)
#   EnhanceGraphics  = OFF  (stop replacing Unicode with ConEmu graphics)
#   chcp 65001             (UTF-8 console code page in EnvironmentSet)
#   WSL task: native wsl.exe (WSL2) + ConEmu console flags
#

CONEMU_XML="/mnt/c/Users/skyle/AppData/Roaming/ConEmu.xml"
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

  # ProcessAnsi: 00 → 01 (required for cursor/erase sequences used by Ink)
  if grep -q '"ProcessAnsi" type="hex" data="00"' "$CONEMU_XML"; then
    sed -i 's/\("ProcessAnsi" type="hex" data="\)00"/\101"/' "$CONEMU_XML"
    echo "FIX   ProcessAnsi → ON"
    changed=1
  fi

  # chcp 65001 in EnvironmentSet
  if ! grep -q 'chcp 65001' "$CONEMU_XML"; then
    sed -i '/"EnvironmentSet" type="multi"/a\\t\t\t\t<line data="chcp 65001"/>' "$CONEMU_XML"
    echo "FIX   chcp 65001 added to EnvironmentSet"
    changed=1
  fi

  # Ensure Connector flag (p) is present on WSL task
  if grep -q 'cur_console:m:/mnt' "$CONEMU_XML" && ! grep -q 'cur_console:pm:/mnt' "$CONEMU_XML"; then
    sed -i 's/cur_console:m:\/mnt/cur_console:pm:\/mnt/g' "$CONEMU_XML"
    echo "FIX   WSL task: Connector mode (p flag) restored"
    changed=1
  fi

  # Ensure {Bash::bash} task uses native wsl.exe (WSL2-supported path)
  if python3 - "$CONEMU_XML" <<'PY'
import re, sys
from pathlib import Path

xml_path = Path(sys.argv[1])
text = xml_path.read_text(encoding="utf-8", errors="surrogatepass")

desired = r'wsl.exe -cur_console:pm:/mnt ~'

lines = text.splitlines(True)
out = []
in_task7 = False
changed = False

for line in lines:
    if '<key name="Task7"' in line:
        in_task7 = True
        out.append(line)
        continue
    if in_task7 and '</key>' in line:
        in_task7 = False
        out.append(line)
        continue
    if in_task7 and 'name="Cmd1"' in line and 'type="string"' in line:
        # Preserve indentation
        indent = re.match(r'^(\s*)', line).group(1)
        new_line = f'{indent}<value name="Cmd1" type="string" data="{desired}"/>\n'
        if new_line != line:
            changed = True
        out.append(new_line)
        continue
    out.append(line)

if changed:
    xml_path.write_text("".join(out), encoding="utf-8", errors="surrogatepass")
    sys.exit(0)
sys.exit(1)
PY
  then
    echo "FIX   WSL task: native wsl.exe"
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
}

echo "── ConEmu configuration ──"

if [[ "${1:-}" == "--offline" ]]; then
  patch_xml
  exit 0
fi

# Runtime: apply what we can via GuiMacro, then patch XML for persistence
if apply_runtime_guimacro 2>/dev/null; then
  patch_xml 2>/dev/null || true
else
  patch_xml
fi
