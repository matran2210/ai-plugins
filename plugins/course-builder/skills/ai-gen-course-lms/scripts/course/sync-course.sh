#!/usr/bin/env bash
# Đọc cây của một khóa học CÓ SẴN, ghi session, và (khi có --state) ghi
# `section:N` → SECTION_ID vào state file để các script tạo dùng lại.
# Dùng cho luồng ai-update-course-lms. Chỉ GỌI GET, không tạo gì trên LMS.
#
#   sync-course.sh --course <link|uuid>                         chỉ đọc + ghi session
#   sync-course.sh --course <link|uuid> --state FILE --expect-sections K
#
# --course: link OPS (…/course-full/<uuid>) hoặc uuid trần. Link có chữ
#   "staging" là staging, link OPS khác là prod — lệch UPBASE_ENV thì DỪNG.
# --state: ghi `section:1..K` theo thứ tự position của Section trên LMS, cùng
#   khóa `_course` để chặn dùng lại state của khóa khác.
# --expect-sections K: số Section đã ghi trong outline đã duyệt. Khóa có số
#   Section khác K (ai đó sửa trên giao diện sau khi duyệt) thì DỪNG — số Section
#   lệch là SECTION_ID lệch, câu hỏi gắn nhầm Section.
#
# Thay cho start.sh trong luồng này: start.sh chỉ thấy 100 khóa mới nhất,
# còn GET /courses/<id> đọc thẳng theo id.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

ARG="" STATE="" EXPECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --course) [ $# -ge 2 ] || die "--course cần một giá trị"
              ARG="$2"; shift 2 ;;
    --state)  [ $# -ge 2 ] || die "--state cần một giá trị"
              STATE="$2"; shift 2 ;;
    --expect-sections) [ $# -ge 2 ] || die "--expect-sections cần một giá trị"
              EXPECT="$2"; shift 2 ;;
    # In khối comment đầu file. Tự bám theo header nên không lệch khi header dài ra.
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    *) die "cờ không nhận: $1" ;;
  esac
done

need_deps
[ -n "$ARG" ] || die "cần --course <link khóa học hoặc uuid>"
[ -z "$STATE" ] || [ -n "$EXPECT" ] \
  || die "--state phải đi kèm --expect-sections <số Section ghi trong outline đã duyệt>"

COURSE=$(printf '%s' "$ARG" | grep -oiE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -n1 | tr 'A-F' 'a-f')
[ -n "$COURSE" ] || die "không thấy course_id (uuid) trong: $ARG"

# Link nói môi trường nào thì phải đang chạy đúng môi trường đó. Bắn nhầm
# môi trường là ghi vào khóa khác, mà skill không xóa được gì.
case "$ARG" in
  http*staging*) LINK_ENV="staging" ;;
  http*)         LINK_ENV="prod" ;;
  *)             LINK_ENV="" ;;
esac
[ -z "$LINK_ENV" ] || [ "$LINK_ENV" = "$UPBASE_ENV" ] \
  || die "link khóa là môi trường $LINK_ENV, đang chạy $UPBASE_ENV.
  Đăng nhập lại và chọn $LINK_ENV, hoặc chạy với UPBASE_ENV=$LINK_ENV."

show_env
load_token

api GET "/courses/$COURSE"; check_auth
[ "$API_HTTP" = "200" ] \
  || die "GET /courses/$COURSE trả $API_HTTP — không có khóa này ở môi trường $UPBASE_ENV? $(api_body | head -c 200)"
CNAME=$(api_body | jq -r '.data.name // empty')
CSTATUS=$(api_body | jq -r '.data.status // empty')
[ -n "$CNAME" ] || die "GET /courses/$COURSE không trả .data.name: $(api_body | head -c 200)"

api GET "/courses/$COURSE/sections"; check_auth
[ "$API_HTTP" = "200" ] || die "GET /courses/$COURSE/sections trả $API_HTTP: $(api_body | head -c 200)"
TREE=$(api_body | jq -c '.data // empty')
[ -n "$TREE" ] && printf '%s' "$TREE" | jq -e 'type == "array"' >/dev/null \
  || die "GET /courses/$COURSE/sections không trả mảng .data"

