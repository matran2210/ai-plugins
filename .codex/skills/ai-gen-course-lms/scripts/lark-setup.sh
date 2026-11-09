#!/usr/bin/env bash
# Khai báo LARK_APP_ID và LARK_APP_SECRET cho MCP server `lark`, lưu ở MÁY người
# dùng. Codex dùng ~/.codex/config.toml; Claude Code dùng ~/.claude/settings.json.
#
#   lark-setup.sh --check          kiểm tra đã có chưa. Exit 0 = có, 1 = thiếu.
#   lark-setup.sh --gui            mở hộp thoại nhập, ghi vào settings người dùng.
#   lark-setup.sh                  như --gui, nhưng máy không có GUI thì hỏi ngay
#                                  tại terminal (dành cho người dùng tự chạy).
#   lark-setup.sh --host <host>    ép host: codex hoặc claude (mặc định: tự dò).
#   lark-setup.sh --settings <file>   ghi vào file khác (để test)
#
# Agent CHỈ được gọi --check và --gui. Bản trần cho phép nhập qua terminal, mà
# stdin lúc đó là stream agent kiểm soát — App Secret không được đi đường đó.
#
# Claude Code: ghi vào khối "env" của ~/.claude/settings.json.
# Codex: ghi vào [mcp_servers.lark.env] của ~/.codex/config.toml.
#
# BÍ MẬT LƯU DẠNG PLAINTEXT trong file settings — đúng như mọi biến môi trường
# khác. File được chmod 600. Đừng commit file settings chứa secret.
#
# Sau khi ghi phải KHỞI ĐỘNG LẠI host: tiến trình MCP đang chạy giữ môi trường cũ.

set -uo pipefail

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

MODE=set GUI_ONLY=0 SETTINGS="" HOST=auto
while [ $# -gt 0 ]; do
  case "$1" in
    --check)    MODE=check; shift ;;
    --gui)      MODE=set; GUI_ONLY=1; shift ;;
    --host)     [ $# -ge 2 ] || die "--host cần codex hoặc claude"
                HOST="$2"; shift 2 ;;
    --settings) [ $# -ge 2 ] || die "--settings cần một giá trị"
                SETTINGS="$2"; shift 2 ;;
    -h|--help)  awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
                exit 0 ;;
    -*)         die "cờ không nhận: $1" ;;
    *)          shift ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "thiếu lệnh 'jq'"

