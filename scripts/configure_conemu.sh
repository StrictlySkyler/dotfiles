#!/usr/bin/env bash
set -euo pipefail
#
# Apply required ConEmu settings for Cursor Agent compatibility.
# Run from WSL while ConEmu is open, or standalone against the XML.
#
# Settings applied:
#   FixFarBorders   = OFF  (let font render box-drawing chars, not GDI)
#   EnhanceGraphics = OFF  (stop replacing Unicode with ConEmu graphics)
#   ProcessAnsi     = OFF  (ConPTY handles ANSI; double-processing garbles scrolling)
#   chcp 65001             (UTF-8 console code page in EnvironmentSet)
#   ConPTY flag (p)        (explicit ConPTY for WSL tasks - prevents
#                           double-processing of VT scroll regions)
#
# Override the XML path with CONEMU_XML=/path/to/ConEmu.xml if needed.

CONEMU_XML="${CONEMU_XML:-}"

resolve_conemu_xml() {
  if [[ -n "$CONEMU_XML" && -f "$CONEMU_XML" ]]; then
    return 0
  fi

  local appdata_win appdata_wsl candidate

  appdata_win="$(powershell.exe -NoProfile -Command \
    '[Environment]::GetFolderPath("ApplicationData")' \
    2>/dev/null | tr -d '\r')"
  if [[ -n "$appdata_win" ]] && command -v wslpath >/dev/null 2>&1; then
    appdata_wsl="$(wslpath -u "$appdata_win" 2>/dev/null || true)"
    if [[ -n "$appdata_wsl" && -f "$appdata_wsl/ConEmu.xml" ]]; then
      CONEMU_XML="$appdata_wsl/ConEmu.xml"
      return 0
    fi
  fi

  for candidate in /mnt/c/Users/*/AppData/Roaming/ConEmu.xml; do
    [[ -f "$candidate" ]] || continue
    CONEMU_XML="$candidate"
    return 0
  done

  return 1
}

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
  resolve_conemu_xml || { echo "SKIP  ConEmu.xml not found"; return 1; }

  local status
  status="$(python3 - "$CONEMU_XML" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
original = text

for old_val, new_val in [
    ('name="FixFarBorders" type="hex" data="01"',
     'name="FixFarBorders" type="hex" data="00"'),
    ('name="EnhanceGraphics" type="hex" data="01"',
     'name="EnhanceGraphics" type="hex" data="00"'),
    ('name="ProcessAnsi" type="hex" data="01"',
     'name="ProcessAnsi" type="hex" data="00"'),
]:
    text = text.replace(old_val, new_val)

# Ensure WSL -cur_console and -new_console flags include ConPTY (p).
# Only touch lines containing "wsl" to avoid modifying cmd.exe directives.
# Also fix split directives like "-cur_console:p -cur_console:d:" into
# a single combined "-cur_console:pd:" (ConEmu expects one directive).
def _fix_wsl_line(line):
    if 'wsl' not in line.lower():
        return line
    # Merge split directives: -cur_console:p -cur_console:XY -> -cur_console:pXY
    line = re.sub(
        r'-(?:cur_console|new_console):p\s+-(?:cur_console|new_console):([a-zA-Z])',
        lambda m: '-cur_console:p' + m.group(1),
        line,
    )
    # Add p flag if missing from any -cur_console/-new_console directive
    def _add_p(m):
        prefix, flags = m.group(1), m.group(2)
        return prefix + flags if 'p' in flags else prefix + 'p' + flags
    return re.sub(r'(-(?:cur_console|new_console):)([a-zA-Z]*)', _add_p, line)

text = '\n'.join(_fix_wsl_line(l) for l in text.split('\n'))

if 'chcp 65001' not in text:
    env_header = '<value name="EnvironmentSet" type="multi">'
    env_line = '\t\t\t\t<line data="chcp 65001"/>\n'
    if env_header in text:
        text = text.replace(env_header + '\n', env_header + '\n' + env_line, 1)
    else:
        match = re.search(r'(\s*<value name="AutoReloadEnvironment"[^>]+/>\n)', text)
        if not match:
            raise SystemExit("Unable to locate AutoReloadEnvironment in ConEmu.xml")
        insertion = (
            match.group(1)
            + '\t\t\t<value name="EnvironmentSet" type="multi">\n'
            + env_line
            + '\t\t\t</value>\n'
        )
        text = text[:match.start()] + insertion + text[match.end():]

if text == original:
    print("unchanged")
else:
    path.write_text(text)
    print("updated")
PY
)"

  echo "INFO  ConEmu.xml -> $CONEMU_XML"
  if [[ "$status" == "unchanged" ]]; then
    echo "OK    ConEmu.xml already correct"
  else
    echo "OK    ConEmu.xml updated (close ConEmu fully before reopening)"
  fi
}

echo "-- ConEmu configuration --"

if apply_via_guimacro 2>/dev/null; then
  echo "       (GuiMacro applied to running instance; XML also updated for persistence)"
fi

apply_via_xml
