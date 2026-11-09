#!/usr/bin/env bash
# Thêm một Document QUIZ vào một Tab đã tồn tại. Chạy ở bước 7 sau khi
# build-section.sh đã tạo Tab.
#
#   create-tab-quiz.sh --tab <TAB_ID> [--state FILE] [--dry-run]
#   create-tab-quiz.sh --section <N> --activity <A> --tab-index <T>
#                      [--state FILE] [--dry-run]
#
# --questions <questions.json>: nối câu hỏi đã tạo ở bước 7.1 (id đọc từ state).
# Bỏ cờ này thì Document QUIZ tạo rỗng — không có endpoint gắn câu hỏi vào
# document đã tạo, nên bỏ sót là phải nhập tay trên giao diện.
# --tab: TAB_ID trực tiếp. Hoặc để script tra từ state key `tab:<N>:<A>:<T>`
#   (--activity và --tab-index đếm TỪ 0, giống key mà build-section.sh ghi).
#
# Document xếp theo THỨ TỰ TẠO. Tab kiểm tra nên đã có Doc TEXT hướng dẫn làm bài
# từ bước 6; quiz thêm ở đây sẽ nằm sau nó, đúng thứ tự cần.
#
# Đọc session do scripts/course/start.sh ghi.
# Mặc định --state là ./state.json theo thư mục đang đứng, KHÁC với
# build-section.sh (lấy theo thư mục của file plan) — trỏ sai là tạo quiz lần hai.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/quiz-config.sh"

TAB="" SECTION="" ACT="" TABIDX="" STATE="state.json" DRY=0 QFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tab) [ $# -ge 2 ] || die "--tab cần một giá trị"
                TAB="$2"; shift 2 ;;
    --section) [ $# -ge 2 ] || die "--section cần một giá trị"
                SECTION="$2"; shift 2 ;;
    --activity) [ $# -ge 2 ] || die "--activity cần một giá trị"
                ACT="$2"; shift 2 ;;
    --questions) [ $# -ge 2 ] || die "--questions cần một giá trị"
                QFILE="$2"; shift 2 ;;
    --tab-index) [ $# -ge 2 ] || die "--tab-index cần một giá trị"
                TABIDX="$2"; shift 2 ;;
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
[ -f "$STATE" ] || echo '{}' > "$STATE"

# TAB_ID: nhận trực tiếp, hoặc tra từ state theo ba chỉ số.
if [ -z "$TAB" ]; then
  for v in SECTION:"$SECTION" ACT:"$ACT" TABIDX:"$TABIDX"; do
    printf '%s' "${v#*:}" | grep -qE '^[0-9]+$' \
      || die "thiếu --tab, mà cũng chưa đủ --section/--activity/--tab-index (đều phải là số)"
  done
  TKEY="tab:$SECTION:$ACT:$TABIDX"
  TAB=$(jq -r --arg k "$TKEY" '.[$k] // empty' "$STATE")
  [ -n "$TAB" ] \
    || die "state thiếu key '$TKEY' — chạy build-section.sh cho Section $SECTION trước, và kiểm tra --state có trỏ đúng file không"
fi

COURSE="${UPBASE_COURSE_ID:-}"
[ -n "$COURSE" ] || die "chưa có UPBASE_COURSE_ID — chạy scripts/course/start.sh trước"

QUESTIONS='[]'
NQ=0
if [ -n "${QFILE:-}" ]; then
  QUESTIONS=$(build_quiz_questions "$QFILE" "$STATE") || exit 1
  NQ=$(printf '%s' "$QUESTIONS" | jq 'length')
fi

# Key theo TAB_ID: một Tab đúng một Document QUIZ. Tab cần hai quiz thì dùng
# state file riêng cho cái thứ hai.
KEY="tabquiz:$TAB"
id=$(jq -r --arg k "$KEY" '.[$k] // empty' "$STATE")
if [ -n "$id" ]; then
  printf 'SKIP %-24s %s\n' "$KEY" "$id" >&2
  exit 0
fi

# quiz_questions nằm TRONG .payload ở endpoint này — khác /quiz (ở gốc payload).
# Document QUIZ: quiz_type QUIZ, KHÔNG có quiz_for.
payload=$(jq -nc --arg c "$COURSE" --argjson cfg "$QUIZ_CFG" --argjson qs "$QUESTIONS" \
  '{type: "QUIZ",
    payload: ($cfg + {quiz_type: "QUIZ", quiz_questions: $qs}),
    course_id: $c}')

if [ "$DRY" = "1" ]; then
  printf '[dry-run] POST /course-sections/tab/%s/document  (%d câu)\n' "$TAB" "$NQ" >&2
  printf '%s\n' "$payload" | jq .
  printf '=== DRY-RUN — CHƯA TẠO GÌ === (state: %s)\n' "$STATE" >&2
  exit 0
fi

load_token
api POST "/course-sections/tab/$TAB/document" "$payload"; check_auth
id=$(api_body | jq -r '.data.id // empty')
if [ -z "$id" ]; then
  printf 'FAIL %-24s http=%s %s\n' "$KEY" "$API_HTTP" \
    "$(api_body | jq -c '.error // .' 2>/dev/null | head -c 300)" >&2
  exit 1
fi

jq --arg k "$KEY" --arg v "$id" '. + {($k):$v}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
printf 'OK   %-24s %s  (%d câu)\n' "$KEY" "$id" "$NQ" >&2
