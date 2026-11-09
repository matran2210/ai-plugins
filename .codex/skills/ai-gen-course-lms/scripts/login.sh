#!/usr/bin/env bash
# login.sh — Đăng nhập bằng hộp thoại, lưu access token để các script khác dùng lại.
#
# CÁCH DÙNG
#   scripts/login.sh            chọn môi trường, đăng nhập, lưu token
#   scripts/login.sh --gui      như trên nhưng CHỈ nhận qua hộp thoại đồ hoạ;
#                               không có GUI thì dừng thay vì hỏi ở terminal.
#   scripts/login.sh --env prod bỏ qua panel, vào thẳng môi trường đó
#   scripts/login.sh --username admin
#
# LUÔN ĐĂNG NHẬP LẠI. Script không kiểm token cũ còn hạn hay không, và không có
# nhánh nào thoát sớm — nên panel chọn môi trường luôn hiện trước, mỗi lượt.
# Hạn token do realm Keycloak quyết định; đoán nó ở phía client là đoán sai.
#
# Hộp thoại: macOS dùng AppleScript, Windows dùng PowerShell (chạy trong Git Bash
# hoặc WSL), môi trường không có GUI thì nhập ẩn ký tự ngay tại terminal.
#
# `--gui` là chế độ DUY NHẤT Claude được phép gọi. Nó an toàn vì mật
# khẩu đi từ cửa sổ đồ hoạ thẳng vào tiến trình này, không qua stdin và không bao
# giờ có mặt trong stdout — Claude chỉ thấy tên đăng nhập và hạn token. Cờ này
# chặn hẳn nhánh nhập-qua-terminal, nên không tồn tại đường nào để mật khẩu chảy
# qua stream mà Claude kiểm soát.
#
# ── CƠ CHẾ LƯU TRỮ: cái gì nằm ở đâu ────────────────────────────────────────
#
#   Access token → $UPBASE_ENV_FILE       chmod 600 · hạn do Keycloak quyết định
#   File này TÁCH THEO MÔI TRƯỜNG: upbase-session-staging.env / -prod.env
#                  Đường dẫn do lib.sh quyết định, mặc định
#                  $TMPDIR/upbase-session.env — MỘT session file dùng chung cho
#                  mọi đối tượng, đăng nhập một lần là đủ cho tất cả.
#
#   Tên đăng nhập → KHÔNG LƯU
#   và mật khẩu     Hộp thoại hỏi lại cả hai ô mỗi lần, để đăng nhập bằng tài
#                   khoản khác không phải xoá gì trước. Cả hai chỉ nằm trong RAM
#                   của tiến trình thu thập chúng, dùng đúng một lần cho request
#                   login rồi bỏ.
#
#                   `--username <tên>` điền sẵn ô tên cho đúng lần chạy đó và
#                   cũng không được ghi xuống đâu cả.
#
# ── LUỒNG: vì sao các script khác không cần token trên dòng lệnh ────────────
#
#   login.sh ──ghi──▶ $UPBASE_ENV_FILE ──đọc──▶ lib.sh:_load_env_file()
#                                                 └─▶ $UPBASE_TOKEN
#                                                     └─▶ mọi script khác
#
#   Mỗi script khi khởi động đều source lib.sh, và lib.sh tự nạp session file
#   vào biến môi trường. Nên sau khi login xong thì không script nào phải nhận
#   token qua tham số nữa.
#   Ghi file kiểu atomic (.tmp → chmod 600 → mv) nên không có trạng thái nửa vời
#   nếu tiến trình chết giữa chừng; topic_id/course_id đã lưu được giữ nguyên.
#
# ── HẾT HẠN: khi nào phải đăng nhập lại ─────────────────────────────────────
#
#   • Khi token hết hạn. Hạn do REALM KEYCLOAK đặt, không phải con số cố định
#     của UpBase — script đọc `exp` trong payload JWT và in ra hạn thật sau khi
#     đăng nhập. Realm để mặc định thì access token Keycloak sống rất ngắn.
#     CỐ Ý không dùng refresh token. Nếu hạn ngắn tới mức chạy không hết một
#     lượt thì đó là chỗ phải tính lại, không vá bằng cách đoán hạn ở client.
#   • Sau khi máy reboot — $TMPDIR bị dọn nên mất token dù chưa hết hạn.
#
#   Muốn token sống qua reboot:
#       export UPBASE_ENV_FILE="$HOME/.upbase-session.env"
#
# ── BẢO MẬT: những chỗ cố tình làm khó ──────────────────────────────────────
#
#   • Mật khẩu không bao giờ vào argv → không lộ trong `ps` cho user khác thấy.
#     Nó đi vào curl qua stdin (--data-binary @-).
#   • Body dựng bằng `jq @uri` → mật khẩu chứa &, = hay ký tự lạ không làm vỡ
#     form-urlencoded, và không phải tự viết hàm percent-encode.
#   • Trên Windows, PowerShell tự thu mật khẩu VÀ tự gọi API, chỉ trả response
#     về bash → mật khẩu không bao giờ rời tiến trình PowerShell.
#   • Chỉ lưu access token; refresh token Keycloak trả về bị bỏ hẳn.
#   • KHÔNG BAO GIỜ nhận mật khẩu qua khung chat của Claude — dán vào đó là nó
#     nằm vĩnh viễn trong transcript và log phiên. Script này phải do người dùng
#     tự chạy ở terminal của họ; Claude chỉ được gọi `--gui`.