detect_host() {
  case "$HOST" in
    codex|claude) printf '%s\n' "$HOST"; return ;;
    auto) ;;
    *) die "--host chỉ nhận codex hoặc claude" ;;
  esac

  # Ưu tiên dấu hiệu tường minh từ môi trường của host.
  if [ -n "${CODEX_HOME:-}" ] || [ -n "${CODEX_THREAD_ID:-}" ]; then
    printf 'codex\n'; return
  fi
  if [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ] || [ -n "${CLAUDECODE:-}" ]; then
    printf 'claude\n'; return
  fi

  # IDE/agent thường không truyền biến nhận diện xuống shell, nên dò cây process.
  if command -v ps >/dev/null 2>&1; then
    pid=$PPID
    hops=0
    while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$hops" -lt 12 ]; do
      proc=$(ps -p "$pid" -o command= 2>/dev/null || true)
      case "$proc" in
        *codex*|*openai.chatgpt*|*ChatGPT.app*) printf 'codex\n'; return ;;
        *claude*)                           printf 'claude\n'; return ;;
      esac
      next=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
      [ -n "$next" ] && [ "$next" != "$pid" ] || break
      pid=$next
      hops=$((hops + 1))
    done
  fi

  # Chạy tay: vị trí cài skill là tín hiệu cuối cùng; giữ Claude làm fallback cũ.
  case "$0" in
    */.codex/*)  printf 'codex\n' ;;
    */.claude/*) printf 'claude\n' ;;
    *)           printf 'claude\n' ;;
  esac
}

HOST=$(detect_host)
case "$HOST" in
  codex)
    SETTINGS="${SETTINGS:-${CODEX_HOME:-$HOME/.codex}/config.toml}"
    SETTINGS_FORMAT=toml
    ;;
  claude)
    SETTINGS="${SETTINGS:-$HOME/.claude/settings.json}"
    SETTINGS_FORMAT=json
    ;;
esac

# --settings thường dùng trong test; phần mở rộng cho phép test đúng định dạng.
case "$SETTINGS" in
  *.toml) SETTINGS_FORMAT=toml ;;
  *.json) SETTINGS_FORMAT=json ;;
esac

# Giá trị đến từ hai nguồn. Claude Code nạp khối "env" của settings file ĐÈ LÊN
# biến shell trước khi khởi chạy MCP server — nên ở đây settings cũng phải thắng,
# để cái script báo đúng bằng cái MCP server thật sự nhận.
read_from_settings() {
  [ -r "$SETTINGS" ] || return 1
  if [ "$SETTINGS_FORMAT" = json ]; then
    jq -r --arg k "$1" '.env[$k] // empty' "$SETTINGS" 2>/dev/null
    return
  fi

  awk -v key="$1" '
    /^\[mcp_servers\.lark\.env\][[:space:]]*$/ { inside=1; next }
    /^\[/ { inside=0 }
    inside && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      line=$0
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*\\\"", "", line)
      sub("\\\"[[:space:]]*(#.*)?$", "", line)
      gsub(/\\\\\"/, "\"", line)
      gsub(/\\\\\\\\/, "\\", line)
      print line
      exit
    }
  ' "$SETTINGS"
}

ID=$(read_from_settings LARK_APP_ID || true)
SECRET=$(read_from_settings LARK_APP_SECRET || true)
[ -n "$ID" ]     || ID="${LARK_APP_ID:-}"
[ -n "$SECRET" ] || SECRET="${LARK_APP_SECRET:-}"

# Che giá trị khi in: chỉ lộ 4 ký tự đầu, đủ để người dùng nhận ra mình khai gì.
mask() { printf '%s' "$1" | cut -c1-4 | tr -d '\n'; printf '…(%d ký tự)' "${#1}"; }

if [ "$MODE" = check ]; then
  bad=0
  if [ -n "$ID" ]; then printf '  ✓ LARK_APP_ID: %s\n' "$(mask "$ID")"
  else printf '  ✗ LARK_APP_ID: chưa khai\n'; bad=1; fi
  if [ -n "$SECRET" ]; then printf '  ✓ LARK_APP_SECRET: %s\n' "$(mask "$SECRET")"
  else printf '  ✗ LARK_APP_SECRET: chưa khai\n'; bad=1; fi
  if [ "$bad" = 0 ]; then
    printf '\n=== ĐÃ KHAI BÁO === (%s)\n' "$SETTINGS"
    exit 0
  fi
  printf '\n=== THIẾU KHAI BÁO ===\nChạy: %s --gui\n' "$0"
  exit 1
fi

# ---------------------------------------------------------------- nhập giá trị --
# prompt đi qua argv nên nội dung không chèn được vào mã AppleScript.
mac_ask() {
  if [ "$2" = 1 ]; then
    osascript - "$1" 2>/dev/null <<'AS'
on run argv
	set d to display dialog (item 1 of argv) default answer "" with hidden answer with title "Lark App" buttons {"Hủy", "OK"} default button "OK"
	return text returned of d
end run
AS
  else
    osascript - "$1" 2>/dev/null <<'AS'
on run argv
	set d to display dialog (item 1 of argv) default answer "" with title "Lark App" buttons {"Hủy", "OK"} default button "OK"
	return text returned of d
end run
AS
  fi
}

case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin)               PLATFORM=macos ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) if command -v powershell.exe >/dev/null 2>&1; then PLATFORM=windows
     else PLATFORM=tty; fi ;;
esac

case "$PLATFORM" in
  macos)
    ID=$(mac_ask "Lark App ID (bắt đầu bằng cli_):" 0) || die "đã hủy"
    [ -n "$ID" ] || die "chưa nhập App ID"
    SECRET=$(mac_ask "Lark App Secret của $ID:" 1) || die "đã hủy"
    [ -n "$SECRET" ] || die "chưa nhập App Secret"
    ;;
  windows)
    # Get-Credential: ô UserName = App ID, ô Password = App Secret (ẩn ký tự).
    out=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '
      $c = Get-Credential -Message "Lark App: nhập App ID và App Secret"
      if (-not $c) { exit 1 }
      Write-Output ("ID " + $c.UserName)
      Write-Output ("SECRET " + $c.GetNetworkCredential().Password)' 2>/dev/null | tr -d '\r') \
      || die "đã hủy hoặc không chạy được PowerShell"
    ID=$(printf '%s\n' "$out" | sed -n 's/^ID //p' | head -n1)
    SECRET=$(printf '%s\n' "$out" | sed -n 's/^SECRET //p' | head -n1)
    [ -n "$ID" ] && [ -n "$SECRET" ] || die "chưa nhập đủ App ID và App Secret"
    ;;
  tty)
    [ "$GUI_ONLY" = 0 ] || {
      if [ "$SETTINGS_FORMAT" = toml ]; then
        hint="thêm LARK_APP_ID và LARK_APP_SECRET vào [mcp_servers.lark.env] của $SETTINGS"
      else
        hint="thêm LARK_APP_ID và LARK_APP_SECRET vào khối \"env\" của $SETTINGS"
      fi
      die "máy này không có hộp thoại đồ hoạ.
Khai bằng tay: $hint"
    }
    printf 'Lark App ID: ' >&2;      IFS= read -r ID
    printf 'Lark App Secret: ' >&2;  stty -echo 2>/dev/null; IFS= read -r SECRET
    stty echo 2>/dev/null; printf '\n' >&2
    [ -n "$ID" ] && [ -n "$SECRET" ] || die "chưa nhập đủ"
    ;;
esac

case "$ID" in
  cli_*) ;;
  *) printf '  ⚠️  App ID không bắt đầu bằng "cli_" — kiểm lại xem có dán nhầm không\n' >&2 ;;
esac

# ------------------------------------------------------------------- ghi file --
mkdir -p "$(dirname "$SETTINGS")" || die "không tạo được thư mục cho $SETTINGS"
tmp="$SETTINGS.tmp.$$"

if [ "$SETTINGS_FORMAT" = json ]; then
  [ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
  jq -e . "$SETTINGS" >/dev/null 2>&1 \
    || die "$SETTINGS không phải JSON hợp lệ — sửa tay rồi chạy lại, đừng để script ghi đè"
  jq --arg id "$ID" --arg sec "$SECRET" \
    '.env = ((.env // {}) + {LARK_APP_ID: $id, LARK_APP_SECRET: $sec})' \
    "$SETTINGS" > "$tmp" || { rm -f "$tmp"; die "không ghi được $SETTINGS"; }
else
  [ -f "$SETTINGS" ] || : > "$SETTINGS"
  # Merge đúng section TOML, giữ nguyên toàn bộ cấu hình Codex khác.
  LARK_SETUP_ID="$ID" LARK_SETUP_SECRET="$SECRET" awk '
    function escaped(value) {
      gsub(/\\/, "\\\\", value)
      gsub(/\"/, "\\\"", value)
      return value
    }
    function credentials() {
      print "LARK_APP_ID = \"" escaped(ENVIRON["LARK_SETUP_ID"]) "\""
      print "LARK_APP_SECRET = \"" escaped(ENVIRON["LARK_SETUP_SECRET"]) "\""
    }
    /^\[mcp_servers\.lark\.env\][[:space:]]*$/ {
      if (inside) credentials()
      inside=1; found=1; print; next
    }
    /^\[/ && inside { credentials(); inside=0 }
    inside && /^[[:space:]]*LARK_APP_(ID|SECRET)[[:space:]]*=/ { next }
    { print }
    END {
      if (inside) credentials()
      if (!found) {
        print ""
        print "[mcp_servers.lark.env]"
        credentials()
      }
    }
  ' "$SETTINGS" > "$tmp" || { rm -f "$tmp"; die "không ghi được $SETTINGS"; }
fi

chmod 600 "$tmp" 2>/dev/null || true
mv -f "$tmp" "$SETTINGS" || { rm -f "$tmp"; die "không ghi được $SETTINGS"; }

printf '  ✓ LARK_APP_ID: %s\n' "$(mask "$ID")"
printf '  ✓ LARK_APP_SECRET: %s\n' "$(mask "$SECRET")"
printf '\n=== ĐÃ LƯU === (%s)\n' "$SETTINGS"
case "$HOST" in
  codex)  printf 'KHỞI ĐỘNG LẠI Codex/IDE extension để MCP server nạp giá trị mới.\n' ;;
  claude) printf 'KHỞI ĐỘNG LẠI Claude Code để MCP server nạp giá trị mới.\n' ;;
esac
