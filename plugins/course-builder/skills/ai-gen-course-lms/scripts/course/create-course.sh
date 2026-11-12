#!/usr/bin/env bash
# Tạo khóa học mới trên LMS. Chạy đầu bước 5, trước mọi thứ cần course_id.
#
#   create-course.sh --name "<Name:>" --description "<Description: dạng HTML>"
#                    --category "<Course Category:>" [--type "<Type:>"]
#                    [--pass-point <Passpoint:>] [--setting '<JSON Điểm thành phần>']
#                    [--state FILE] [--dry-run]
#
# Mọi giá trị lấy từ vùng "Thông tin khóa học" của tài liệu Lark, theo luật
# `Nhãn: giá trị` — xem references/lark-source.md.
#
# Hai call, call sau cần kết quả call trước:
#   1. GET  /course_categories?name=<--category>  → search theo TÊN, thu hẹp bằng
#      ba mức khớp. Khớp 0 hoặc >1 đều DỪNG — không bao giờ chọn phần tử đầu.
#      Search rỗng thì lấy nguyên danh sách rồi khớp tại chỗ.
#   2. POST /courses             → course_id
#
# --name, --description, --category BẮT BUỘC. Ba cờ còn lại bỏ trống thì lấy
# fallback trong scripts/config.sh và IN CẢNH BÁO — tài liệu mới khai đủ, thiếu
# là dấu hiệu đọc sót. `code` không gửi; backend tự sinh.
#

#
# In dòng cuối `COURSE_ID=<uuid>`. Sau đó chạy:
#   scripts/course/start.sh --course <COURSE_ID>

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

NAME="" DESC="" CATEGORY="" CTYPE="" PASSPOINT="" SETTING="" STATE="state.json" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || die "--name cần một giá trị"
                NAME="$2"; shift 2 ;;
    --description) [ $# -ge 2 ] || die "--description cần một giá trị"
                DESC="$2"; shift 2 ;;
    --category) [ $# -ge 2 ] || die "--category cần một giá trị"
                CATEGORY="$2"; shift 2 ;;
    --type) [ $# -ge 2 ] || die "--type cần một giá trị"
                CTYPE="$2"; shift 2 ;;
    --pass-point) [ $# -ge 2 ] || die "--pass-point cần một giá trị"
                PASSPOINT="$2"; shift 2 ;;
    --setting) [ $# -ge 2 ] || die "--setting cần một giá trị"
                SETTING="$2"; shift 2 ;;
    --state) [ $# -ge 2 ] || die "--state cần một giá trị"
                STATE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) shift ;;
  esac
done

need_deps
[ -n "$NAME" ] || die "thiếu --name (tên khóa học trong tài liệu Lark)"

# Thiếu cờ nào cũng chạy được, nhưng KHÔNG im lặng: template mới khai đủ cả sáu
# trường, thiếu là dấu hiệu đọc sót tài liệu chứ không phải "để mặc định".
warn_default() { printf '  ! thiếu %-14s → dùng mặc định %s  (tài liệu khai ở nhãn `%s`)\n' "$1" "$2" "$3" >&2; }

if [ -z "$DESC" ]; then
  warn_default "--description" "<p><tên khóa></p>" "Description:"
  DESC="<p>${NAME}</p>"
fi
[ -n "$CTYPE" ]     || { warn_default "--type" "$COURSE_TYPE" "Type:"; CTYPE="$COURSE_TYPE"; }
[ -n "$PASSPOINT" ] || { warn_default "--pass-point" "$COURSE_PASS_POINT" "Passpoint:"; PASSPOINT="$COURSE_PASS_POINT"; }
[ -n "$SETTING" ]   || { warn_default "--setting" "$COURSE_SETTING" "Điểm thành phần:"; SETTING="$COURSE_SETTING"; }

printf '%s' "$PASSPOINT" | grep -qE '^[0-9]+$' || die "--pass-point phải là số nguyên, nhận: $PASSPOINT"
printf '%s' "$SETTING" | jq -e 'type == "object"' >/dev/null 2>&1 \
  || die "--setting phải là JSON object, nhận: $(printf '%s' "$SETTING" | head -c 120)"