# Source lib.sh để lấy $UPBASE_ENV_FILE và $UPBASE_BASE_URL — không hardcode
# đường dẫn ở đây.
# lib.sh cũng đã nạp sẵn $UPBASE_TOKEN từ session file (nếu có) khi được source.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

RESP_FILE="${TMPDIR:-/tmp}/upbase-login.$$"
PS_FILE="${TMPDIR:-/tmp}/upbase-login.$$.ps1"
trap 'rm -f "$RESP_FILE" "$PS_FILE" "${API_BODY_FILE:-}"' EXIT

GUI_ONLY=0
USERNAME=""
ENVARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    # Bỏ từ bản đổi sang Keycloak: hạn token do realm quyết định chứ không còn
    # là con số cố định của UpBase, nên tin vào token lưu sẵn là tin vào thứ
    # không kiểm được. Mỗi lượt đăng nhập lại — và nhờ vậy panel chọn môi
    # trường LUÔN hiện, không có đường nào lẳng lặng dùng lại môi trường cũ.
    --check)    die "--check đã bỏ. Không còn kiểm hạn token lưu sẵn nữa:
  mỗi lượt đều đăng nhập lại, và panel chọn môi trường luôn hiện.
  Chạy: scripts/login.sh --gui" ;;
    --gui)      GUI_ONLY=1; shift ;;
    --username) [ $# -ge 2 ] || die "--username cần một giá trị"
                USERNAME="$2"; shift 2 ;;
    # Bỏ qua panel chọn môi trường. Dùng khi gọi lại từ script.
    --env)      [ $# -ge 2 ] || die "--env cần một giá trị"
                ENVARG="$2"; shift 2 ;;
    # In toàn bộ khối comment đầu file (bỏ shebang, bỏ dấu '#').
    -h|--help)  awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
                exit 0 ;;
    # Gõ nhầm cờ mà nuốt im lặng thì rơi về nhánh nhập qua terminal — đúng thứ
    # mà --gui sinh ra để chặn.
    -*)         die "cờ không nhận: $1" ;;
    *)          shift ;;
  esac
done

need_deps
command -v openssl >/dev/null 2>&1 || die "thiếu lệnh 'openssl'"

