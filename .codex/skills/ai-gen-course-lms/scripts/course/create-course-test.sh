#!/usr/bin/env bash
# Tạo một khung bài test rỗng sau khi đã dựng xong các Section
# (build-section.sh). Luồng skill không tạo Question Topic; câu hỏi tạo trước ở
# bước 7.1 bằng create-question.sh, rồi nối vào đây qua --questions.
# Resume qua cùng state file với build-section.sh.
#
#   create-course-test.sh --type MID_TERM_TEST|FINAL_TEST --name "…"
#                         [--state FILE] [--dry-run]
#
#   create-course-test.sh --type SECTION_TEST --section <N> --name "…"
#                         [--state FILE] [--dry-run]
#
# Setting bài test — lấy từ 6 nhãn trong tài liệu, bỏ cờ nào thì giữ QUIZ_CFG:
#   --question-type "<Type of Test:>"        Multiple Choice | Essay
#   --test-mode "<Test Mode:>"               Tutor | Exam
#   --graded "<Graded Assignment:>"          Yes | No
#   --pass-point "<Pass Point:>"             số, chấp nhận cả dạng "80%"
#   --grading-preference "<Grading Preference:>"  After all questions | After each question
#   --attempt "<Attempt:>"                   số lần làm lại, hoặc Unlimited
#
# --questions <questions.json>: nối câu hỏi đã tạo ở bước 7.1 vào bài test. Script
# đọc id từ state key `q:<test>:<n>`, nên create-question.sh PHẢI chạy trước.
# Bỏ cờ này thì bài test tạo rỗng (quiz_questions: []).
# --section: chỉ dùng với SECTION_TEST; đọc SECTION_ID từ state key `section:<N>`.
# API vẫn dùng enum quiz_for "CHAPTER" / quiz_type "CHAPTER_TEST" — đó là tên của
# backend, không đổi được. Mọi chỗ khác trong bộ script gọi là Section.
#
# Đọc session do scripts/course/start.sh ghi.
# Mặc định --state là ./state.json theo thư mục đang đứng, KHÁC với
# build-section.sh (lấy theo thư mục của file plan). Plan nằm ở thư mục khác thì
# phải truyền --state, nếu không lệnh này tạo state file trống mới và tạo lại bài
# test lần thứ hai.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/quiz-config.sh"

TYPE="" NAME="" STATE="state.json" SECTION="" DRY=0
QTYPE="" TMODE="" GRADED="" PASSPOINT="" GPREF="" ATTEMPT="" QFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type) [ $# -ge 2 ] || die "--type cần một giá trị"
                TYPE="$2"; shift 2 ;;
    --question-type) [ $# -ge 2 ] || die "--question-type cần một giá trị"
                QTYPE="$2"; shift 2 ;;
    --test-mode) [ $# -ge 2 ] || die "--test-mode cần một giá trị"
                TMODE="$2"; shift 2 ;;
    --graded) [ $# -ge 2 ] || die "--graded cần một giá trị"
                GRADED="$2"; shift 2 ;;
    --pass-point) [ $# -ge 2 ] || die "--pass-point cần một giá trị"
                PASSPOINT="$2"; shift 2 ;;
    --grading-preference) [ $# -ge 2 ] || die "--grading-preference cần một giá trị"
                GPREF="$2"; shift 2 ;;
    --attempt) [ $# -ge 2 ] || die "--attempt cần một giá trị"
                ATTEMPT="$2"; shift 2 ;;
    --questions) [ $# -ge 2 ] || die "--questions cần một giá trị"
                QFILE="$2"; shift 2 ;;
    --name) [ $# -ge 2 ] || die "--name cần một giá trị"
                NAME="$2"; shift 2 ;;
    --state) [ $# -ge 2 ] || die "--state cần một giá trị"
                STATE="$2"; shift 2 ;;
    --section) [ $# -ge 2 ] || die "--section cần một giá trị"
                SECTION="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    # In khối comment đầu file. Tự bám theo header nên không lệch khi header dài ra.
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) shift ;;
  esac
