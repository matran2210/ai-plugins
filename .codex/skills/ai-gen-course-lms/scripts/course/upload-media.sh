#!/usr/bin/env bash
# Upload một file media lên LMS, lấy resource_id và quiz_id.
#
#   upload-media.sh <file> [--display-name "<tên>"] [--manifest FILE] [--dry-run]
#
# Bốn bước, đúng thứ tự — bước sau cần kết quả của bước trước:
#   1. GET  /resources/upload/folder?type=COURSE&object_id=<course_id>
#             → parent_id = .data.id, location = .data.name + "/"
#   2. GET  /resources/pre-upload/metadata?content_type&name&location&size&display_name
#             → file_key = .data.file_key, upload_url = .data.upload_url
#   3. PUT  <upload_url>   presigned S3, KHÔNG gửi Authorization, URL sống 1 giờ
#   4. POST /resources/upload/add-file-resource
#             → resource_id = .data[0].id, quiz_id = .data[0].quiz_id
#
# Dùng id nào ở bước dựng document:
#   VIDEO → quiz_id    → {type:"VIDEO", payload:{video_quiz_ids:["…"]}}
#   ẢNH   → resource_id → <img src="PRESIGN_URL" title="…" resource_id="…" width="200">
#
# Kết quả ghi vào manifest (mặc định ./media-manifest.json), khoá theo đường dẫn
# file truyền vào. File đã có trong manifest thì SKIP, chạy lại không upload lại.
# Khoá "_folder" cache lại parent_id/location để không gọi lại bước 1 mỗi file.
#
# Cần UPBASE_COURSE_ID — chạy scripts/course/start.sh trước.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

FILE="" DNAME="" MANIFEST="media-manifest.json" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --display-name) [ $# -ge 2 ] || die "--display-name cần một giá trị"
                DNAME="$2"; shift 2 ;;
    --manifest) [ $# -ge 2 ] || die "--manifest cần một giá trị"
                MANIFEST="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
               exit 0 ;;
    -*) die "cờ không nhận: $1" ;;
    *) [ -z "$FILE" ] && FILE="$1"; shift ;;
  esac
done

need_deps
[ -n "$FILE" ] || die "thiếu <file> — dùng: $0 <file> [--manifest FILE]"
[ -r "$FILE" ] || die "không đọc được file: $FILE"

fsize() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0; }

SIZE=$(fsize "$FILE")
[ "$SIZE" -gt 0 ] || die "file rỗng: $FILE"

BASE=$(basename "$FILE")
DNAME="${DNAME:-$BASE}"
STEM="${BASE%.*}"
EXT="${BASE##*.}"