# Đổi môi trường thì phải nạp lại config: base URL VÀ session file đều phụ thuộc
# $UPBASE_ENV, mà lib.sh đã chốt chúng lúc source ở đầu file.
use_env() {
  case "$1" in staging|prod) ;; *) die "--env phải là staging hoặc prod, nhận: $1" ;; esac
  UPBASE_ENV="$1"
  # Phải unset CẢ _DEFAULT: config.sh dùng ${VAR:-…} nên giá trị chốt ở lần
  # source đầu sẽ sống sót và base URL đứng nguyên ở môi trường cũ.
  # UPBASE_AUTH_URL cũng vậy — quên nó thì chọn Production ở panel xong vẫn
  # đăng nhập vào Keycloak staging, mà token lại được đóng dấu là prod.
  unset UPBASE_BASE_URL UPBASE_BASE_URL_DEFAULT UPBASE_AUTH_URL \
        UPBASE_ENV_FILE UPBASE_TOKEN
  . "$HERE/lib.sh"
}
[ -z "$ENVARG" ] || use_env "$ENVARG"

# In ra exp (epoch) đọc từ payload JWT; rỗng nếu không giải mã được.
# Chỉ dùng để BÁO hạn sau khi đăng nhập xong — không còn là cửa chặn.
jwt_exp() {
  local t="${1:-}" p
  case "$t" in *.*.*) ;; *) return 1 ;; esac
  p="${t#*.}"; p="${p%%.*}"
  p=$(printf '%s' "$p" | tr '_-' '/+')
  case $(( ${#p} % 4 )) in 2) p="${p}==" ;; 3) p="${p}=" ;; esac
  printf '%s' "$p" | openssl base64 -d -A 2>/dev/null | jq -r '.exp // empty' 2>/dev/null
}

# ------------------------------------------------------------------- hộp thoại
#
# KHÔNG có nhánh nào thoát sớm vì "token còn hạn". Token trong session file chỉ
# để các script KHÁC dùng lại trong cùng một lượt; chạy login.sh là đăng nhập
# lại, luôn luôn, và panel chọn môi trường luôn hiện trước.

HTTP=000

# Gọi login. Mật khẩu vào curl qua stdin — không bao giờ nằm trong argv.
#
# Body là form-urlencoded, KHÔNG phải JSON. Percent-encode cả bốn trường bằng
# @uri của jq: mật khẩu có & hoặc = mà đi thẳng vào body là cắt sai trường, và
# server chỉ báo sai mật khẩu chứ không nói vì sao.
#
# Không dùng --data-urlencode của curl: cờ đó nhận giá trị qua argv, tức là mật
# khẩu hiện trong `ps` cho mọi user trên máy thấy.
call_api() {
  local u="$1" p="$2" body
  body=$(jq -rn --arg u "$u" --arg p "$p" --arg c "$UPBASE_AUTH_CLIENT_ID" \
           '"grant_type=password&client_id=\($c|@uri)&username=\($u|@uri)&password=\($p|@uri)"') \
    || die "không dựng được body"
  HTTP=$(printf '%s' "$body" \
    | curl -sS -o "$RESP_FILE" -w '%{http_code}' \
        -X POST "$UPBASE_AUTH_URL" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -H 'Accept: application/json' \
        --data-binary @- 2>/dev/null) || HTTP=000
  body=""
}

# mac_ask <prompt> <hidden 0|1> — prompt đi qua argv nên không injection được.
# Panel chọn môi trường — hiện TRƯỚC khi hỏi tên đăng nhập, vì base URL quyết
# định login bắn vào đâu và token được lưu vào file nào.
mac_pick_env() {
  osascript 2>/dev/null <<'AS'
set opts to {"OPS Staging", "OPS Production"}
set c to choose from list opts with title "UpBase OPS — chọn môi trường" ¬
	with prompt "Đăng nhập vào môi trường nào?" default items {"OPS Staging"} ¬
	OK button name "Tiếp tục" cancel button name "Hủy"
if c is false then return "CANCEL"
if item 1 of c is "OPS Production" then return "prod"
return "staging"
AS
}

mac_ask() {
  local title="OPS ${ENV_LABEL}"
  if [ "$2" = 1 ]; then
    osascript - "$1" "$title" 2>/dev/null <<'AS'
on run argv
	set d to display dialog (item 1 of argv) default answer "" with hidden answer with title (item 2 of argv) buttons {"Hủy", "OK"} default button "OK"
	return text returned of d
end run
AS
  else
    osascript - "$1" "$title" 2>/dev/null <<'AS'
on run argv
	set d to display dialog (item 1 of argv) default answer "" with title (item 2 of argv) buttons {"Hủy", "OK"} default button "OK"
	return text returned of d
end run
AS
  fi
}

# PowerShell tự thu mật khẩu VÀ tự gọi API, chỉ trả lại response —
# mật khẩu không bao giờ rời tiến trình PowerShell.
win_login() {
  local esc out u_line h_line winpath
  esc=${USERNAME//\'/\'\'}
  {
    printf '\xef\xbb\xbf'                       # BOM để PowerShell đọc UTF-8
    printf "\$Url = '%s'\n" "$UPBASE_AUTH_URL"
    printf "\$ClientId = '%s'\n" "$UPBASE_AUTH_CLIENT_ID"
    printf "\$Pre = '%s'\n" "$esc"
    printf "\$EnvLabel = '%s'\n" "$ENV_LABEL"
    cat <<'PS'
$ErrorActionPreference = 'Stop'
if ($Pre) { $c = Get-Credential -UserName $Pre -Message ('OPS ' + $EnvLabel + ' — nhập mật khẩu') }
else      { $c = Get-Credential -Message ('OPS ' + $EnvLabel + ' — nhập tên đăng nhập và mật khẩu') }
if (-not $c) { Write-Output 'HTTP 000'; exit 0 }
# Hashtable + ContentType form-urlencoded: Invoke-WebRequest tự percent-encode,
# nên mật khẩu có & hoặc = vẫn sang đúng trường.
$b = @{
  grant_type = 'password'
  client_id  = $ClientId
  username   = $c.UserName
  password   = $c.GetNetworkCredential().Password
}
Write-Output ('USER ' + $c.UserName)
try {
  $r = Invoke-WebRequest -Uri $Url -Method Post -UseBasicParsing `
         -ContentType 'application/x-www-form-urlencoded' `
         -Body $b
  Write-Output ('HTTP ' + [int]$r.StatusCode)
  Write-Output $r.Content
} catch {
  $code = 0
  if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
  Write-Output ('HTTP ' + $code)
  if ($_.ErrorDetails) { Write-Output $_.ErrorDetails.Message }
}
PS
  } > "$PS_FILE" || die "không ghi được $PS_FILE"

  winpath="$PS_FILE"
  if command -v cygpath >/dev/null 2>&1; then
    winpath=$(cygpath -w "$PS_FILE")
  elif command -v wslpath >/dev/null 2>&1; then
    winpath=$(wslpath -w "$PS_FILE")
  fi

  out=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$winpath" 2>/dev/null \
        | tr -d '\r') || out=""
  [ -n "$out" ] || die "không chạy được PowerShell (trên Windows hãy dùng Git Bash hoặc WSL)"

  u_line=$(printf '%s\n' "$out" | sed -n 's/^USER //p' | head -n1)
  h_line=$(printf '%s\n' "$out" | sed -n 's/^HTTP //p' | head -n1)
  [ -n "$u_line" ] && USERNAME="$u_line"
  HTTP="${h_line:-000}"
  printf '%s\n' "$out" | sed -n '/^HTTP /,$p' | tail -n +2 > "$RESP_FILE"
}

case "$(uname -s 2>/dev/null || echo unknown)" in
  Darwin)               PLATFORM=macos ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) if command -v powershell.exe >/dev/null 2>&1; then PLATFORM=windows
     else PLATFORM=tty; fi ;;
esac

# ------------------------------------------------ chọn môi trường trước tiên --
# --env đã truyền thì bỏ qua panel. Chưa truyền thì hỏi, theo đúng nền tảng.
if [ -z "$ENVARG" ]; then
  case "$PLATFORM" in
    macos)
      picked=$(mac_pick_env) || die "đã hủy"
      [ "$picked" != "CANCEL" ] || die "đã hủy"
      [ -n "$picked" ] || die "chưa chọn môi trường"
      use_env "$picked"
      ;;
    *)
      # Windows và tty đều hỏi qua terminal: PowerShell chỉ mở hộp thoại cho
      # phần mật khẩu, không có picker riêng.
      if [ "$GUI_ONLY" = 1 ] && [ "$PLATFORM" = tty ]; then
        die "máy này không có hộp thoại đồ hoạ, mà --gui thì cấm nhập qua terminal.