state_dir=$(dirname "$STATE")
mkdir -p "$state_dir" || die "không tạo được thư mục state: $state_dir"
[ -f "$STATE" ] || echo '{}' > "$STATE"

# Khóa học KHÔNG xóa được bằng bộ script này, nên chạy lại phải SKIP chứ tuyệt
# đối không tạo khóa thứ hai cùng tên.
KEY="course:$NAME"
have=$(jq -r --arg k "$KEY" '.[$k] // empty' "$STATE")
if [ -n "$have" ]; then
  printf 'SKIP %-24s %s\n' "$KEY" "$have" >&2
  printf '\n=== ĐÃ CÓ KHÓA HỌC === (state: %s)\nCOURSE_ID=%s\n' "$STATE" "$have"
  exit 0
fi

if [ "$DRY" = "1" ]; then
  printf '[dry-run] 1) GET  /course_categories?page_index=1&page_size=%s  → tra tên %s\n' \
    "$PAGE_SIZE_CATEGORIES" "${CATEGORY:-<THIẾU --category>}" >&2
  printf '[dry-run] 2) POST /courses\n' >&2
  jq -n --arg n "$NAME" --arg d "$DESC" \
    --arg st "$COURSE_STATUS" --arg ct "$CTYPE" \
    --argjson pp "$PASSPOINT" --argjson tpl "$COURSE_TEMPLATE" \
    --argjson setting "$SETTING" --arg cat "${CATEGORY:-<THIẾU>}" \
    '{name:$n, pass_point:$pp, description:$d, status:$st,
      course_type:$ct, setting:$setting, template:$tpl,
      course_category_id:"<tra theo tên: \($cat)>"}'
  printf '\n=== DRY-RUN — CHƯA TẠO GÌ === (state: %s)\n' "$STATE" >&2
  exit 0
fi

show_env
load_token

# Khôi phục an toàn nếu request tạo trước đó đã thành công nhưng state không ghi
# được. Không POST lần hai cho cùng tên.
api GET "/courses?page_index=1&page_size=$PAGE_SIZE_COURSES"; check_auth
if [ "$API_HTTP" = "200" ]; then
  existing=$(api_body | jq -r --arg n "$NAME" \
    '.data.courses[] | select(.name == $n) | .id' | head -n1)
  if [ -n "$existing" ]; then
    jq --arg k "$KEY" --arg v "$existing" '. + {($k):$v}' "$STATE" > "$STATE.tmp" \
      && mv "$STATE.tmp" "$STATE" \
      || { rm -f "$STATE.tmp"; die "không ghi được state: $STATE"; }
    printf '  ✓ COURSE: %s\n          %s  (khôi phục từ khóa đã tạo, status DRAFT)\n' "$NAME" "$existing" >&2
    printf '\n=== ĐÃ CÓ KHÓA HỌC === (state: %s)\nCOURSE_ID=%s\n' "$STATE" "$existing"
    exit 0
  fi
fi

# ---------- 1. Course category ----------
# Search theo tên rồi thu hẹp bằng ba mức khớp. KHÔNG có mức "lấy phần tử đầu":
# gắn khóa vào sai category là lỗi im lặng — API trả 201, không ai biết.
[ -n "$CATEGORY" ] || CAT_MISSING=1

