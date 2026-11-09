#!/usr/bin/env bash
# Mở phiên cho đối tượng course: xác thực course_id với API thật rồi ghi session.
# Exit 0 = đi tiếp. Exit 1 = hỏi người dùng rồi chạy lại.
#
#   scripts/course/start.sh --course <uuid>
#
# Token lấy từ session file do scripts/login.sh ghi — không cần pipe gì vào.
# Token pipe qua stdin vẫn thắng, dành cho lần dùng tay lẻ.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

COURSE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --course) [ $# -ge 2 ] || die "--course cần một giá trị"
                COURSE="$2"; shift 2 ;;
    # In khối comment đầu file. Tự bám theo header nên không lệch khi header dài ra.
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) shift ;;
  esac
done

need_deps
# -t 2: có pipe thì lấy token ngay; không pipe thì bỏ qua sau 2s.
# Bỏ -t là treo vô hạn khi stdin không phải TTY mà cũng không EOF.
[ -t 0 ] || { IFS= read -r -t 2 piped || true; }
piped="$(printf '%s' "${piped:-}" | tr -d '[:space:]')"
case "$piped" in Bearer*) die "chỉ đưa phần token, bỏ chữ 'Bearer '" ;; esac
[ -n "$piped" ] && UPBASE_TOKEN="$piped"

COURSE="${COURSE:-${UPBASE_COURSE_ID:-}}"
bad=0
ok() { printf '  ✓ %s\n' "$*"; }
no() { printf '  ✗ %s\n' "$*"; bad=$((bad + 1)); }

# In môi trường TRƯỚC mọi kiểm tra: chưa đăng nhập cũng phải thấy mình đang
# nhắm vào staging hay prod, vì đó là thứ quyết định login vào đâu.
show_env
[ -n "${UPBASE_TOKEN:-}" ] || { no "TOKEN: chưa đăng nhập môi trường $UPBASE_ENV — nhờ người dùng chạy scripts/login.sh"
  printf '\n=== DỪNG ===\n'; exit 1; }
load_token
ok "TOKEN: …$(printf '%s' "$TOKEN" | tail -c 6)"

# Hạn token do realm Keycloak đặt. In thời gian còn lại để người dùng biết khi
# nào phải đăng nhập lại — KHÔNG dùng con số này để chia nhỏ công việc theo
# Section.
p=$(printf '%s' "$TOKEN" | cut -d. -f2 | tr '_-' '/+')
case $(( ${#p} % 4 )) in 2) p="$p==" ;; 3) p="$p=" ;; esac
exp=$(printf '%s' "$p" | base64 -d 2>/dev/null | jq -r '.exp // empty' 2>/dev/null)
if [ -n "${exp:-}" ]; then
  left=$(( (exp - $(date +%s)) / 60 ))
  [ "$left" -gt 0 ] && ok "TOKEN còn ~${left} phút" || no "TOKEN đã hết hạn"
fi

if [ -z "$COURSE" ]; then
  no "COURSE: chưa có course_id"
else
  api GET "/courses?page_index=1&page_size=$PAGE_SIZE_COURSES"; check_auth
  if [ "$API_HTTP" != "200" ]; then
    no "COURSE: GET /courses trả $API_HTTP"
  else
    nm=$(api_body | jq -r --arg c "$COURSE" '.data.courses[] | select(.id==$c) | .name')
    [ -n "$nm" ] && ok "COURSE: $nm" || no "COURSE: id không có trong danh sách khóa học"
  fi
fi

if [ "$bad" -gt 0 ]; then
  printf '\n=== THIẾU %d THÔNG TIN — DỪNG, KHÔNG TẠO GÌ ===\nHỏi người dùng rồi chạy lại.\n' "$bad"
  exit 1
fi

# Đọc lại session file cũ để giữ nguyên topic_id đã chọn — session dùng chung
# cho mọi đối tượng, ghi đè thẳng sẽ xóa mất phiên của đối tượng khác.
topic=""
if [ -r "$UPBASE_ENV_FILE" ]; then
  topic=$(sed -n 's/^UPBASE_TOPIC_ID=//p' "$UPBASE_ENV_FILE" 2>/dev/null | tail -n1 | tr -d '\r')
fi

# Ghi atomic: .tmp → chmod 600 → mv. Tiến trình chết giữa chừng thì session cũ
# vẫn nguyên vẹn, không có trạng thái nửa vời.
tmp="${UPBASE_ENV_FILE}.tmp.$$"
{ printf '# UpBase session\n'
  printf 'UPBASE_TOKEN=%s\n' "$TOKEN"
  [ -n "$topic" ] && printf 'UPBASE_TOPIC_ID=%s\n' "$topic"
  printf 'UPBASE_COURSE_ID=%s\n' "$COURSE"
  printf 'UPBASE_BASE_URL=%s\n' "$UPBASE_BASE_URL"
} > "$tmp" 2>/dev/null || { rm -f "$tmp"; die "không ghi được $UPBASE_ENV_FILE"; }
chmod 600 "$tmp" 2>/dev/null || true
mv -f "$tmp" "$UPBASE_ENV_FILE" 2>/dev/null || { rm -f "$tmp"; die "không ghi được $UPBASE_ENV_FILE"; }

printf '\n=== SẴN SÀNG === môi trường %s · session %s\n' "$UPBASE_ENV" "$UPBASE_ENV_FILE"