done

need_deps
case "$TYPE" in
  MID_TERM_TEST|FINAL_TEST) ;;
  SECTION_TEST)
    printf '%s' "$SECTION" | grep -qE '^[0-9]+$' \
      || die "--type SECTION_TEST cần --section <N> là số nguyên" ;;
  *) die "--type phải là MID_TERM_TEST, FINAL_TEST hoặc SECTION_TEST" ;;
esac
[ -n "$NAME" ] || die "cần --name"

[ -f "$STATE" ] || echo '{}' > "$STATE"

# --- quiz_questions: id câu hỏi đã tạo ở 7.1 --------------------------------
# Câu hỏi phải tồn tại TRƯỚC bài test: bài test tham chiếu id, không có endpoint
# gắn câu hỏi vào bài đã tạo. Id đọc từ state key `q:<test>:<n>` mà
# create-question.sh ghi, xếp theo số câu tăng dần.
QUESTIONS='[]'
NQ=0
if [ -n "$QFILE" ]; then
  QUESTIONS=$(build_quiz_questions "$QFILE" "$STATE") || exit 1
  NQ=$(printf '%s' "$QUESTIONS" | jq 'length')
fi

# --- Phần khác nhau giữa test cấp khóa và Section Test ------------------------
if [ "$TYPE" = "SECTION_TEST" ]; then
  KEY="sectiontest:$SECTION"
  SECTION_ID=$(jq -r --arg k "section:$SECTION" '.[$k] // empty' "$STATE")
  [ -n "$SECTION_ID" ] \
    || die "state thiếu key 'section:$SECTION' — chạy build-section.sh cho Section $SECTION trước, và kiểm tra --state có trỏ đúng file không"
  # course_id là BẮT BUỘC kể cả với SECTION_TEST — thiếu nó thì bài test không
  # được tạo. Đã xác nhận bằng request thật của giao diện.
  COURSE="${UPBASE_COURSE_ID:-}"
  [ -n "$COURSE" ] || die "chưa có UPBASE_COURSE_ID — chạy scripts/course/start.sh trước"
  # "CHAPTER"/"CHAPTER_TEST" là enum của backend, KHÔNG phải tên khái niệm ở đây.
  EXTRA=$(jq -nc --arg s "$SECTION_ID" --arg c "$COURSE" \
    '{quiz_for: "CHAPTER", quiz_type: "CHAPTER_TEST",
      course_section_id: $s, course_id: $c}')
else
  # Key theo loại bài: một state file giữ đúng một MID_TERM_TEST và một FINAL_TEST.
  # Khóa cần hai bài cùng loại thì bài thứ hai phải dùng state file riêng.
  KEY="coursetest:$TYPE"
  COURSE="${UPBASE_COURSE_ID:-}"
  [ -n "$COURSE" ] || die "chưa có UPBASE_COURSE_ID — chạy scripts/course/start.sh trước"
  EXTRA=$(jq -nc --arg c "$COURSE" --arg ty "$TYPE" \
    '{quiz_for: "COURSE", quiz_type: $ty, course_id: $c}')
fi

id=$(jq -r --arg k "$KEY" '.[$k] // empty' "$STATE")
if [ -n "$id" ]; then
  printf 'SKIP %-24s %s\n' "$KEY" "$id" >&2
  exit 0
fi

# --- Setting của bài test, từ 6 nhãn trong tài liệu --------------------------
# Cờ nào không truyền thì giữ nguyên giá trị QUIZ_CFG. Giá trị lạ thì DỪNG —
# đoán bừa là tạo bài test sai cấu hình mà API vẫn trả 201.
OVR='{}'
add_ovr() { OVR=$(printf '%s' "$OVR" | jq -c --arg k "$1" --argjson v "$2" '. + {($k):$v}'); }
norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' /_-'; }