Người dùng hãy tự mở terminal và chạy: scripts/login.sh"
      fi
      [ -t 0 ] || die "không chọn được môi trường: không có hộp thoại và cũng không
có terminal tương tác. Truyền thẳng --env staging hoặc --env prod."
      printf 'Chọn môi trường OPS:\n  1) Staging  (%s)\n  2) Production  (%s)\nSố [1]: ' \
        "$UPBASE_BASE_URL_STAGING" "$UPBASE_BASE_URL_PROD" >&2
      IFS= read -r pick || die "đã hủy"
      case "${pick:-1}" in
        1) use_env staging ;;
        2) use_env prod ;;
        *) die "chọn 1 hoặc 2" ;;
      esac
      ;;
  esac
fi

case "$UPBASE_ENV" in
  prod) ENV_LABEL="Production" ;;
  *)    ENV_LABEL="Staging" ;;
esac
show_env

PW=""
case "$PLATFORM" in
  macos)
    if [ -z "$USERNAME" ]; then
      USERNAME=$(mac_ask "Tên đăng nhập UpBase:" 0) || die "đã hủy"
      [ -n "$USERNAME" ] || die "chưa nhập tên đăng nhập"
    fi
    PW=$(mac_ask "Mật khẩu của $USERNAME:" 1) || die "đã hủy"
    [ -n "$PW" ] || die "chưa nhập mật khẩu"
    call_api "$USERNAME" "$PW"; PW=""
    ;;
  windows)
    win_login
    ;;
  tty)
    [ "$GUI_ONLY" = 0 ] || die "máy này không có hộp thoại đồ hoạ, mà --gui thì cấm
