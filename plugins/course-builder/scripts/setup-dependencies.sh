#!/bin/sh
# Bootstrap bằng sh để vẫn cài được khi máy chưa có bash.
# --check chỉ kiểm tra; mặc định cài các công cụ còn thiếu.
set -eu
set -f

fail() { printf 'LỖI: %s\n' "$*" >&2; exit 1; }
MODE=install
case "${1:-}" in
  --check) MODE=check ;;
  --help|-h)
    printf '%s\n' 'Cách dùng: sh setup-dependencies.sh [--check]' \
      'Kiểm tra và cài bash, curl, jq, openssl, node (kèm npx).' \
      'macOS: Homebrew. Linux/WSL: trình quản lý gói của hệ điều hành.' \
      'Windows chưa có Git Bash: chạy setup-dependencies.ps1 bằng PowerShell.'
    exit 0 ;;
  '') ;;
  *) printf 'Tham số không hợp lệ: %s\n' "$1" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { printf 'Chỉ nhận tối đa một tham số.\n' >&2; exit 2; }

SYSTEM=$(uname -s)

MISSING=''
check_tools() {
  MISSING=''
  for tool in bash curl jq openssl node npx; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf 'OK     %s\n' "$tool"
    else
      printf 'THIẾU  %s\n' "$tool"
      MISSING="$MISSING $tool"
    fi
  done
  [ -z "$MISSING" ]
}

if check_tools; then
  printf '\nĐÃ SẴN SÀNG: đủ công cụ hỗ trợ Course Builder.\n'
  exit 0
fi
if [ "$MODE" = check ]; then
  printf '\nChạy lại script không kèm --check để cài phần còn thiếu.\n'
  exit 1
fi

printf '\nĐang cài công cụ còn thiếu:%s\n' "$MISSING"
as_admin() {
  if [ "$(id -u)" = 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    fail 'Cần quyền quản trị để cài đặt. Nhờ IT chạy script bằng tài khoản có quyền sudo.'
  fi
}

PACKAGES=''
add_package() {
  case " $PACKAGES " in *" $1 "*) ;; *) PACKAGES="$PACKAGES $1" ;; esac
}

case "$SYSTEM" in
  Darwin)
    # Chỉ dò vị trí brew trong chế độ cài. --check cần phản ánh PATH hiện tại
    # của host, không báo sẵn sàng nhờ một PATH chỉ tồn tại bên trong script.
    for prefix in /opt/homebrew /usr/local; do
      if [ -x "$prefix/bin/brew" ]; then
        PATH="$PATH:$prefix/bin:$prefix/sbin:$prefix/opt/openssl@3/bin"
      fi
    done
    export PATH
    if ! command -v brew >/dev/null 2>&1; then
      command -v curl >/dev/null 2>&1 && [ -x /bin/bash ] \
        || fail 'Thiếu công cụ hệ thống macOS để cài Homebrew. Nhờ IT khôi phục curl và /bin/bash.'
      printf 'Đang cài Homebrew. Làm theo yêu cầu quyền quản trị nếu có.\n'
      installer=$(mktemp)
      trap 'rm -f "$installer"' EXIT HUP INT TERM
      curl --fail --location --proto '=https' --tlsv1.2 \
        https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer" \
        || fail 'Không tải được trình cài Homebrew. Kiểm tra mạng rồi chạy lại.'
      /bin/bash "$installer" || fail 'Homebrew chưa cài xong. Xử lý thông báo phía trên rồi chạy lại.'
      rm -f "$installer"
      trap - EXIT HUP INT TERM
      for prefix in /opt/homebrew /usr/local; do
        if [ -x "$prefix/bin/brew" ]; then
          PATH="$prefix/bin:$prefix/sbin:$PATH"
        fi
      done
      export PATH
    fi
    command -v brew >/dev/null 2>&1 || fail 'Không tìm thấy Homebrew sau khi cài.'
    for tool in $MISSING; do
      case "$tool" in openssl) add_package openssl@3 ;; npx) add_package node ;; *) add_package "$tool" ;; esac
    done
    brew install $PACKAGES || fail 'Cài đặt bằng Homebrew chưa thành công. Xem thông báo phía trên rồi chạy lại.'
    # Ghi PATH vào profile của người dùng để lần mở ứng dụng tiếp theo dùng được.
    brew_prefix=$(brew --prefix)
    tool_path="$brew_prefix/bin:$brew_prefix/sbin:$brew_prefix/opt/openssl@3/bin"
    case "${SHELL:-}" in
      */bash) profile="$HOME/.bash_profile" ;;
      *) profile="$HOME/.zprofile" ;;
    esac
    path_line="export PATH=\"$tool_path:\$PATH\" # Course Builder tools"
    if ! grep -Fqx "$path_line" "$profile" 2>/dev/null; then
      printf '\n%s\n' "$path_line" >> "$profile" || fail "Không cập nhật được $profile."
    fi
    PATH="$tool_path:$PATH"
    export PATH
    ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then manager=apt-get
    elif command -v dnf >/dev/null 2>&1; then manager=dnf
    elif command -v yum >/dev/null 2>&1; then manager=yum
    elif command -v apk >/dev/null 2>&1; then manager=apk
    elif command -v pacman >/dev/null 2>&1; then manager=pacman
    elif command -v zypper >/dev/null 2>&1; then manager=zypper
    else fail 'Chưa hỗ trợ trình quản lý gói trên máy này. Nhờ IT cài bash, curl, jq, openssl, nodejs và npm.'
    fi
    for tool in $MISSING; do
      case "$tool" in
        node) add_package nodejs ;;
        npx) add_package npm ;;
        *) add_package "$tool" ;;
      esac
    done
    # Arch đặt tên gói là nodejs như các distro khác.
    case "$manager" in
      apt-get)
        as_admin apt-get update || fail 'Không cập nhật được danh sách gói.'
        as_admin apt-get install -y $PACKAGES || fail 'Cài đặt chưa thành công.' ;;
      dnf|yum) as_admin "$manager" install -y $PACKAGES || fail 'Cài đặt chưa thành công.' ;;
      apk) as_admin apk add --no-cache $PACKAGES || fail 'Cài đặt chưa thành công.' ;;
      pacman) as_admin pacman -S --needed --noconfirm $PACKAGES || fail 'Cài đặt chưa thành công.' ;;
      zypper) as_admin zypper --non-interactive install $PACKAGES || fail 'Cài đặt chưa thành công.' ;;
    esac
    ;;
  MINGW*|MSYS*|CYGWIN*)
    command -v powershell.exe >/dev/null 2>&1 || fail 'Mở PowerShell và chạy setup-dependencies.ps1.'
    script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
    command -v cygpath >/dev/null 2>&1 || fail 'Không tìm thấy cygpath. Chạy setup-dependencies.ps1 trực tiếp trong PowerShell.'
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$script_dir/setup-dependencies.ps1")"
    ;;
  *) fail "Chưa hỗ trợ hệ điều hành: $SYSTEM" ;;
esac

printf '\nKiểm tra sau cài đặt:\n'
check_tools || fail 'Vẫn thiếu công cụ. Xem danh sách phía trên, mở lại ứng dụng rồi kiểm tra lại.'
printf '\nĐÃ SẴN SÀNG. Đóng và mở lại Codex/Claude Code để nhận công cụ mới.\n'
