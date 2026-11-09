#!/usr/bin/env bash
# lib.sh — Lớp chung của skill: session, dependency, HTTP client.
# Source file này; không chạy trực tiếp.
# Phần riêng của từng đối tượng: scripts/course/quiz-config.sh.

set -uo pipefail

# Mọi hằng số (base URL, mặc định khóa học, timeout, phân trang) ở config.sh.
# Đừng hardcode giá trị mới vào đây — thêm vào config.sh rồi dùng biến.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.sh"

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
# URL-encode một giá trị để nhét vào query string.
urlenc() { jq -rn --arg s "$1" '$s|@uri'; }

# Dựng quiz_questions[] cho payload bài test, từ file câu hỏi + state file.
#   build_quiz_questions <questions.json> <state.json>
# In ra JSON array [{question_id, setting_grade}, …] theo thứ tự số câu tăng dần.
#
# setting_grade: chia ĐỀU cho mọi câu, giữ phần thập phân. Tổng KHÔNG được
# vượt 100.
#   - Không khai `grade` → mọi câu nhận cùng một số: 100/n làm tròn XUỐNG 2 chữ
#     số thập phân. Làm tròn xuống là bắt buộc: 100/7 = 14.2857, tròn lên thành
#     14.29 thì 7 câu cộng lại 100.03 — vượt 100.
#   - Có khai `grade` → dùng số đó, phải khai đủ mọi câu và tổng ≤ 100.
#
build_quiz_questions() {
  local qfile="$1" state="$2" qtest want ids n nwant
  [ -f "$qfile" ] || die "--questions: không đọc được $qfile"
  jq -e . "$qfile" >/dev/null 2>&1 || die "$qfile không phải JSON hợp lệ"
  qtest=$(jq -r '.test // empty' "$qfile")
  [ -n "$qtest" ] || die "$qfile thiếu .test"

  want=$(jq -c '[.questions[].n] | sort' "$qfile")
  ids=$(jq -c --arg t "$qtest" --argjson want "$want" \
    '. as $st | [ $want[] | $st["q:\($t):\(.)"] | select(. != null) ]' "$state")
  n=$(printf '%s' "$ids" | jq 'length')
  nwant=$(printf '%s' "$want" | jq 'length')
  [ "$n" = "$nwant" ] || die "state chỉ có $n/$nwant id câu hỏi của bài '$qtest'.
  Chạy create-question.sh $qfile --state $state cho xong trước."

  # Điểm khai tay: phải khai đủ cho MỌI câu và tổng đúng 100.
  local ngrade sum
  ngrade=$(jq '[.questions[] | select(has("grade"))] | length' "$qfile")
  if [ "$ngrade" != "0" ]; then
    [ "$ngrade" = "$nwant" ] \
      || die "chỉ $ngrade/$nwant câu khai 'grade' — khai thì phải khai đủ mọi câu, hoặc bỏ hết để chia đều"
    sum=$(jq '[.questions[].grade] | add' "$qfile")
    jq -ne --argjson s "$sum" '$s <= 100' >/dev/null \
      || die "tổng 'grade' của bài '$qtest' là $sum — KHÔNG được vượt 100"
    jq -ne --argjson s "$sum" '$s >= 99.9' >/dev/null \
      || printf '  ! tổng grade bài %s chỉ %s/100 — bài test không dùng hết điểm\n' "$qtest" "$sum" >&2
    jq -c --argjson ids "$ids" '[ .questions | sort_by(.n) | to_entries[]
        | {question_id: $ids[.key], setting_grade: .value.grade} ]' "$qfile"
  else
    printf '%s' "$ids" | jq -c '
      length as $n
      | ((100 / $n * 100 | floor) / 100) as $g
      | [ .[] | {question_id: ., setting_grade: $g} ]'
  fi
}
info() { printf '%s\n' "$*" >&2; }

need_deps() {
  for c in curl jq; do
    command -v "$c" >/dev/null 2>&1 || die "thiếu lệnh '$c'"
  done
}

# Đọc các khoá UPBASE_* từ session file. Biến môi trường thắng. Chịu được CRLF.
_load_env_file() {
  local f="$1" line k v
  [ -r "$f" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    line="${line#export }"
    case "$line" in UPBASE_*=*) ;; *) continue ;; esac
    k="${line%%=*}"; v="${line#*=}"
    v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
    case "$k" in
      UPBASE_TOKEN)     [ -n "${UPBASE_TOKEN:-}" ]     || UPBASE_TOKEN="$v" ;;
      UPBASE_TOPIC_ID)  [ -n "${UPBASE_TOPIC_ID:-}" ]  || UPBASE_TOPIC_ID="$v" ;;
      UPBASE_COURSE_ID) [ -n "${UPBASE_COURSE_ID:-}" ] || UPBASE_COURSE_ID="$v" ;;
      UPBASE_BASE_URL)  [ -n "${UPBASE_BASE_URL:-}" ]  || UPBASE_BASE_URL="$v" ;;
      UPBASE_SESSION_ENV) _FILE_ENV="$v" ;;
    esac
  done < "$f"
}