nhập qua terminal. Người dùng hãy tự mở terminal và chạy: scripts/login.sh"
    if [ -z "$USERNAME" ]; then
      printf 'Tên đăng nhập UpBase: ' >&2
      IFS= read -r USERNAME || die "đã hủy"
    fi
    printf 'Mật khẩu (không hiện ký tự): ' >&2
    IFS= read -rs PW || die "đã hủy"
    printf '\n' >&2
    [ -n "$PW" ] || die "chưa nhập mật khẩu"
    call_api "$USERNAME" "$PW"; PW=""
    ;;
esac

# --------------------------------------------------------------------- kết quả

# Keycloak trả 400 cho CẢ sai mật khẩu lẫn client cấu hình thiếu, phân biệt
# bằng trường .error — nên không gộp được vào một thông báo.
KC_ERR=$(jq -r '.error // empty' < "$RESP_FILE" 2>/dev/null)
KC_DESC=$(jq -r '.error_description // .message // empty' < "$RESP_FILE" 2>/dev/null)

case "$HTTP" in
  200|201) ;;
  000) die "không gọi được $UPBASE_AUTH_URL — hủy hộp thoại, hoặc lỗi mạng" ;;
  400|401|403)
    case "$KC_ERR" in
      invalid_grant)
        die "sai tên đăng nhập hoặc mật khẩu" ;;
      unauthorized_client)
        die "Keycloak chưa bật 'Direct access grants' cho client '$UPBASE_AUTH_CLIENT_ID'
  ($UPBASE_AUTH_URL)
  Đây là cấu hình phía Keycloak, đăng nhập lại không giải quyết được. Nhờ người
  quản trị bật Direct access grants cho client đó, hoặc dùng client khác:
    export UPBASE_AUTH_CLIENT_ID=<client-id>" ;;
      invalid_client)
        die "client '$UPBASE_AUTH_CLIENT_ID' không tồn tại ở realm này
  ($UPBASE_AUTH_URL)
  Đổi bằng: export UPBASE_AUTH_CLIENT_ID=<client-id>" ;;
      *)
        die "đăng nhập trả HTTP $HTTP: ${KC_ERR:-?} ${KC_DESC:-}" ;;
    esac ;;
  *) die "đăng nhập trả HTTP $HTTP: $(printf '%s %s' "${KC_ERR:-}" "${KC_DESC:-}" | head -c 200)" ;;
