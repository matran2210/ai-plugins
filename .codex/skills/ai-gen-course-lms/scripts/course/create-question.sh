#!/usr/bin/env bash
# Tạo câu hỏi cho một bài test, từ file JSON đã soạn ở bước 7.
#
#   create-question.sh <questions.json> [--state FILE] [--manifest FILE] [--dry-run]
#
# Một file cho một bài test. Mỗi câu là một POST /question/single vào ngân hàng
# câu hỏi của khóa (question_filter.course_id = khóa đang dựng).
#
# Bảy loại câu hỏi, ba hình dạng plan khác nhau:
#   .answers    One Choice · Multiple Choice · True / False
#   .matchings  Matching
#   .blanks     Select Word · Fill Word · Drag & Drop  (+ .distractors cho Drag & Drop)
# Hình dạng của từng loại: references/question-types.md
#
# Ảnh trong đề bài: .images = [đường dẫn file, …] theo thứ tự tài liệu. Script tra
# resource_id trong manifest (mặc định media-manifest.json cạnh file câu hỏi) rồi
# nối <img src="PRESIGN_URL" … resource_id="…"> vào SAU đề bài. Ảnh phải đã upload
# bằng upload-media.sh --folder-type QUESTION — thiếu là dừng trước khi gọi API.
#
# Resume qua state file: câu đã tạo in SKIP, không tạo trùng.
#
# Đọc session do scripts/course/start.sh ghi. Phần bất biến của payload nằm ở
# QUESTION_CFG trong scripts/config.sh.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

