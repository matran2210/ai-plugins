#!/usr/bin/env bash
# Đặt ảnh bìa (thumbnail) cho khóa học. Chạy ở bước 5, SAU create-course.sh.
#
#   upload-course-image.sh --image <đường/dẫn/ảnh> [--course <id>]
#                          [--state FILE] [--dry-run]
#
# Ảnh lấy từ nhãn `Thumbnail:` ở vùng "Thông tin khóa học" của tài liệu Lark,
# tải về <course-slug>/assets/ ở bước 2.
#
# Endpoint RIÊNG, không đi qua luồng resource của upload-media.sh:
#
#   PUT /courses/image     multipart/form-data
#        course_id=<uuid>
#        course_image=@<file>
#
# Khác upload-media.sh ở chỗ không có presigned S3, không sinh resource_id —
# file đi thẳng trong body request, và ảnh gắn luôn vào khóa.
#
# PHẢI có course_id, nên không chạy được trước create-course.sh. Lấy từ --course,
# hoặc từ session do start.sh ghi.
#
# Resume qua state file: đã đặt ảnh rồi thì in SKIP, không gửi lại.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib.sh"

IMAGE="" COURSE="" STATE="state.json" DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --image) [ $# -ge 2 ] || die "--image cần một giá trị"
                IMAGE="$2"; shift 2 ;;
    --course) [ $# -ge 2 ] || die "--course cần một giá trị"
                COURSE="$2"; shift 2 ;;
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
[ -n "$IMAGE" ] || die "thiếu --image"
[ -f "$IMAGE" ] || die "không thấy file ảnh: $IMAGE"
[ -s "$IMAGE" ] || die "file ảnh rỗng: $IMAGE
  File tải về 0 byte là dấu hiệu bước 2 hỏng — tải lại rồi chạy lại."

# Kiểu MIME suy từ ĐUÔI FILE, không đoán. Gửi sai kiểu thì server có thể nhận
# rồi lưu một file giao diện không hiển thị được, mà vẫn trả 200.
case "$(printf '%s' "${IMAGE##*.}" | tr '[:upper:]' '[:lower:]')" in
  png)        MIME="image/png" ;;
  jpg|jpeg)   MIME="image/jpeg" ;;
  gif)        MIME="image/gif" ;;
  webp)       MIME="image/webp" ;;
  *) die "không nhận đuôi file '${IMAGE##*.}' — ảnh bìa chỉ hỗ trợ .png .jpg .jpeg .gif .webp
  Block image của Lark không có tên file thì bước 2 để đuôi .bin; mở file ra xem
  thật sự là ảnh gì rồi đổi đuôi cho đúng." ;;
esac

[ -f "$STATE" ] || echo '{}' > "$STATE"

SIZE=$(wc -c < "$IMAGE" | tr -d ' ')
info "Ảnh bìa: $IMAGE  ($MIME, $SIZE byte)"

if [ "$DRY" -eq 1 ]; then
  printf '[dry-run] PUT /courses/image  course_id=%s  course_image=@%s;type=%s\n' \
    "${COURSE:-<từ session>}" "$IMAGE" "$MIME" >&2
  printf '\n=== DRY-RUN — CHƯA GỬI GÌ === (state: %s)\n' "$STATE" >&2
  exit 0
fi

load_token
COURSE="${COURSE:-${UPBASE_COURSE_ID:-}}"
[ -n "$COURSE" ] || die "chưa có course_id — truyền --course <id>, hoặc chạy
  scripts/course/start.sh --course <id> trước để ghi nó vào session"

KEY="courseimage:$COURSE"
have=$(jq -r --arg k "$KEY" '.[$k] // empty' "$STATE")
if [ -n "$have" ]; then
  printf 'SKIP %-24s %s\n' "$KEY" "$have" >&2
  printf '\n=== ĐÃ CÓ ẢNH BÌA TỪ TRƯỚC === (state: %s)\n' "$STATE"
  exit 0
fi

api_form PUT "/courses/image" \
  "course_id=$COURSE" \
  "course_image=@${IMAGE};type=${MIME}"
check_auth
case "$API_HTTP" in
  200|201|204) ;;
  413) die "ảnh quá lớn, server trả 413 ($SIZE byte). Giảm kích thước rồi chạy lại." ;;
  *) die "PUT /courses/image trả $API_HTTP: $(api_body | jq -c '.error // .message // .' 2>/dev/null | head -c 300)" ;;
esac

# Response chưa được kiểm chứng kỹ — lấy được url thì in ra, không thì thôi.
# KHÔNG coi việc thiếu url là lỗi: mã 2xx đã là đặt thành công.
url=$(api_body | jq -r '.data.image // .data.url // .data.course_image // .image // empty' 2>/dev/null)

jq --arg k "$KEY" --arg v "${url:-ok}" '. + {($k):$v}' "$STATE" > "$STATE.tmp" \
  && mv "$STATE.tmp" "$STATE" \
  || { rm -f "$STATE.tmp"; die "không ghi được state: $STATE"; }

printf 'OK   %-24s %s\n' "$KEY" "${url:-đã đặt}" >&2
printf '\n=== ĐÃ ĐẶT ẢNH BÌA === (state: %s)\n' "$STATE"
