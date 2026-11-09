#!/usr/bin/env bash
# Đính file đã upload vào khóa học, dưới dạng tài liệu đính kèm của CẢ KHÓA.
#
#   add-course-resource.sh <file> [<file> …] [--manifest FILE] [--course <id>]
#                          [--state FILE] [--dry-run]
#
# File lấy từ nhãn `Course Resource:` ở vùng "Thông tin khóa học" của tài liệu
# Lark — khác `Resource:` của một Activity, cái đó gắn vào Activity.
#
# ĐÂY LÀ CALL THỨ NĂM, chạy SAU upload-media.sh. File phải đã đi hết bốn call
# của luồng upload (folder → metadata → PUT S3 → add-file-resource) để có
# resource_id; script này chỉ đọc id đó từ manifest rồi gắn vào khóa:
#
#   POST /courses/<course_id>/add-resource
#   {"attachments":[{"resource_id":"…","type":"attached","dom_id":"","note":""}]}
#
# Tham số nhận ĐƯỜNG DẪN FILE, không phải resource_id — id tra từ manifest, y
# như cách bước 6 tra. Truyền thẳng id là bỏ qua lớp kiểm "file này đã upload
# chưa".
#
# MỘT CALL CHO MỌI FILE. `attachments` là mảng nên mọi file đi cùng một request.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

MANIFEST="media-manifest.json" COURSE="" STATE="state.json" DRY=0
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) [ $# -ge 2 ] || die "--manifest cần một giá trị"
                MANIFEST="$2"; shift 2 ;;
    --course) [ $# -ge 2 ] || die "--course cần một giá trị"
                COURSE="$2"; shift 2 ;;
    --state) [ $# -ge 2 ] || die "--state cần một giá trị"
                STATE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) FILES+=("$1"); shift ;;
  esac
done

need_deps
[ "${#FILES[@]}" -gt 0 ] || die "cần ít nhất một đường dẫn file
  Dùng đúng đường dẫn đã truyền cho upload-media.sh — manifest khoá theo chuỗi đó."
[ -f "$MANIFEST" ] || die "không thấy manifest: $MANIFEST
  Chạy scripts/course/upload-media.sh cho các file này trước."
jq -e . "$MANIFEST" >/dev/null 2>&1 || die "$MANIFEST không phải JSON hợp lệ"
[ -f "$STATE" ] || echo '{}' > "$STATE"

# Tra resource_id của từng file. Ba trạng thái phải tách bạch, vì cách xử lý
# khác nhau: chưa upload là LỖI (dừng), bị bỏ qua vì quá lớn là CHẤP NHẬN ĐƯỢC
# (cảnh báo rồi đi tiếp, người dùng tự upload trên giao diện).
ATT='[]'
missing="" skipped=""
for f in "${FILES[@]}"; do
  entry=$(jq -c --arg k "$f" '.[$k] // empty' "$MANIFEST")
  if [ -z "$entry" ]; then
    missing="$missing  · $f"$'\n'; continue
  fi
  if [ "$(printf '%s' "$entry" | jq -r '.skipped // empty')" != "" ]; then
    skipped="$skipped  · $f ($(printf '%s' "$entry" | jq -r '.skipped'))"$'\n'; continue
  fi
  rid=$(printf '%s' "$entry" | jq -r '.resource_id // empty')
  [ -n "$rid" ] || { missing="$missing  · $f (có trong manifest nhưng resource_id rỗng)"$'\n'; continue; }
  ATT=$(printf '%s' "$ATT" | jq -c --arg r "$rid" \
    '. + [{resource_id: $r, type: "attached", dom_id: "", note: ""}]')
done

[ -z "$missing" ] || die "chưa có resource_id cho các file sau:
$missing  Chạy scripts/course/upload-media.sh cho chúng trước, và nhớ truyền
  --manifest trỏ đúng file manifest của khóa này ($MANIFEST)."

[ -z "$skipped" ] || {
  printf '⚠️  bỏ qua (quá lớn, chưa upload được):\n%s' "$skipped" >&2
  printf '    Người dùng tự upload trên giao diện; nói rõ trong báo cáo cuối.\n' >&2
}

N=$(printf '%s' "$ATT" | jq 'length')
[ "$N" -gt 0 ] || die "không còn file nào để đính — mọi file đều bị bỏ qua ở bước upload"

info "Đính $N file vào khóa"
if [ "$DRY" -eq 1 ]; then
  printf '[dry-run] POST /courses/%s/add-resource\n' "${COURSE:-<từ session>}" >&2
  printf '%s' "$ATT" | jq -r '.[] | "  · \(.resource_id)"' >&2
  printf '\n=== DRY-RUN — CHƯA GẮN GÌ === (state: %s)\n' "$STATE" >&2
  exit 0
fi

load_token
COURSE="${COURSE:-${UPBASE_COURSE_ID:-}}"
[ -n "$COURSE" ] || die "chưa có course_id — truyền --course <id>, hoặc chạy
  scripts/course/start.sh --course <id> trước để ghi nó vào session"

# Resume ở mức CẢ CALL, không phải từng file. Chưa kiểm chứng được gọi lần hai
# thì server CỘNG THÊM hay THAY THẾ danh sách attachments, nên không có cách
# gửi bổ sung nào an toàn: cộng thêm mà gửi lại cả mảng là nhân đôi, thay thế
# mà chỉ gửi phần mới là mất phần cũ. Gọi đúng một lần với đủ mọi file.
KEY="courseresource:$COURSE"
have=$(jq -r --arg k "$KEY" '.[$k] // empty' "$STATE")
if [ -n "$have" ]; then
  printf 'SKIP %-26s đã đính %s file\n' "$KEY" "$have" >&2
  printf '\n=== ĐÃ ĐÍNH TỪ TRƯỚC === (state: %s)\n' "$STATE"
  printf '  Cần đính thêm file mới thì xoá khoá "%s" trong %s rồi chạy lại\n' "$KEY" "$STATE" >&2
  printf '  VỚI ĐỦ MỌI FILE, không chỉ file mới.\n' >&2
  exit 0
fi

payload=$(jq -nc --argjson a "$ATT" '{attachments: $a}')
api POST "/courses/$COURSE/add-resource" "$payload"; check_auth
case "$API_HTTP" in
  200|201|204) ;;
  *) die "POST /courses/$COURSE/add-resource trả $API_HTTP: $(api_body | jq -c '.error // .message // .' 2>/dev/null | head -c 300)" ;;
esac

jq --arg k "$KEY" --arg v "$N" '. + {($k):$v}' "$STATE" > "$STATE.tmp" \
  && mv "$STATE.tmp" "$STATE" \
  || { rm -f "$STATE.tmp"; die "không ghi được state: $STATE"; }

printf 'OK   %-26s %s file\n' "$KEY" "$N" >&2
printf '\n=== ĐÃ ĐÍNH TÀI LIỆU KHÓA HỌC === (state: %s)\n' "$STATE"
