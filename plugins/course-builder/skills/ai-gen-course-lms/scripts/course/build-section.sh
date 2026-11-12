#!/usr/bin/env bash
# Dựng một Section từ file plan:
#   section -> unit -> learning outcome -> activity -> tab -> document -> section test
# Resume được: mọi id tạo ra ghi ngay vào state file, chạy lại thì SKIP phần đã có.
#
#   build-section.sh <plan.json> [--state FILE] [--dry-run]
#
# Đọc session do scripts/course/start.sh ghi.
# Chạy TUẦN TỰ từng plan một: hai tiến trình cùng ghi một state file sẽ đè nhau.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"
. "$HERE/quiz-config.sh"

PLAN="" STATE="" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --state) [ $# -ge 2 ] || die "--state cần một giá trị"
                STATE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    # In khối comment đầu file. Tự bám theo header nên không lệch khi header dài ra.
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) PLAN="$1"; shift ;;
  esac
done

need_deps
[ -n "$PLAN" ] && [ -f "$PLAN" ] || die "cần đường dẫn tới file plan JSON"
jq -e . "$PLAN" >/dev/null 2>&1 || die "$PLAN không phải JSON hợp lệ"
STATE="${STATE:-$(dirname "$PLAN")/state.json}"
[ -f "$STATE" ] || echo '{}' > "$STATE"

N=$(jq -r '.section.n // empty' "$PLAN")
SNAME=$(jq -r '.section.name // empty' "$PLAN")
[ -n "$N" ] && [ -n "$SNAME" ] || die "plan thiếu .section.n hoặc .section.name"
NACT=$(jq '.activities | length' "$PLAN")
[ "$NACT" -gt 0 ] || die "plan không có activity nào"

# Validate cấu trúc TRƯỚC, cho cả dry-run lẫn chạy thật. Activity thiếu .tabs hoặc
# Tab thiếu .docs mà lọt qua đây thì các vòng lặp bên dưới chạy 0 lần và Section
# tạo ra rỗng — không có lỗi nào báo.
# .tabs ĐƯỢC PHÉP rỗng: tài liệu không khai `Tab …:` nào thì Activity không có tab
# nào cả — đúng thiết kế, không phải thiếu sót. Nhưng phải là mảng.
jq -e '[.activities[] | .tabs // []] | all(type == "array")' "$PLAN" >/dev/null 2>&1 \
  || die "plan có activity mà .tabs không phải mảng"
# Tab đã tạo thì phải có document, trừ Tab có document QUIZ được chủ ý dời sang
# bước 7. Dấu deferred_quiz giữ Tab trong bước 6 mà không tạo placeholder.
jq -e '[.activities[] | (.tabs // [])[]
  | if .deferred_quiz == true
    then (.docs | type == "array" and length == 0)
    else (.docs | type == "array" and length > 0)
    end] | all' "$PLAN" >/dev/null 2>&1 \
  || die "plan có tab thiếu .docs/rỗng; chỉ cho phép docs rỗng với deferred_quiz: true"

# Shape cũ gom hết LO con vào .outcomes cấp Section, không gắn được vào Activity
# nào. Bắt ngay thay vì tạo ra một cây LO rời rạc.
if jq -e 'has("outcomes") or (.activities // [] | any(has("outcomes")))' "$PLAN" >/dev/null 2>&1; then
  die "plan dùng shape cũ: .outcomes chứa nội dung LO.
  Giờ LO con khai một chỗ ở .learning_outcome.items[] = [{n, description}],
  Activity trỏ tới bằng .outcome_refs[] = [1, 3] — xem references/create-structure.md"
fi
if jq -e '.activities // [] | any(has("quiz"))' "$PLAN" >/dev/null 2>&1; then
  die "plan dùng tên cũ: .activities[].quiz.
  Đổi thành .display_icon = 'TEXT' | 'VIDEO' | 'QUIZ' (từ nhãn 'Type of Activity:');
  is_graded suy ra từ nó, không khai riêng"
fi

# display_icon chỉ nhận đúng 3 giá trị. Giá trị lạ lọt xuống thì API nhận hay
# không cũng không biết trước — chặn ở đây, và tài liệu sai phải ghi vào Sai lệch.
badicon=$(jq -r '[ .activities[] | .display_icon // "TEXT"
  | select(. != "TEXT" and . != "VIDEO" and . != "QUIZ") ] | unique | join(", ")' "$PLAN")