QFILE="" STATE="" MANIFEST="" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --state) [ $# -ge 2 ] || die "--state cần một giá trị"
                STATE="$2"; shift 2 ;;
    --manifest) [ $# -ge 2 ] || die "--manifest cần một giá trị"
                MANIFEST="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) QFILE="$1"; shift ;;
  esac
done

need_deps
[ -n "$QFILE" ] && [ -f "$QFILE" ] || die "cần đường dẫn tới file câu hỏi JSON"
jq -e . "$QFILE" >/dev/null 2>&1 || die "$QFILE không phải JSON hợp lệ"
STATE="${STATE:-$(dirname "$QFILE")/state.json}"
[ -f "$STATE" ] || echo '{}' > "$STATE"
MANIFEST="${MANIFEST:-$(dirname "$QFILE")/media-manifest.json}"

TEST=$(jq -r '.test // empty' "$QFILE")
[ -n "$TEST" ] || die "file thiếu .test — khóa để đặt state key, ví dụ \"final\", \"mid\", \"section:1\""
NQ=$(jq '.questions | length' "$QFILE")
[ "$NQ" -gt 0 ] || die "file không có câu hỏi nào"

# --- Hàm dùng chung cho mọi khối jq bên dưới ---------------------------------
# qt   chuẩn hóa qtype: nhận cả nguyên văn nhãn Lark lẫn enum API, hai dạng
#      khớp nhau từng chữ sau khi bỏ hoa thường và ký tự không phải chữ cái.
# nblank  đếm ô trống trong đề bài. {{blank}} là ký hiệu DUY NHẤT của plan;
#      thẻ <span> thật do script này sinh ở khâu tạo, không ai gõ tay.
JQ_LIB='
def qt: (.qtype // "" | ascii_downcase | gsub("[^a-z]";""));
def qenum: qt
  | if   . == "onechoice"      then "ONE_CHOICE"
    elif . == "multiplechoice" then "MULTIPLE_CHOICE"
    elif . == "truefalse"      then "TRUE_FALSE"
    elif . == "matching"       then "MATCHING"
    elif . == "selectword"     then "SELECT_WORD"
    elif . == "fillword"       then "FILL_WORD"
    elif . == "dragdrop"       then "DRAG_DROP"
    else "?" end;
def isold:   qt | (. == "onechoice" or . == "multiplechoice" or . == "truefalse");
def isblank: qt | (. == "selectword" or . == "fillword" or . == "dragdrop");
def nblank: (.content // "") | [ match("\\{\\{blank\\}\\}"; "g") ] | length;
def alltexts:
    ((.answers     // []) | map(.answer // ""))
  + ((.matchings   // []) | map((.left // ""), (.right // "")))
  + ((.blanks      // []) | map(((.correct // [])[]), ((.distractors // [])[])))
  + ( .distractors // []);
'

# --- Validate trước, cho cả dry-run lẫn chạy thật -----------------------------
# Sai ở đây mà lọt xuống thì câu hỏi tạo ra hỏng và KHÔNG xóa được bằng bộ script
# này — người dùng phải vào giao diện dọn tay.

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(qenum == "?")
  | "câu \(.n): qtype=\(.qtype // "thiếu")" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "qtype không hợp lệ: $bad
  Nhận nguyên văn nhãn Lark hoặc enum API, bảy loại:
  'One Choice'/ONE_CHOICE · 'Multiple Choice'/MULTIPLE_CHOICE · 'True / False'/TRUE_FALSE
  'Matching'/MATCHING · 'Select Word'/SELECT_WORD · 'Fill Word'/FILL_WORD · 'Drag & Drop'/DRAG_DROP"

# display_type KHÔNG được khai trực tiếp. Nhãn tài liệu là `One column` /
# `Two column`, mà giá trị API là HORIZONTAL / VERTICAL — NGƯỢC với trực giác và
# hai cặp từ chẳng giống
# nhau, nên để bên soạn plan tự quy đổi là chỗ dễ chọn ngược nhất. Quy đổi làm ở
# ĐÂY, plan chỉ được chép nguyên văn nhãn vào .layout.
if jq -e '.questions // [] | any(has("display_type"))' "$QFILE" >/dev/null 2>&1; then
  die "plan khai .display_type — trường này script tự suy, không khai tay.
  Chép nguyên văn nhãn 'Question Layout:' vào .layout: 'One column' hoặc 'Two column'."
fi

bad=$(jq -r '[ .questions[]
  | (.layout // "" | ascii_downcase | gsub("[^a-z]";"")) as $l
  | select($l != "onecolumn" and $l != "twocolumn")
  | "câu \(.n): layout=\(.layout // "thiếu")" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "layout không hợp lệ: $bad
  Chỉ nhận nguyên văn nhãn 'Question Layout:' của tài liệu: 'One column' → HORIZONTAL,
  'Two column' → VERTICAL. Đừng ghi VERTICAL/HORIZONTAL vào .layout."

# Mỗi loại một hình dạng plan. Khai nhầm trường là dấu hiệu chọn nhầm loại —
# chặn ở đây rẻ hơn nhiều so với đi dọn tay trên giao diện.
bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | . as $q
  | ( if (qt) == "matching" then
          (if ($q|has("answers"))     then ["khai .answers — Matching dùng .matchings"] else [] end)
        + (if ($q|has("blanks"))      then ["khai .blanks — Matching không có ô trống"] else [] end)
        + (if ($q|has("distractors")) then ["khai .distractors — Matching không có đáp án nhiễu"] else [] end)
        + (if (nblank) > 0            then ["đề bài có {{blank}} — Matching không có ô trống"] else [] end)
      elif (isblank) then
          (if ($q|has("answers"))   then ["khai .answers — loại có ô trống dùng .blanks"] else [] end)
        + (if ($q|has("matchings")) then ["khai .matchings"] else [] end)
      else
          (if ($q|has("blanks"))      then ["khai .blanks — loại này dùng .answers"] else [] end)
        + (if ($q|has("matchings"))   then ["khai .matchings — loại này dùng .answers"] else [] end)
        + (if ($q|has("distractors")) then ["khai .distractors — nhiễu của loại này nằm trong .answers với is_correct: false"] else [] end)
        + (if (nblank) > 0            then ["đề bài có {{blank}} — chỉ Select Word / Fill Word / Drag & Drop mới có ô trống"] else [] end)
      end ) as $e
  | select($e | length > 0)
  | "câu \($q.n) [\($q|qenum)]: \($e | join(", "))" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "trường khai không đúng loại câu hỏi: $bad
  Hình dạng plan của từng loại: references/question-types.md"

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(isold)
  | (qt) as $t
  | ((.answers // []) | map(select(.is_correct)) | length) as $ok
  | ((.answers // []) | length) as $all
  | select(
      ($all < 2)
      or ($t == "onechoice"      and $ok != 1)
      or ($t == "multiplechoice" and $ok < 2)
      or ($t == "truefalse"      and ($all != 2 or $ok != 1)))
  | "câu \(.n): \($all) đáp án, \($ok) đúng, qtype=\(.qtype)" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "số đáp án không khớp qtype: $bad
  ONE_CHOICE cần đúng 1 đáp án đúng · MULTIPLE_CHOICE cần từ 2 · TRUE_FALSE cần đúng 2 đáp án, 1 đúng"

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(qt == "matching")
  | . as $q
  | ( (if (($q.matchings // []) | length) < 2 then ["cần tối thiểu 2 cặp ghép"] else [] end)
    + [ (($q.matchings // []) | to_entries[])
        | select(((.value.left // "") == "") or ((.value.right // "") == ""))
        | "cặp \(.key + 1) rỗng một vế" ] ) as $e
  | select($e | length > 0)
  | "câu \($q.n): \($e | join(", "))" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "Matching không hợp lệ: $bad
  Mỗi cặp là một dòng 'vế trái → vế phải' dưới nhãn 'Cặp ghép:' của tài liệu."

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(isblank)
  | (nblank) as $nb
  | ((.blanks // []) | length) as $k
  | select($nb == 0 or $nb != $k)
  | "câu \(.n): \($nb) ô {{blank}} trong đề bài, \($k) nhóm .blanks" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "số ô trống không khớp: $bad
  Mỗi ô [k] trong tài liệu là một {{blank}} trong .content và một phần tử .blanks,
  theo đúng thứ tự xuất hiện. Đề bài không có ô trống nào thì chọn nhầm loại rồi."

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(qt == "selectword")
  | . as $q
  | ( [ (($q.blanks // []) | to_entries[])
        | select((((.value.correct // []) | length) < 1) or (((.value.distractors // []) | length) < 1))
        | "ô \(.key + 1) thiếu đáp án đúng hoặc thiếu nhiễu" ]
    + (if ($q|has("distractors")) then ["khai .distractors ở cấp câu hỏi — nhiễu của Select Word nằm trong từng ô"] else [] end) ) as $e
  | select($e | length > 0)
  | "câu \($q.n): \($e | join(", "))" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "Select Word không hợp lệ: $bad
  Mỗi ô cần tối thiểu 1 đáp án đúng và 1 nhiễu — ô không có nhiễu thì chỉ còn một lựa chọn."

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(qt == "fillword")
  | . as $q
  | ( [ (($q.blanks // []) | to_entries[]) | select(((.value.correct // []) | length) < 1)
        | "ô \(.key + 1) không có đáp án đúng" ]
    + [ (($q.blanks // []) | to_entries[]) | select(((.value.distractors // []) | length) > 0)
        | "ô \(.key + 1) có .distractors" ]
    + (if ($q|has("distractors")) then ["khai .distractors ở cấp câu hỏi"] else [] end) ) as $e
  | select($e | length > 0)
  | "câu \($q.n): \($e | join(", "))" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "Fill Word không hợp lệ: $bad
  Loại này KHÔNG có đáp án nhiễu — học viên gõ tay. Mỗi phần tử .correct là một
  cách viết được chấp nhận cho ô đó."

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(qt == "dragdrop")
  | . as $q
  | ( [ (($q.blanks // []) | to_entries[]) | select(((.value.correct // []) | length) != 1)
        | "ô \(.key + 1) phải có đúng 1 đáp án đúng" ]
    + [ (($q.blanks // []) | to_entries[]) | select(((.value.distractors // []) | length) > 0)
        | "ô \(.key + 1) có .distractors — nhiễu của Drag & Drop để chung ở cấp câu hỏi" ]
    + (if (($q.distractors // []) | length) < 1 then ["thiếu .distractors — cần ít nhất 1 mảnh nhiễu"] else [] end) ) as $e
  | select($e | length > 0)
  | "câu \($q.n): \($e | join(", "))" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "Drag & Drop không hợp lệ: $bad
  Mỗi ô đúng 1 đáp án; mọi mảnh nhiễu nằm chung ở .distractors cấp câu hỏi."

bad=$(jq -r "$JQ_LIB"'[ .questions[]
  | select(((.content // "") == "") or (alltexts | any(. == "")))
  | "câu \(.n)" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "có câu hỏi rỗng đề bài hoặc rỗng nội dung đáp án: $bad"

# --- Ảnh trong đề bài -----------------------------------------------------------
# Ảnh đi qua .images, không gõ <img> tay vào .content: script là chỗ duy nhất tra
# resource_id và kiểm ảnh đã upload đúng folder QUESTION. Thiếu resource_id thì
# câu hỏi vẫn tạo được (201) nhưng mất ảnh vĩnh viễn — không có endpoint sửa.
bad=$(jq -r '[ .questions[]
  | select((.content // "") | test("<img"; "i"))
  | "câu \(.n)" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die "đề bài có thẻ <img> gõ tay: $bad
  Khai đường dẫn ảnh vào .images, script tự dựng thẻ <img>."

bad=$(jq -r '[ .questions[]
  | select(has("images") and ((.images | type) != "array"
                              or (.images | any((type) != "string" or . == ""))))
  | "câu \(.n)" ] | join("; ")' "$QFILE")
[ -z "$bad" ] || die ".images phải là mảng đường dẫn file (chuỗi không rỗng): $bad"

if jq -e '[.questions[] | (.images // [])[]] | length > 0' "$QFILE" >/dev/null; then
  [ -f "$MANIFEST" ] || die "câu hỏi có .images nhưng không thấy manifest: $MANIFEST
  Upload ảnh trước: scripts/course/upload-media.sh <ảnh> --folder-type QUESTION --manifest $MANIFEST"
  jq -e . "$MANIFEST" >/dev/null 2>&1 || die "$MANIFEST không phải JSON hợp lệ"
  bad=$(jq -r --slurpfile m "$MANIFEST" '[ .questions[] | .n as $n | (.images // [])[]
    | . as $f | ($m[0][$f] // null) as $e
    | if   $e == null                         then "câu \($n): \($f) chưa upload"
      elif ($e.skipped // null) != null       then "câu \($n): \($f) bị bỏ qua lúc upload (\($e.skipped))"
      elif (($e.resource_id // "") == "")     then "câu \($n): \($f) không có resource_id"
      elif ($e.folder_type // "COURSE") != "QUESTION"
                                              then "câu \($n): \($f) upload vào folder \($e.folder_type // "COURSE"), cần QUESTION"
      else empty end ] | join("; ")' "$QFILE")
  [ -z "$bad" ] || die "ảnh câu hỏi chưa sẵn sàng: $bad
  Upload lại bằng: scripts/course/upload-media.sh <ảnh> --folder-type QUESTION --manifest $MANIFEST"
  MAN_JSON=$(jq -c . "$MANIFEST")
else
  MAN_JSON='{}'
fi

# --- Ô trống: {{blank}} → thẻ span mang UUID v4 chữ thường -------------------
# Backend đếm ô trống bằng regex khớp UUID v4 CHỮ THƯỜNG. id dạng "blank-1",
# UUID chữ hoa, hay UUID không phải v4 đều không được đếm — và với DRAG_DROP,
# đếm được 0 ô thì server vẫn trả 201 nhưng ép toàn bộ đáp án thành sai, không
# báo lỗi gì. Nên UUID sinh ra ở đây được kiểm lại trước khi dùng.
gen_uuid() {
  local u=""
  if command -v uuidgen >/dev/null 2>&1; then
    u=$(uuidgen | tr 'A-Z' 'a-z')
  fi
  if ! printf '%s' "$u" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'; then
    local h
    h=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
    u=$(printf '%s-%s-4%s-%x%s-%s' \
          "${h:0:8}" "${h:8:4}" "${h:13:3}" \
          "$(( 0x${h:16:1} & 3 | 8 ))" "${h:17:3}" "${h:20:12}")
  fi
  printf '%s' "$u" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' \
    || die "không sinh được UUID v4 chữ thường cho ô trống — máy thiếu cả uuidgen lẫn /dev/urandom"
  printf '%s' "$u"
}

expand_blanks() {
  local rest="$1" out="" uuid
  while [ "${rest#*\{\{blank\}\}}" != "$rest" ]; do
    uuid=$(gen_uuid) || exit 1
    out="$out${rest%%\{\{blank\}\}*}<span id=\"$uuid\" class=\"question-content-tag\" contenteditable=\"false\">[_______]</span>"
    rest="${rest#*\{\{blank\}\}}"
  done
  printf '%s%s' "$out" "$rest"
}

info "Bài test '$TEST' — $NQ câu hỏi"
if [ "$DRY" -eq 1 ]; then
  jq -r "$JQ_LIB"'.questions[]
    | (qenum) as $e
    | (.layout | ascii_downcase | gsub("[^a-z]";"")) as $l
    | "  câu \(.n) [\($e) · \(.layout) → \(if $l == "onecolumn" then "HORIZONTAL" else "VERTICAL" end)]"
      + "  " + ( if $e == "MATCHING" then
                   "\((.matchings | length)) cặp ghép"
                 elif $e == "SELECT_WORD" then
                   "\(nblank) ô trống, mỗi ô \([.blanks[] | "\((.correct|length))đ/\((.distractors|length))n"] | join(" · "))"
                 elif $e == "FILL_WORD" then
                   "\(nblank) ô trống, mỗi ô \([.blanks[] | "\((.correct|length)) cách viết"] | join(" · "))"
                 elif $e == "DRAG_DROP" then
                   "\(nblank) ô trống, \(((.distractors // []) | length)) mảnh nhiễu chung"
                 else
                   "\((.answers | length)) đáp án, \((.answers | map(select(.is_correct)) | length)) đúng"
                 end )
      + (if ((.images // []) | length) > 0 then " · \((.images | length)) ảnh" else "" end)
      + "\n      \(.content | gsub("<[^>]*>";"") | .[0:80])"' "$QFILE" >&2
  printf '\n=== DRY-RUN — CHƯA TẠO GÌ === (state: %s)\n' "$STATE" >&2
  exit 0
fi

load_token
COURSE="${UPBASE_COURSE_ID:-}"
[ -n "$COURSE" ] || die "chưa có UPBASE_COURSE_ID — chạy scripts/course/start.sh trước"

created=0 skipped=0
for ((i = 0; i < NQ; i++)); do
  n=$(jq -r ".questions[$i].n" "$QFILE")
  KEY="q:$TEST:$n"
  have=$(jq -r --arg k "$KEY" '.[$k] // empty' "$STATE")
  if [ -n "$have" ]; then
    printf 'SKIP %-20s %s\n' "$KEY" "$have" >&2
    skipped=$((skipped + 1)); continue
  fi

  raw=$(jq -r ".questions[$i].content" "$QFILE")
  content=$(expand_blanks "$raw") || exit 1
  # Ảnh nối SAU đề bài, đúng thứ tự .images — cùng dạng thẻ với Document TEXT.
  imgs=$(jq -r --argjson man "$MAN_JSON" --arg w "$QUESTION_IMAGE_WIDTH" --arg h "$QUESTION_IMAGE_HEIGHT" --argjson i "$i" '
    [ (.questions[$i].images // [])[] | $man[.]
      | "<img src=\"PRESIGN_URL\" title=\"\(.display_name | @html)\" resource_id=\"\(.resource_id)\" width=\"\($w)\" height=\"\($h)\">" ]
    | join("")' "$QFILE")
  content="$content$imgs"

  # answer_position:
  #   loại một nhóm (One/Multiple/True-False) — đánh từ 1 theo ĐÚNG thứ tự trong
  #     file, và thứ tự đó là thứ tự tài liệu viết, không sắp xếp lại;
  #   loại có ô trống — số thứ tự của ô mà đáp án đó thuộc về;
  #   Matching — số thứ tự của cặp.
  # DRAG_DROP còn một luật nữa: server ghi đè is_correct THEO INDEX trong mảng
  # answers (N phần tử đầu thành đúng, phần còn lại thành nhiễu), nên N đáp án
  # đúng phải nằm đầu mảng theo đúng thứ tự ô trống. Script tự xếp, plan không lo.
  payload=$(jq -c "$JQ_LIB"'
     .questions[$i] as $q
     | ($q | qt) as $t
     | ($q.layout | ascii_downcase | gsub("[^a-z]";"")) as $l
     | (($q.blanks // []) | length) as $nb
     | $cfg
       + {question_content: $content,
          qType: ($q | qenum),
          display_type: (if $l == "onecolumn" then "HORIZONTAL" else "VERTICAL" end),
          question_filter: {course_id: $c}}
       + (if (($q.solution // "") != "") then {solution: $q.solution} else {} end)
       + (if $t == "matching" then
            {question_matchings: [ (($q.matchings // []) | to_entries[])
               | {content: .value.left,
                  answer: {is_correct: true, answer: .value.right, answer_position: (.key + 1)}} ]}
          elif $t == "selectword" or $t == "fillword" then
            {answers: [ (($q.blanks // []) | to_entries[]) as $b
               | ( (($b.value.correct     // [])[] | {is_correct: true,  answer: ., answer_position: ($b.key + 1)}),
                   (($b.value.distractors // [])[] | {is_correct: false, answer: ., answer_position: ($b.key + 1)}) ) ]}
          elif $t == "dragdrop" then
            {answers: ( [ (($q.blanks // []) | to_entries[])
                          | {is_correct: true, answer: (.value.correct[0]), answer_position: (.key + 1)} ]
                      + [ (($q.distractors // []) | to_entries[])
                          | {is_correct: false, answer: .value, answer_position: ($nb + .key + 1)} ] )}
          else
            {answers: [ (($q.answers // []) | to_entries[])
               | {is_correct: (.value.is_correct // false),
                  answer: .value.answer,
                  answer_position: (.key + 1)} ]}
          end)' \
    --argjson cfg "$QUESTION_CFG" --arg c "$COURSE" --argjson i "$i" --arg content "$content" "$QFILE")

  api POST "/question/single" "$payload"; check_auth
  case "$API_HTTP" in
    200|201) ;;
    *) die "câu $n: POST /question/single trả $API_HTTP: $(api_body | jq -c '.error // .' 2>/dev/null | head -c 300)" ;;
  esac
  id=$(api_body | jq -r '.data.id // .id // empty')
  [ -n "$id" ] || die "câu $n: tạo xong nhưng không đọc được id: $(api_body | head -c 300)"

  jq --arg k "$KEY" --arg v "$id" '. + {($k):$v}' "$STATE" > "$STATE.tmp" \
    && mv "$STATE.tmp" "$STATE" \
    || { rm -f "$STATE.tmp"; die "không ghi được state: $STATE"; }
  printf 'OK   %-20s %s\n' "$KEY" "$id" >&2
  created=$((created + 1))
done

printf '\n=== XONG === %d câu mới, %d câu SKIP (state: %s)\n' "$created" "$skipped" "$STATE"