esac

# Keycloak trả .access_token; .data.tokens.act là shape của endpoint
# /auth/login cũ, giữ lại để session file viết bằng bản cũ vẫn đọc được.
# Fallback quét JWT nếu cả hai đều đổi.
TOKEN=$(jq -r '.access_token // .data.tokens.act // empty' < "$RESP_FILE" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  TOKEN=$(jq -r '
    def isjwt: type == "string"
      and test("^ey[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]*$");
    [ paths(isjwt) as $p
      | { k: ($p | map(tostring) | join(".")), v: getpath($p) }
      | select(.k | test("refresh|rft"; "i") | not) ]
    | (map(select(.k | test("act|access"; "i"))) + .) | .[0].v // empty
  ' < "$RESP_FILE" 2>/dev/null)
  [ -n "$TOKEN" ] && info "  ! không thấy access_token — đã dùng fallback quét JWT"
fi
[ -n "$TOKEN" ] || die "đăng nhập OK nhưng không tìm thấy access token trong response"

printf '  ✓ đăng nhập: %s\n' "$USERNAME" >&2
exp=$(jwt_exp "$TOKEN") || exp=""
if [ -n "${exp:-}" ]; then
  left=$(( exp - $(date +%s) ))
  printf '  ✓ token hết hạn sau %dh%02dm\n' \
    $(( left / 3600 )) $(( (left % 3600) / 60 )) >&2
fi

# ĐÂY LÀ CHỖ TOKEN ĐƯỢC LƯU.
# Đọc lại session file cũ trước để giữ nguyên topic_id/course_id đã chọn —
# nếu ghi đè thẳng thì người dùng phải chọn lại đối tượng chỉ vì vừa login.
# Ghi atomic: dựng file .tmp → chmod 600 → mv đè. Nhờ vậy nếu tiến trình chết
# giữa chừng thì session file cũ vẫn nguyên vẹn, không có trạng thái nửa vời.
topic=""; course=""
if [ -r "$UPBASE_ENV_FILE" ]; then
  topic=$(sed  -n 's/^UPBASE_TOPIC_ID=//p'  "$UPBASE_ENV_FILE" 2>/dev/null | tail -n1 | tr -d '\r')
  course=$(sed -n 's/^UPBASE_COURSE_ID=//p' "$UPBASE_ENV_FILE" 2>/dev/null | tail -n1 | tr -d '\r')
fi
# UPBASE_SESSION_ENV là DẤU MÔI TRƯỜNG của token, không phải cấu hình. lib.sh
# đọc nó và BỎ token nếu lệch môi trường đang chạy — chốt cuối chặn việc bắn
# token staging vào prod.
tmp="${UPBASE_ENV_FILE}.tmp.$$"
{ printf '# UpBase session — %s\n' "$UPBASE_ENV"
  printf 'UPBASE_SESSION_ENV=%s\n' "$UPBASE_ENV"
  printf 'UPBASE_TOKEN=%s\n' "$TOKEN"
  [ -n "$topic" ]  && printf 'UPBASE_TOPIC_ID=%s\n'  "$topic"
  [ -n "$course" ] && printf 'UPBASE_COURSE_ID=%s\n' "$course"
  printf 'UPBASE_BASE_URL=%s\n' "$UPBASE_BASE_URL"
} > "$tmp" 2>/dev/null || { rm -f "$tmp"; die "không ghi được $UPBASE_ENV_FILE"; }
chmod 600 "$tmp" 2>/dev/null || true
mv -f "$tmp" "$UPBASE_ENV_FILE" 2>/dev/null || { rm -f "$tmp"; die "không ghi được $UPBASE_ENV_FILE"; }
printf '  ✓ đã lưu: %s\n' "$UPBASE_ENV_FILE" >&2

printf '\n=== ĐÃ ĐĂNG NHẬP (%s) === quay lại Claude và tiếp tục.\n' "$UPBASE_ENV" >&2