fetch_cats() {
  local qs="page_index=1&page_size=$PAGE_SIZE_CATEGORIES&dateField=updated_at"
  [ -n "${1:-}" ] && qs="$qs&name=$(urlenc "$1")"
  api GET "/course_categories?$qs"; check_auth
  [ "$API_HTTP" = "200" ] || die "GET /course_categories trả $API_HTTP: $(api_body | head -c 300)"
  # Tên mảng trong .data chưa kiểm chứng — dò mảng đầu tiên có phần tử mang .id.
  api_body | jq -c '
    (.data // {}) as $d
    | (if ($d | type) == "array" then $d
       else [ $d | to_entries[] | select((.value | type) == "array") | .value ] | add // []
       end)
    | map(select(type == "object" and has("id")))'
}

CATS=$(fetch_cats "$CATEGORY")
# Search rỗng thì lấy nguyên danh sách để khớp tại chỗ, và để in ra cho người dùng.
[ "$(printf '%s' "$CATS" | jq 'length')" -gt 0 ] || CATS=$(fetch_cats "")
ALLNAMES=$(printf '%s' "$CATS" | jq -r '[.[] | .name // .title] | join(" · ")')

[ -z "${CAT_MISSING:-}" ] || die "thiếu --category. KHÔNG tự chọn phần tử đầu danh sách.
  Điền nhãn 'Course Category:' trong tài liệu Lark cho khớp một trong các tên sau:
  $ALLNAMES"

# Ba mức, dừng ở mức đầu tiên có kết quả:
#   1. khớp chính xác
#   2. tên category nằm trong giá trị tài liệu (dài nhất thắng)
#   3. giá trị tài liệu nằm trong tên category
MATCH=$(printf '%s' "$CATS" | jq -c --arg q "$CATEGORY" '
  def norm: ascii_downcase | gsub("^\\s+|\\s+$";"");
  ($q | norm) as $n
  | map(. + {_t: ((.name // .title // "") | norm)})
  | (map(select(._t == $n)))                       as $t1
  | (map(. as $c | select($c._t != "" and ($n | contains($c._t))))
     | (map(._t | length) | max) as $L
     | map(select((._t | length) == $L)))          as $t2
  | (map(. as $c | select($c._t | contains($n))))  as $t3
  | if   ($t1 | length) > 0 then $t1
    elif ($t2 | length) > 0 then $t2
    elif ($t3 | length) > 0 then $t3
    else [] end')

nmatch=$(printf '%s' "$MATCH" | jq 'length')
case "$nmatch" in
  0) die "không có course_category nào khớp '$CATEGORY'.
  Danh sách hiện có: $ALLNAMES
  Sửa 'Course Category:' trong tài liệu cho khớp, rồi chạy lại." ;;
  1) CAT=$(printf '%s' "$MATCH" | jq -r '.[0].id') ;;
  *) die "'$CATEGORY' khớp $nmatch category — KHÔNG tự chọn hộ:
$(printf '%s' "$MATCH" | jq -r '.[] | "    · \(.name // .title)   \(.id)"')
  Ghi một dòng vào Sai lệch của outline, hỏi người dùng chọn cái nào, rồi sửa
  'Course Category:' trong tài liệu thành tên đầy đủ và chạy lại." ;;
esac

CATNAME=$(printf '%s' "$CATS" | jq -r --arg id "$CAT" '.[] | select(.id == $id) | (.name // .title // "?")')
printf '  ✓ CATEGORY: %s\n            %s\n' "$CATNAME" "$CAT" >&2

# ---------- 2. Tạo khóa học ----------
payload=$(jq -nc --arg n "$NAME" --arg d "$DESC" --arg cat "$CAT" \
  --arg st "$COURSE_STATUS" --arg ct "$CTYPE" \
  --argjson pp "$PASSPOINT" --argjson tpl "$COURSE_TEMPLATE" \
  --argjson setting "$SETTING" \
  '{name:$n, pass_point:$pp, description:$d, status:$st,
    course_type:$ct, setting:$setting, template:$tpl, course_category_id:$cat}')

api POST "/courses" "$payload"; check_auth
case "$API_HTTP" in
  200|201) ;;
  *) die "POST /courses trả $API_HTTP: $(api_body | head -c 300)" ;;
esac

id=$(api_body | jq -r '.data.id // .id // empty')
[ -n "$id" ] || die "tạo xong nhưng không đọc được id: $(api_body | head -c 300)"

jq --arg k "$KEY" --arg v "$id" '. + {($k):$v}' "$STATE" > "$STATE.tmp" \
  && mv "$STATE.tmp" "$STATE" \
  || { rm -f "$STATE.tmp"; die "không ghi được state: $STATE"; }

printf '  ✓ COURSE: %s\n          %s  (mới tạo, status DRAFT)\n' "$NAME" "$id" >&2
printf '\n=== ĐÃ TẠO KHÓA HỌC === (state: %s)\nCOURSE_ID=%s\n' "$STATE" "$id"