[ -z "$badicon" ] \
  || die "display_icon không hợp lệ: $badicon — chỉ nhận TEXT, VIDEO, QUIZ.
  Tài liệu ghi sai ở nhãn 'Type of Activity:' thì quy về TEXT và ghi một dòng vào Sai lệch của outline."

if jq -e 'has("chapter_test") or has("chapter_test_name")' "$PLAN" >/dev/null 2>&1; then
  die "plan dùng tên cũ: .chapter_test / .chapter_test_name.
  Đổi thành .section_test / .section_test_name"
fi

# Tham chiếu tới LO con không tồn tại là lỗi TÀI LIỆU, không phải lỗi API — nó
# lọt xuống thành Activity thiếu LO mà vẫn trả 201. Bắt ngay.
badref=$(jq -r '((.learning_outcome.items // []) | map(.n)) as $have
  | [ .activities[] | (.outcome_refs // [])[] | select(. as $r | $have | index($r) | not) ]
  | unique | map(tostring) | join(", ")' "$PLAN")
[ -z "$badref" ] \
  || die "plan tham chiếu LO con không tồn tại: $badref — Section chỉ khai $(jq -c '[(.learning_outcome.items // [])[].n]' "$PLAN")"

info "Section $N. $SNAME — $NACT activity"
if [ "$DRY" -eq 1 ]; then
  # 0 LO con thì KHÔNG có node LO nào được tạo — nói thẳng, đừng in tên node ma.
  jq -r --argjson n "$N" '((.learning_outcome.items // []) | length) as $k
         | if $k == 0 then "  LO: không tạo node nào — Section không khai Learning Outcome"
           else "  LO to: \(.learning_outcome.name // "Learning Outcome \($n)")  →  \($k) LO con [\([(.learning_outcome.items // [])[].n] | sort | map(tostring) | join(", "))]"
           end' "$PLAN" >&2
  # LO con không Activity nào dùng vẫn được tạo — người dùng cần biết trước.
  jq -r '([.activities[] | (.outcome_refs // [])[]] | unique) as $used
         | [ (.learning_outcome.items // [])[] | select(.n as $x | $used | index($x) | not) | .n ]
         | if length > 0 then "  ! LO con không Activity nào dùng: \(map(tostring) | join(", "))" else empty end' \
    "$PLAN" >&2
  # In cả duration để soát trước khi tạo: nó phải khớp `Time:` trong tài liệu Lark.
  # Activity không khai duration hiện `30 phút (MẶC ĐỊNH)` — dấu hiệu tài liệu
  # thiếu `Time:`, không phải con số đã duyệt.
  jq -r --argjson dd "$ACTIVITY_DEFAULT_DURATION" '.activities[]
         | (.tabs // []) as $tabs
         | "  \(.name)  [\(.display_icon // "TEXT")]  →  \(.duration // $dd) phút"
           + (if .duration then "" else " (MẶC ĐỊNH — tài liệu thiếu `Time:`)" end)
           + ", LO [\((.outcome_refs // []) | map(tostring) | join(", "))]"
           + ", \($tabs|length) tab, \([$tabs[].docs|length]|add // 0) doc"
           + (if ((.files // []) | length) > 0 then ", \((.files|length)) resource" else "" end)' \
    "$PLAN" >&2 || die "không đọc được .activities của $PLAN"
  # Doc VIDEO thiếu video_quiz_ids chỉ vỡ ở lúc gọi API thật, mà lúc đó Tab đã
  # tạo rồi — bắt ngay trong dry-run.
  bad=$(jq -r '[.activities[] | .tabs[]? | .docs[]?
        | select(.type == "VIDEO")
        | select((.video_quiz_ids // []) | length == 0)] | length' "$PLAN")
  [ "$bad" = "0" ] \
    || die "$bad doc VIDEO thiếu video_quiz_ids — lấy quiz_id từ media-manifest.json (upload-media.sh)"

  # duration < 1 làm API trả 422 exceptions.invalid_data, mà lúc đó Section và
  # Unit đã tạo rồi. `Time:` quy ra phút phải luôn làm tròn LÊN, tối thiểu 1.
  badd=$(jq -r '[.activities[] | select(has("duration"))
        | select((.duration | type) != "number" or .duration < 1)] | length' "$PLAN")
  [ "$badd" = "0" ] \
    || die "$badd activity có duration < 1 hoặc không phải số — quy 'Time:' trong tài liệu ra phút nguyên, làm tròn lên, tối thiểu 1"

  # Handout thiếu resource_id thì Activity tạo ra mất file đính kèm, và không gắn
  # lại được. Bắt ở đây thay vì để lọt.
  badf=$(jq -r '[.activities[] | (.files // [])[]
        | select((.resource_id // "") == "")] | length' "$PLAN")
  [ "$badf" = "0" ] \
    || die "$badf handout trong .activities[].files thiếu resource_id — lấy từ media-manifest.json (upload-media.sh)"
  info "--dry-run: dừng trước khi gọi API"
  exit 0
fi

COURSE="${UPBASE_COURSE_ID:-}"
[ -n "$COURSE" ] || die "chưa có UPBASE_COURSE_ID — chạy scripts/course/start.sh trước"
load_token

# create <state-key> <PATH> <payload>  → in ra id trên stdout, log trên stderr.
# State key không chứa course_id: một state file phục vụ đúng một khóa học.
create() {
  local key="$1" path="$2" body="$3" id
  id=$(jq -r --arg k "$key" '.[$k] // empty' "$STATE")
  if [ -n "$id" ]; then printf 'SKIP %-20s %s\n' "$key" "$id" >&2; printf '%s' "$id"; return 0; fi

  api POST "$path" "$body"; check_auth
  id=$(api_body | jq -r '.data.id // empty')
  if [ -z "$id" ]; then
    printf 'FAIL %-20s http=%s %s\n' "$key" "$API_HTTP" \
      "$(api_body | jq -c '.error // .' 2>/dev/null | head -c 300)" >&2
    return 1
  fi
  jq --arg k "$key" --arg v "$id" '. + {($k):$v}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  printf 'OK   %-20s %s\n' "$key" "$id" >&2
  printf '%s' "$id"
}

# ---------- Section ----------
# Khóa 3 cấp: KHÔNG gửi parent_id. position = số Section.
# Path /course-sections/chapter là tên endpoint của backend, không đổi được.
payload=$(jq -c --arg c "$COURSE" --argjson n "$N" '{
    name: .section.name,
    short_name: (.section.short_name // ""),
    description: (.section.description // ""),
    course_id: $c, position: $n }' "$PLAN")
SECTION_ID=$(create "section:$N" "/course-sections/chapter" "$payload") || exit 1

# ---------- Unit ----------
# Đúng một Unit cho mỗi Section, tên cố định, position 1.
payload=$(jq -nc --arg c "$COURSE" --arg p "$SECTION_ID" \
  --arg un "$UNIT_NAME" --argjson up "$UNIT_POSITION" \
  '{name:$un, parent_id:$p, course_id:$c, position:$up}')
UNIT=$(create "unit:$N" "/course-sections/unit" "$payload") || exit 1

# ---------- Learning Outcome ----------
# MỘT LO "to" cho cả Section (course_section_id là SECTION_ID, không phải
# UNIT_ID). LO con không phải node riêng — chúng là outcomes[] bên trong nó.
# Activity chỉ THAM CHIẾU id, nên phải tạo LO trước rồi mới tạo Activity.
#
# .learning_outcome.items[] khai theo SỐ trong tài liệu (`Learning Outcome 2:`).
# Activity trỏ tới bằng .outcome_refs[] = [2, 3]. Một LO con dùng chung cho nhiều
# Activity là bình thường; map theo SỐ, tuyệt đối không theo thứ tự xuất hiện.
LO_KEY="lo:$N"; LO_OUT_KEY="lo_outcomes:$N"
LO_ID=$(jq -r --arg k "$LO_KEY" '.[$k] // empty' "$STATE")
LO_MAP=$(jq -c --arg k "$LO_OUT_KEY" '.[$k] // {}' "$STATE")
NOUT=$(jq '(.learning_outcome.items // []) | length' "$PLAN")

if [ "$NOUT" -gt 0 ] && [ -n "$LO_ID" ]; then
  printf 'SKIP %-20s %s (%s LO con)\n' "$LO_KEY" "$LO_ID" "$(printf '%s' "$LO_MAP" | jq 'length')" >&2
elif [ "$NOUT" -gt 0 ]; then
  # Gửi outcomes[] theo thứ tự SỐ tăng dần để id trả về map lại được chắc chắn.
  ORDER=$(jq -c '(.learning_outcome.items // []) | map(.n) | sort' "$PLAN")
  payload=$(jq -c --arg sec "$SECTION_ID" --argjson n "$N" '{
      name: (.learning_outcome.name // "Learning Outcome \($n)"),
      description: (.learning_outcome.description // .section.description // ""),
      outcomes: [ (.learning_outcome.items // []) | sort_by(.n)[] | {description: .description} ],
      text_editor_files: [],
      course_section_id: $sec }' "$PLAN")

  api POST "/course_learning_outcomes" "$payload"; check_auth
  LO_ID=$(api_body | jq -r '.data.id // empty')
  [ -n "$LO_ID" ] || { printf 'FAIL %-20s http=%s %s\n' "$LO_KEY" "$API_HTTP" \
      "$(api_body | jq -c '.error // .' 2>/dev/null | head -c 300)" >&2; exit 1; }

  # Tên mảng chứa LO con trong .data CHƯA kiểm chứng — dò mảng đầu tiên có phần
  # tử mang .id, cùng cách create-course.sh dò course_categories. Giữ nguyên thứ tự.
  IDS=$(api_body | jq -c '
    (.data // {}) as $d
    | [ $d | to_entries[] | select((.value | type) == "array") | .value ] | add // []
    | map(select(type == "object" and has("id")) | .id)')

  got=$(printf '%s' "$IDS" | jq 'length')
  # Thiếu id là hỏng KHÔNG SỬA ĐƯỢC: Activity gắn LO con lúc TẠO, không có
  # endpoint gắn sau. Dừng trước khi tạo Activity nào.
  [ "$got" = "$NOUT" ] || die "LO tạo xong ($LO_ID) nhưng đọc được $got/$NOUT id LO con.
  Activity chỉ gắn được LO con lúc tạo, nên dừng tại đây.
  Response: $(api_body | jq -c '.data' 2>/dev/null | head -c 400)"

  # Ghép id trở lại theo SỐ: ORDER[i] là số của LO con thứ i đã gửi.
  LO_MAP=$(jq -nc --argjson order "$ORDER" --argjson ids "$IDS" \
    '[ range(0; $order | length) | {key: ($order[.] | tostring), value: $ids[.]} ] | from_entries')

  jq --arg k "$LO_KEY" --arg v "$LO_ID" --arg ok "$LO_OUT_KEY" --argjson m "$LO_MAP" \
     '. + {($k):$v, ($ok):$m}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  printf 'OK   %-20s %s (%s LO con: %s)\n' "$LO_KEY" "$LO_ID" "$NOUT" \
    "$(printf '%s' "$LO_MAP" | jq -r 'keys_unsorted | join(", ")')" >&2
fi

# ---------- Activity → Tab → Document ----------
# parent_id của Activity là UNIT_ID; gắn vào SECTION_ID thì Activity không hiện.
for ((a = 0; a < NACT; a++)); do
  # Đổi .outcome_refs[] (các SỐ tài liệu khai) thành id qua LO_MAP. Số không có
  # trong map là tham chiếu tới LO không tồn tại — bỏ, đã cảnh báo ở dry-run.
  oids=$(jq -c --argjson m "$LO_MAP" --argjson i "$a" \
    '[ (.activities[$i].outcome_refs // [])[] | $m[tostring] | select(. != null) ]' "$PLAN")

  # files[] = resource đính kèm Activity. Phải có resource_id TRƯỚC khi tạo
  # Activity (upload ở bước 5); không có endpoint gắn file vào Activity đã tạo.
  payload=$(jq -c --arg c "$COURSE" --arg u "$UNIT" --argjson i "$a" \
    --argjson dd "$ACTIVITY_DEFAULT_DURATION" \
    --arg lo "$LO_ID" --argjson oids "$oids" '.activities[$i]
      | (.display_icon // "TEXT") as $icon
      | { name, parent_id: $u,
          is_graded: ($icon == "QUIZ"),
          duration: (.duration // $dd),
          display_icon: $icon,
          files: [ (.files // [])[] | {resource_id: .resource_id, type: (.type // "attached")} ],
          course_id: $c, position: ($i + 1) }
      + (if $lo == "" then {} else {course_learning_outcome_id: $lo, course_outcome_ids: $oids} end)' "$PLAN")
  ACT=$(create "act:$N:$a" "/course-sections/activity" "$payload") || exit 1

  NTAB=$(jq ".activities[$a].tabs // [] | length" "$PLAN")
  for ((t = 0; t < NTAB; t++)); do
    payload=$(jq -c --arg c "$COURSE" --arg s "$ACT" --argjson i "$a" --argjson j "$t" \
      '{course_section_id: $s, tab_name: .activities[$i].tabs[$j].name, course_id: $c}' "$PLAN")
    TAB=$(create "tab:$N:$a:$t" "/course-sections/tab" "$payload") || exit 1

    # Document xếp theo thứ tự tạo — thứ tự trong plan là thứ tự học viên đọc.
    NDOC=$(jq ".activities[$a].tabs[$t].docs | length" "$PLAN")
    for ((d = 0; d < NDOC; d++)); do
      dtype=$(jq -r ".activities[$a].tabs[$t].docs[$d].type" "$PLAN")
      if [ "$dtype" = "QUIZ" ]; then
        # Document QUIZ: quiz_type QUIZ, KHÔNG có quiz_for.
        payload=$(jq -nc --arg c "$COURSE" --argjson cfg "$QUIZ_CFG" \
          '{type:"QUIZ", payload: ($cfg + {quiz_type:"QUIZ"}), course_id:$c}')
      elif [ "$dtype" = "VIDEO" ]; then
        # Document VIDEO: video_quiz_ids là QUIZ_ID (không phải resource_id) do
        # upload-media.sh lấy từ .data[0].quiz_id. Plan phải điền sẵn.
        nq=$(jq ".activities[$a].tabs[$t].docs[$d].video_quiz_ids | length // 0" "$PLAN")
        [ "$nq" -gt 0 ] || die "doc[$d] của tab[$t] activity[$a] là VIDEO nhưng thiếu video_quiz_ids — lấy quiz_id từ media-manifest.json"
        payload=$(jq -c --arg c "$COURSE" --argjson i "$a" --argjson j "$t" --argjson k "$d" \
          '.activities[$i].tabs[$j].docs[$k]
           | {type:"VIDEO", payload:{video_quiz_ids:.video_quiz_ids}, course_id:$c}' "$PLAN")
      else
        payload=$(jq -c --arg c "$COURSE" --argjson i "$a" --argjson j "$t" --argjson k "$d" \
          '.activities[$i].tabs[$j].docs[$k]
           | {type:"TEXT", payload:{content:.content, attachments:[]},
              text_editor_files:[], course_id:$c}' "$PLAN")
      fi
      create "doc:$N:$a:$t:$d" "/course-sections/tab/$TAB/document" "$payload" >/dev/null || exit 1
    done
  done
done

# ---------- Section Test ----------
# quiz_for/quiz_type giữ enum "CHAPTER"/"CHAPTER_TEST" của backend;
# course_section_id = SECTION_ID.
if [ "$(jq -r '.section_test // false' "$PLAN")" = "true" ]; then
  # Tên lấy từ plan; không tự ghép. Bỏ trống thì mới dùng tên suy ra từ Section.
  CT_NAME=$(jq -r '.section_test_name // empty' "$PLAN")
  payload=$(jq -nc --arg c "$COURSE" --arg ch "$SECTION_ID" \
    --arg nm "${CT_NAME:-Section Test $N - $SNAME}" \
    --argjson cfg "$QUIZ_CFG" \
    '$cfg + {name:$nm, quiz_for:"CHAPTER", quiz_type:"CHAPTER_TEST",
             course_id:$c, course_section_id:$ch}')
  # Khóa PHẢI khác `sectiontest:$N` của create-course-test.sh: trùng khóa thì bài
  # khung test rỗng ở bước 7 bị SKIP im lặng, exit 0, tưởng đã tạo.
  create "sectiontest-shell:$N" "/quiz" "$payload" >/dev/null || exit 1
fi

read -r ntab ndoc <<<"$(jq -r '"\([.activities[].tabs|length]|add) \([.activities[].tabs[].docs|length]|add)"' "$PLAN")"
printf -- '--- Section %s xong: %s activity, %s tab, %s document  (state: %s)\n' \
  "$N" "$NACT" "$ntab" "$ndoc" "$STATE" >&2