# content_type theo đuôi file; không nhận ra thì hỏi `file`, vẫn không ra thì dừng.
# Không đoán bừa: content_type sai làm LMS phân loại sai suffix_type.
case "$(printf '%s' "$EXT" | tr 'A-Z' 'a-z')" in
  mp4)        CT="video/mp4" ;;
  mov)        CT="video/quicktime" ;;
  webm)       CT="video/webm" ;;
  png)        CT="image/png" ;;
  jpg|jpeg)   CT="image/jpeg" ;;
  gif)        CT="image/gif" ;;
  webp)       CT="image/webp" ;;
  svg)        CT="image/svg+xml" ;;
  pdf)        CT="application/pdf" ;;
  md|markdown) CT="text/markdown" ;;
  *)
    CT=$(file --mime-type -b "$FILE" 2>/dev/null || true)
    # Fallback chỉ nhận mime của media. `file` trả text/plain cho file lạ, mà
    # nhận nó thì LMS phân loại suffix_type sai và không có lỗi nào báo.
    case "$CT" in
      video/*|image/*|audio/*|application/pdf) ;;
      *) die "không xác định được content_type cho '.$EXT' (file đoán: ${CT:-không ra}) — bổ sung vào bảng trong $0" ;;
    esac ;;
esac

[ -f "$MANIFEST" ] || echo '{}' > "$MANIFEST"

# Đã upload rồi, hoặc đã ghi nhận là bỏ qua, thì thôi.
have=$(jq -r --arg k "$FILE" '.[$k].resource_id // empty' "$MANIFEST")
skipped=$(jq -r --arg k "$FILE" '.[$k].skipped // empty' "$MANIFEST")
if [ -n "$have" ]; then
  qz=$(jq -r --arg k "$FILE" '.[$k].quiz_id // "null"' "$MANIFEST")
  printf 'SKIP %s\n     resource_id=%s quiz_id=%s\n' "$BASE" "$have" "$qz" >&2
  exit 0
elif [ -n "$skipped" ]; then
  printf 'SKIP %s  (đã ghi nhận bỏ qua: %s — người dùng tự upload)\n' "$BASE" "$skipped" >&2
  exit 0
fi

COURSE="${UPBASE_COURSE_ID:-}"
[ -n "$COURSE" ] || die "chưa có UPBASE_COURSE_ID — chạy scripts/course/start.sh trước"

if [ "$DRY" = "1" ]; then
  printf '[dry-run] %s\n' "$BASE" >&2
  printf '  size=%s content_type=%s display_name=%s\n' "$SIZE" "$CT" "$DNAME" >&2
  printf '  1) GET  /resources/upload/folder?type=COURSE&object_id=%s\n' "$COURSE" >&2
  printf '  2) GET  /resources/pre-upload/metadata?content_type=%s&name=%s&location=<từ b1>&size=%s&display_name=%s\n' \
    "$(urlenc "$CT")" "$(urlenc "$STEM")" "$SIZE" "$(urlenc "$DNAME")" >&2
  printf '  3) PUT  <upload_url từ b2>  (%s byte, không gửi Authorization)\n' "$SIZE" >&2
  printf '  4) POST /resources/upload/add-file-resource\n' >&2
  printf '=== DRY-RUN — CHƯA UPLOAD GÌ === (manifest: %s)\n' "$MANIFEST" >&2
  exit 0
fi

load_token

# ---------- 1. Folder của khóa (get-or-create), cache trong manifest ----------
PARENT=$(jq -r '._folder.parent_id // empty' "$MANIFEST")
LOC=$(jq -r '._folder.location // empty' "$MANIFEST")
if [ -z "$PARENT" ] || [ -z "$LOC" ]; then
  api GET "/resources/upload/folder?type=COURSE&object_id=$(urlenc "$COURSE")"; check_auth
  [ "$API_HTTP" = "200" ] || die "bước 1 GET folder trả $API_HTTP: $(api_body | head -c 300)"
  PARENT=$(api_body | jq -r '.data.id // empty')
  fname=$(api_body | jq -r '.data.name // empty')
  [ -n "$PARENT" ] || die "bước 1 không có .data.id: $(api_body | head -c 300)"
  [ -n "$fname" ] || die "bước 1 không có .data.name: $(api_body | head -c 300)"
  # .data.name không có dấu / cuối, mà location thì cần — thêm vào.
  LOC="${fname%/}/"
  jq --arg p "$PARENT" --arg l "$LOC" \
    '. + {_folder: {parent_id: $p, location: $l}}' "$MANIFEST" > "$MANIFEST.tmp" \
    && mv "$MANIFEST.tmp" "$MANIFEST" || { rm -f "$MANIFEST.tmp"; die "không ghi được $MANIFEST"; }
  printf '  folder: %s  (%s)\n' "$PARENT" "$LOC" >&2
fi

# ---------- 2. Metadata: file_key + presigned upload_url ----------
qs="content_type=$(urlenc "$CT")&name=$(urlenc "$STEM")&location=$(urlenc "$LOC")"
qs="$qs&size=$SIZE&display_name=$(urlenc "$DNAME")"
api GET "/resources/pre-upload/metadata?$qs"; check_auth
[ "$API_HTTP" = "200" ] || die "bước 2 GET metadata trả $API_HTTP: $(api_body | head -c 300)"

PTYPE=$(api_body | jq -r '.data.type // empty')
FKEY=$(api_body | jq -r '.data.file_key // empty')
UURL=$(api_body | jq -r '.data.upload_url // empty')
EXISTT=$(api_body | jq -r '.data.exist_type // "null"')

[ -n "$FKEY" ] || die "bước 2 không có .data.file_key: $(api_body | head -c 300)"
[ -n "$UURL" ] || die "bước 2 không có .data.upload_url: $(api_body | head -c 300)"

# File quá lớn thì server trả loại khác SINGLE_PART (upload nhiều phần). Luồng đó
# cố ý KHÔNG hỗ trợ: ghi nhận vào manifest rồi bỏ qua để người dùng tự upload,
# và exit 0 để vòng lặp qua các file khác chạy tiếp.
if [ "$PTYPE" != "SINGLE_PART" ]; then
  jq --arg k "$FILE" --arg t "$PTYPE" --arg d "$DNAME" --arg sz "$SIZE" \
    '. + {($k): {skipped: $t, display_name: $d, size: $sz,
                 resource_id: null, quiz_id: null}}' \
    "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST" \
    || { rm -f "$MANIFEST.tmp"; die "không ghi được $MANIFEST"; }
  printf 'SKIP %s  (%s byte, server trả type=%s)\n' "$BASE" "$SIZE" "$PTYPE" >&2
  printf '     File quá lớn cho luồng một phát — người dùng tự upload trên giao diện.\n' >&2
  printf '     Activity dùng file này sẽ KHÔNG có document media; nói rõ trong báo cáo.\n' >&2
  exit 0
fi

[ "$EXISTT" = "null" ] \
  || printf '  ⚠️  exist_type=%s (chưa rõ nghĩa, vẫn upload tiếp)\n' "$EXISTT" >&2

# ---------- 3. PUT lên S3 ----------
# Presigned URL ký với X-Amz-SignedHeaders=host, nên KHÔNG được thêm Authorization
# (sẽ xung đột với auth trong query) và Content-Type không cần khớp.
printf '  đang upload %s byte…\n' "$SIZE" >&2
s3=$(curl -sS -T "$FILE" -w '%{http_code}' -o /dev/null \
  --retry "$UPLOAD_RETRY" --retry-delay 3 \
  --connect-timeout "$UPLOAD_CONNECT_TIMEOUT" --max-time "$UPLOAD_MAX_TIME" "$UURL") \
  || die "bước 3 PUT S3 thất bại — kiểm tra mạng. URL presigned sống 1 giờ, quá hạn thì chạy lại từ đầu"
case "$s3" in
  200|204) ;;
  403) die "bước 3 PUT trả 403 — URL presigned hết hạn (sống 1 giờ) hoặc chữ ký sai. Chạy lại lệnh này" ;;
  *)   die "bước 3 PUT trả HTTP $s3" ;;
esac

# ---------- 4. Tạo resource ----------
# size là STRING ở đây, dù là number ở query param bước 2. Gửi đúng theo mẫu.
payload=$(jq -nc --arg n "$DNAME" --arg fk "$FKEY" --arg l "$LOC" \
  --arg sz "$SIZE" --arg p "$PARENT" \
  '{files: [{name: $n, file_key: $fk, location: $l, description: "",
             size: $sz, parent_id: $p}]}')
api POST "/resources/upload/add-file-resource" "$payload"; check_auth
case "$API_HTTP" in
  200|201) ;;
  *) die "bước 4 add-file-resource trả $API_HTTP: $(api_body | head -c 300)" ;;
esac

# data là MẢNG, mỗi file một phần tử.
RID=$(api_body | jq -r '.data[0].id // empty')
QID=$(api_body | jq -r '.data[0].quiz_id // empty')
STYPE=$(api_body | jq -r '.data[0].suffix_type // empty')
[ -n "$RID" ] || die "bước 4 không có .data[0].id: $(api_body | head -c 300)"

# Video không có quiz_id thì Document VIDEO không dựng được — báo ngay, đừng để
# lộ ra ở bước tạo document.
if [ "$STYPE" = "VIDEO" ] && [ -z "$QID" ]; then
  printf '  ⚠️  suffix_type=VIDEO nhưng quiz_id rỗng — Document VIDEO sẽ không dựng được\n' >&2
fi

jq --arg k "$FILE" --arg r "$RID" --arg q "$QID" --arg d "$DNAME" \
   --arg s "$STYPE" --arg fk "$FKEY" --arg sz "$SIZE" \
  '. + {($k): {resource_id: $r, quiz_id: (if $q == "" then null else $q end),
               display_name: $d, suffix_type: $s, file_key: $fk, size: $sz}}' \
  "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST" \
  || { rm -f "$MANIFEST.tmp"; die "không ghi được $MANIFEST"; }

printf 'OK   %s  (%s)\n     resource_id=%s  quiz_id=%s\n' \
  "$BASE" "${STYPE:-?}" "$RID" "${QID:-null}" >&2