if [ -n "$QTYPE" ]; then
  case "$(norm "$QTYPE")" in
    multiplechoice) add_ovr quiz_question_type '"MULTIPLE_CHOICE"' ;;
    essay)          add_ovr quiz_question_type '"ESSAY"' ;;
    *) die "--question-type không nhận '$QTYPE' — nhãn 'Type of Test:' chỉ hỗ trợ Multiple Choice hoặc Essay" ;;
  esac
fi
if [ -n "$TMODE" ]; then
  case "$(norm "$TMODE")" in
    tutor)                 add_ovr is_tutor true ;;
    exam|test|kiemtra)     add_ovr is_tutor false ;;
    *) die "--test-mode không nhận '$TMODE' — nhãn 'Test Mode:' chỉ hỗ trợ Tutor hoặc Exam" ;;
  esac
fi
if [ -n "$GRADED" ]; then
  case "$(norm "$GRADED")" in
    yes|true|co) add_ovr is_graded true ;;
    no|false|khong) add_ovr is_graded false ;;
    *) die "--graded không nhận '$GRADED' — nhãn 'Graded Assignment:' chỉ hỗ trợ Yes hoặc No" ;;
  esac
fi
if [ -n "$PASSPOINT" ]; then
  # Tài liệu ghi "80%" — bỏ dấu phần trăm, giữ số.
  pp=$(printf '%s' "$PASSPOINT" | tr -d ' %')
  printf '%s' "$pp" | grep -qE '^[0-9]+$' || die "--pass-point phải là số, nhận: $PASSPOINT"
  add_ovr required_percent_score "$pp"
fi
if [ -n "$GPREF" ]; then
  case "$(norm "$GPREF")" in
    afterallquestions)  add_ovr grading_preference '"AFTER_ALL_QUESTIONS"' ;;
    aftereachquestion)  add_ovr grading_preference '"AFTER_EACH_QUESTION"' ;;
    *) die "--grading-preference không nhận '$GPREF' — nhãn 'Grading Preference:' chỉ hỗ trợ 'After all questions' hoặc 'After each question'" ;;
  esac
fi
if [ -n "$ATTEMPT" ] && [ "$(norm "$ATTEMPT")" = "unlimited" ]; then
  add_ovr is_limited false
elif [ -n "$ATTEMPT" ]; then
  printf '%s' "$ATTEMPT" | grep -qE '^[0-9]+$' || die "--attempt phải là số nguyên hoặc Unlimited, nhận: $ATTEMPT"
  # is_limited bật thì BẮT BUỘC kèm limit_count — thiếu một trong hai thì giới
  # hạn số lần làm không có hiệu lực, mà API vẫn trả 201.
  add_ovr is_limited true
  add_ovr limit_count "$ATTEMPT"
fi

payload=$(jq -nc --arg nm "$NAME" --argjson cfg "$QUIZ_CFG" \
  --argjson extra "$EXTRA" --argjson qs "$QUESTIONS" --argjson ovr "$OVR" \
  '$cfg + $extra + $ovr + {name: $nm, quiz_questions: $qs}')

if [ "$DRY" = "1" ]; then
  printf '[dry-run] POST /quiz  %s  (%d câu)\n' "$KEY" "$NQ" >&2
  printf '%s\n' "$payload" | jq .
  printf '=== DRY-RUN — CHƯA TẠO GÌ === (state: %s)\n' "$STATE" >&2
  exit 0
fi

load_token
api POST "/quiz" "$payload"; check_auth
id=$(api_body | jq -r '.data.id // empty')
if [ -z "$id" ]; then
  printf 'FAIL %-24s http=%s %s\n' "$KEY" "$API_HTTP" \
    "$(api_body | jq -c '.error // .' 2>/dev/null | head -c 300)" >&2
  exit 1
fi

jq --arg k "$KEY" --arg v "$id" '. + {($k):$v}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
printf 'OK   %-24s %s  (%s, %d câu)\n' "$KEY" "$id" "$NAME" "$NQ" >&2