_FILE_ENV=""
_load_env_file "$UPBASE_ENV_FILE" || true
UPBASE_BASE_URL="${UPBASE_BASE_URL:-$UPBASE_BASE_URL_DEFAULT}"

# Chốt an toàn cuối: session file phải thuộc đúng môi trường đang chạy. Bình
# thường không xảy ra vì mỗi môi trường một file, nhưng ai đó export
# UPBASE_ENV_FILE trỏ chéo là token staging đi vào prod — sai kiểu đó chỉ lộ ra
# SAU KHI đã ghi dữ liệu, nên bỏ token luôn thay vì cảnh báo.
if [ -n "$_FILE_ENV" ] && [ "$_FILE_ENV" != "$UPBASE_ENV" ]; then
  printf '  ! session file %s là của môi trường %s, đang chạy %s — BỎ token đó.\n' \
    "$UPBASE_ENV_FILE" "$_FILE_ENV" "$UPBASE_ENV" >&2
  UPBASE_TOKEN=""
fi

load_token() {
  TOKEN="${UPBASE_TOKEN:-}"
  [ -n "$TOKEN" ] || die "chưa có token cho môi trường $UPBASE_ENV ($UPBASE_BASE_URL).
  Nhờ người dùng chạy: scripts/login.sh  (chọn đúng môi trường trong hộp thoại)"
}

# In môi trường đang dùng. Gọi ở đầu mọi script có ghi dữ liệu — người dùng phải
# thấy mình đang bắn vào đâu TRƯỚC khi có gì được tạo.
show_env() {
  if [ "$UPBASE_ENV" = "prod" ]; then
    printf '  ⚠️  MÔI TRƯỜNG: PRODUCTION — %s\n' "$UPBASE_BASE_URL" >&2
  else
    printf '  môi trường: staging — %s\n' "$UPBASE_BASE_URL" >&2
  fi
}

API_HTTP=""
API_BODY_FILE="${TMPDIR:-/tmp}/upbase-api.$$"
trap 'rm -f "$API_BODY_FILE"' EXIT

# api <METHOD> <PATH> [JSON] — set API_HTTP, body ghi ra api_body.
# Gọi KHÔNG qua command substitution; subshell sẽ làm mất API_HTTP.
api() {
  local method="$1" path="$2" body="${3:-}"
  local -a args=(-sS -o "$API_BODY_FILE" -w '%{http_code}'
                 -X "$method" "${UPBASE_BASE_URL}${path}"
                 -H "Authorization: Bearer ${TOKEN}"
                 -H "Accept: application/json")
  [ -n "$body" ] && args+=(-H "Content-Type: application/json" --data "$body")
  API_HTTP=$(curl "${args[@]}") || { API_HTTP="000"; : > "$API_BODY_FILE"; }
}

# api_form <METHOD> <PATH> <field> [field …] — gửi multipart/form-data.
# Mỗi <field> là một tham số --form của curl: "ten=giatri" hoặc
# "ten=@/duong/dan;type=image/png".
#
# ĐỪNG tự đặt header Content-Type ở đây. multipart bắt buộc phải kèm boundary,
# mà boundary do curl sinh — tự đặt 'Content-Type: multipart/form-data' là gửi
# đi một header thiếu boundary và server trả 400 mà không nói vì sao.
api_form() {
  local method="$1" path="$2"; shift 2
  local -a args=(-sS -o "$API_BODY_FILE" -w '%{http_code}'
                 -X "$method" "${UPBASE_BASE_URL}${path}"
                 -H "Authorization: Bearer ${TOKEN}"
                 -H "Accept: application/json")
  local f
  for f in "$@"; do args+=(--form "$f"); done
  API_HTTP=$(curl "${args[@]}") || { API_HTTP="000"; : > "$API_BODY_FILE"; }
}

api_body() { cat "$API_BODY_FILE" 2>/dev/null; }

check_auth() {
  [ "${API_HTTP:-}" = "401" ] || return 0
  die "401 — token môi trường $UPBASE_ENV hết hạn.
Nhờ người dùng chạy 'scripts/login.sh' trong terminal của họ, chọn đúng môi
trường, rồi lặp lại đúng lệnh cũ.
State file giữ tiến độ nên không tạo lại phần đã xong."
}