# Danh sách phẳng: CHAPTER (Section) · UNIT · ACTIVITY · CHAPTER_TEST · FINAL_TEST…
# Section = CHAPTER không có parent_id, đánh số 1..K theo position.
SECTIONS=$(printf '%s' "$TREE" | jq -c '
  . as $all
  | [ .[] | select(.course_section_type == "CHAPTER" and (.parent_id // "") == "") ]
  | sort_by(.position)
  | to_entries
  | map(.value as $s
      | ([ $all[] | select(.course_section_type == "UNIT" and .parent_id == $s.id) | .id ]) as $units
      | { n: (.key + 1), id: $s.id, name: $s.name,
          lo: ($s.course_learning_outcome != null),
          activities: ([ $all[] | select(.course_section_type == "ACTIVITY")
                         | select(.parent_id as $p | $units | index($p)) ] | length),
          tests: [ $all[] | select(.course_section_type == "CHAPTER_TEST" and .parent_id == $s.id) | .name ] })')
K=$(printf '%s' "$SECTIONS" | jq 'length')

printf '\nKHÓA: %s\n  id: %s · status: %s\n\n' "$CNAME" "$COURSE" "$CSTATUS"
printf '%s' "$SECTIONS" | jq -r '.[]
  | "  Section \(.n)  \(.name)  — \(.activities) activity"
    + (if .lo then " · có LO" else "" end)
    + (if (.tests | length) > 0 then " · Section Test: \(.tests | join(" | "))" else " · chưa có Section Test" end)'
printf '%s' "$TREE" | jq -r '
  [ .[] | select((.parent_id // "") == "" and .course_section_type != "CHAPTER") ]
  | if length == 0 then "  Test cấp khóa: chưa có"
    else .[] | "  Test cấp khóa: \(.course_section_type)  \(.name)" end'
printf '\n  %s Section hiện có → Section mới đánh số từ %s\n' "$K" "$((K + 1))"

if [ -n "$EXPECT" ] && [ "$EXPECT" != "$K" ]; then
  die "outline đã duyệt ghi $EXPECT Section, khóa hiện có $K.
  Khóa đã bị sửa sau khi duyệt — xuất lại outline, đừng chạy tiếp."
fi

# ---------- state ----------
if [ -n "$STATE" ]; then
  [ -f "$STATE" ] || { mkdir -p "$(dirname "$STATE")" && echo '{}' > "$STATE"; } \
    || die "không tạo được $STATE"
  old=$(jq -r '._course // empty' "$STATE")
  [ -z "$old" ] || [ "$old" = "$COURSE" ] \
    || die "$STATE là của khóa $old, không phải $COURSE — dùng state file mới"
  # section:N đã có mà khác id thật = state lệch với khóa. Không ghi đè.
  bad=$(jq -r --argjson s "$SECTIONS" '. as $st
    | [ $s[] | select(($st["section:\(.n)"] // .id) != .id) | "section:\(.n)" ] | join(", ")' "$STATE")
  [ -z "$bad" ] || die "$STATE có $bad trỏ tới id khác Section thật trên LMS — dừng, không ghi đè"
  jq --arg c "$COURSE" --argjson s "$SECTIONS" \
    '. + {_course: $c} + ([ $s[] | {key: "section:\(.n)", value: .id} ] | from_entries)' \
    "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE" || die "không ghi được $STATE"
  printf '  state: ghi section:1..%s vào %s\n' "$K" "$STATE"
fi

# ---------- session ----------
# Giống start.sh: giữ UPBASE_TOPIC_ID cũ, ghi atomic .tmp → chmod 600 → mv.
topic=""
if [ -r "$UPBASE_ENV_FILE" ]; then
  topic=$(sed -n 's/^UPBASE_TOPIC_ID=//p' "$UPBASE_ENV_FILE" 2>/dev/null | tail -n1 | tr -d '\r')
fi
tmp="${UPBASE_ENV_FILE}.tmp.$$"
{ printf '# UpBase session\n'
  printf 'UPBASE_SESSION_ENV=%s\n' "$UPBASE_ENV"
  printf 'UPBASE_TOKEN=%s\n' "$TOKEN"
  [ -n "$topic" ] && printf 'UPBASE_TOPIC_ID=%s\n' "$topic"
  printf 'UPBASE_COURSE_ID=%s\n' "$COURSE"
  printf 'UPBASE_BASE_URL=%s\n' "$UPBASE_BASE_URL"
} > "$tmp" 2>/dev/null || { rm -f "$tmp"; die "không ghi được $UPBASE_ENV_FILE"; }
chmod 600 "$tmp" 2>/dev/null || true
mv -f "$tmp" "$UPBASE_ENV_FILE" 2>/dev/null || { rm -f "$tmp"; die "không ghi được $UPBASE_ENV_FILE"; }

printf '\n=== SẴN SÀNG === môi trường %s · khóa %s\n' "$UPBASE_ENV" "$CNAME"
