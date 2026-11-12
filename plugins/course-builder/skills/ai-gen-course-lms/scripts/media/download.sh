#!/usr/bin/env bash
# download.sh — Tải một file media của Lark về project.
#
#   scripts/media/download.sh <tmp_url> <dest_path>
#
# <tmp_url> là URL tạm lấy từ tool MCP drive_v1_media_batchGetTmpDownloadUrl.
# URL đó đã ký sẵn nên script KHÔNG cần token và KHÔNG source lib.sh —
# đây là lý do nó không nằm chung với các script gọi API UpBase.
#
# In một dòng kết quả:
#   OK    <byte> <đường dẫn>   tải xong
#   SKIP  <byte> <đường dẫn>   đã có file không rỗng, không tải lại
# Lỗi thì exit 1 kèm ERROR ở stderr.

set -uo pipefail

# Source config.sh trực tiếp: script này cố ý KHÔNG dùng lib.sh (tải từ URL
# presigned, không cần token UpBase), nhưng vẫn phải lấy timeout từ một chỗ.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

URL="${1:-}"
DEST="${2:-}"

[ -n "$URL" ]  || die "thiếu <tmp_url> — dùng: $0 <tmp_url> <dest_path>"
[ -n "$DEST" ] || die "thiếu <dest_path> — dùng: $0 <tmp_url> <dest_path>"

command -v curl >/dev/null 2>&1 || die "thiếu lệnh 'curl'"

# Kích thước file, khác cú pháp giữa macOS và Linux.
fsize() {
  stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

# Đã tải rồi thì bỏ qua — chạy lại cả bước media không tải lại từ đầu.
if [ -f "$DEST" ]; then
  have=$(fsize "$DEST")
  if [ "$have" -gt 0 ]; then
    printf 'SKIP %s %s\n' "$have" "$DEST"
    exit 0
  fi
  rm -f "$DEST"
fi

dir=$(dirname "$DEST")
mkdir -p "$dir" || die "không tạo được thư mục: $dir"

# Tải vào file tạm rồi mới mv, để không để lại file dở dang mang tên thật.
tmp="$DEST.part"
rm -f "$tmp"

meta=$(curl -sS -L \
  --retry "$DOWNLOAD_RETRY" --retry-delay 2 --retry-connrefused \
  --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" \
  -w '%{http_code} %{content_type}' \
  -o "$tmp" \
  "$URL" 2>/dev/null) || { rm -f "$tmp"; die "curl thất bại — kiểm tra mạng, hoặc URL tạm đã hết hạn"; }

http="${meta%% *}"
ctype="${meta#* }"

case "$http" in
  200) ;;
  403) rm -f "$tmp"; die "403 — URL tạm đã hết hạn. Lấy URL mới cho token này rồi tải lại ngay" ;;
  404) rm -f "$tmp"; die "404 — token media không còn tồn tại" ;;
  *)   rm -f "$tmp"; die "HTTP $http — không tải được" ;;
esac

# Lark trả 200 kèm trang HTML cho URL sai hoặc hết phiên, thay vì trả mã lỗi.
# Không chặn ở đây thì một trang lỗi được lưu lại thành "video" và báo OK.
case "$ctype" in
  text/html*|application/xhtml*)
    rm -f "$tmp"
    die "server trả HTML ($ctype) chứ không phải media — URL tạm sai hoặc đã hết hạn"
    ;;
esac

got=$(fsize "$tmp")
[ "$got" -gt 0 ] || { rm -f "$tmp"; die "tải về 0 byte — thử lại một lần, vẫn vậy thì ghi vào mục Sai lệch"; }

mv -f "$tmp" "$DEST" || { rm -f "$tmp"; die "không ghi được: $DEST"; }

printf 'OK %s %s\n' "$got" "$DEST"
