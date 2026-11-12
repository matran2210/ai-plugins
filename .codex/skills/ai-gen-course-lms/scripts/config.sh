#!/usr/bin/env bash
# config.sh — MỌI hằng số của skill nằm ở đây. Source file này; không chạy trực tiếp.
#
# lib.sh tự source file này, nên mọi script gọi API đều có sẵn các biến dưới đây.
# scripts/media/download.sh source riêng vì nó cố ý không dùng lib.sh (tải từ URL
# presigned của S3, không cần token UpBase).
#
# Mỗi biến đều theo dạng ${VAR:-mặc định}: đặt biến môi trường cùng tên là ghi đè
# được cho một lần chạy, không phải sửa file.
#
#   UPBASE_ENV=prod scripts/course/start.sh …

# ---------------------------------------------------------------- Môi trường --
# HAI môi trường OPS, khác nhau ĐÚNG base URL; mọi endpoint và payload giống nhau.
# Chọn ở hộp thoại của login.sh, hoặc export UPBASE_ENV trước khi chạy.
UPBASE_BASE_URL_STAGING="${UPBASE_BASE_URL_STAGING:-https://uplms-api.staging.upbase.asia/ops/api/v1}"
UPBASE_BASE_URL_PROD="${UPBASE_BASE_URL_PROD:-https://uplms-api.upbase.asia/ops/api/v1}"

# ĐĂNG NHẬP nằm ở Keycloak, HOST KHÁC hẳn base URL của API — không phải một
# đường dẫn con của nó. Đổi môi trường là phải đổi CẢ HAI, nên hai biến này đi
# chung một case bên dưới.
#
# Luồng là OAuth2 Resource Owner Password Credentials: POST form-urlencoded với
# grant_type=password. Client là PUBLIC, không có client_secret.
UPBASE_AUTH_URL_STAGING="${UPBASE_AUTH_URL_STAGING:-https://accounts.staging.upbase.asia/realms/lms/protocol/openid-connect/token}"
UPBASE_AUTH_URL_PROD="${UPBASE_AUTH_URL_PROD:-https://accounts.upbase.asia/realms/lms/protocol/openid-connect/token}"

# Client id của giao diện OPS. Keycloak phải BẬT "Direct access grants" cho
# client này thì grant_type=password mới chạy; tắt thì trả
# 400 unauthorized_client "Client not allowed for direct access grants".
UPBASE_AUTH_CLIENT_ID="${UPBASE_AUTH_CLIENT_ID:-ops-frontend}"

# staging | prod. Mặc định staging — dựng thử không bao giờ vô tình vào prod.
UPBASE_ENV="${UPBASE_ENV:-staging}"
case "$UPBASE_ENV" in
  staging) UPBASE_BASE_URL_DEFAULT="${UPBASE_BASE_URL_DEFAULT:-$UPBASE_BASE_URL_STAGING}"
           UPBASE_AUTH_URL="${UPBASE_AUTH_URL:-$UPBASE_AUTH_URL_STAGING}" ;;
  prod)    UPBASE_BASE_URL_DEFAULT="${UPBASE_BASE_URL_DEFAULT:-$UPBASE_BASE_URL_PROD}"
           UPBASE_AUTH_URL="${UPBASE_AUTH_URL:-$UPBASE_AUTH_URL_PROD}" ;;
  *) printf 'ERROR: UPBASE_ENV phải là staging hoặc prod, nhận: %s\n' "$UPBASE_ENV" >&2; exit 1 ;;
esac

# Session file TÁCH THEO MÔI TRƯỜNG. Token staging không dùng được ở prod và
# ngược lại; dùng chung một file là chỗ để lẫn token, mà lỗi đó chỉ lộ ra khi đã
# ghi dữ liệu vào môi trường sai. $TMPDIR bị dọn khi reboot; trỏ sang $HOME nếu
# muốn token sống qua khởi động lại.
UPBASE_ENV_FILE="${UPBASE_ENV_FILE:-${TMPDIR:-/tmp}/upbase-session-${UPBASE_ENV}.env}"

# ----------------------------------------------------- Tạo khóa học (bước 5) --
# FALLBACK cho POST /courses — chỉ dùng khi tài liệu Lark KHÔNG khai trường đó.
# Tài liệu có `Type:`, `Passpoint:`, `Điểm thành phần:` thì giá trị trong tài liệu
# THẮNG; create-course.sh nhận qua --type / --pass-point / --setting.
COURSE_STATUS="${COURSE_STATUS:-DRAFT}"
COURSE_TYPE="${COURSE_TYPE:-NORMAL_COURSE}"
COURSE_PASS_POINT="${COURSE_PASS_POINT:-65}"
COURSE_TEMPLATE="${COURSE_TEMPLATE:-3}"
# Gán hai bước: dấu } của JSON nằm trong ${VAR:-…} sẽ đóng sớm phần mở rộng,
# mà escape nó thì backslash lọt vào chuỗi và làm hỏng JSON.
COURSE_SETTING="${COURSE_SETTING:-}"
[ -n "$COURSE_SETTING" ] || COURSE_SETTING='{"progress":20,"activity_points":0,"chapter_points":0,"topic_points":0,"mid_term_points":0,"final_test_points":80}'

# --------------------------------------------------- Câu hỏi (bước 7) --------
# Phần BẤT BIẾN của POST /question/single, lấy từ request thật của giao diện.
# Phần thay đổi theo từng câu (question_content, qType, display_type, answers,
# question_filter.course_id, question_filter.chapter_id) do create-question.sh
# cộng vào.
QUESTION_CFG="${QUESTION_CFG:-}"
[ -n "$QUESTION_CFG" ] || QUESTION_CFG='{"groups":[],"assignment_type":"","quiz_question_instances":[],"level":"FUNDAMENTAL","is_self_reflection":false,"solution":"","hint":"","tags":[],"question_category_id":[],"question_topic_id":"question-list","text_editor_files":[],"is_independent_question":false,"quiz":{}}'

# ------------------------------------------------ Dựng cấu trúc (bước 6) -----
# Tên và vị trí của Unit — mỗi Section đúng một Unit, quy ước của LMS.
UNIT_NAME="${UNIT_NAME:-Learning activity}"
UNIT_POSITION="${UNIT_POSITION:-1}"

# Activity không khai duration trong plan thì dùng số này. ĐỪNG để 0:
# API trả 422 exceptions.invalid_data với duration < 1.
ACTIVITY_DEFAULT_DURATION="${ACTIVITY_DEFAULT_DURATION:-30}"

# Bề rộng thẻ <img> khi nhúng ảnh vào Document TEXT. Không phải script dùng —
# Claude dùng khi viết HTML; để ở đây cho cùng một chỗ tra.
IMAGE_DEFAULT_WIDTH="${IMAGE_DEFAULT_WIDTH:-200}"

# Kích thước thẻ <img> của ảnh trong đề bài câu hỏi (question_content).
# create-question.sh dùng — khác Document TEXT, ảnh câu hỏi có cả height.
QUESTION_IMAGE_WIDTH="${QUESTION_IMAGE_WIDTH:-836}"
QUESTION_IMAGE_HEIGHT="${QUESTION_IMAGE_HEIGHT:-428}"

# ------------------------------------------------------------- Phân trang ----
# start.sh chỉ quét trang ĐẦU để xác thực id. Khóa/topic nằm ngoài trang đầu sẽ
# bị báo "không có trong danh sách" dù id đúng — tăng số này nếu gặp.
PAGE_SIZE_COURSES="${PAGE_SIZE_COURSES:-100}"
PAGE_SIZE_CATEGORIES="${PAGE_SIZE_CATEGORIES:-50}"

# ----------------------------------------------------------------- Mạng ------
# Upload: video vài chục MB nên max-time rộng. Presigned URL của S3 sống 1 giờ,
# đặt MAX_TIME lớn hơn 3600 là vô nghĩa.
UPLOAD_CONNECT_TIMEOUT="${UPLOAD_CONNECT_TIMEOUT:-20}"
UPLOAD_MAX_TIME="${UPLOAD_MAX_TIME:-3600}"
UPLOAD_RETRY="${UPLOAD_RETRY:-2}"

# Tải media từ Lark về máy.
DOWNLOAD_CONNECT_TIMEOUT="${DOWNLOAD_CONNECT_TIMEOUT:-20}"
DOWNLOAD_MAX_TIME="${DOWNLOAD_MAX_TIME:-1800}"
DOWNLOAD_RETRY="${DOWNLOAD_RETRY:-3}"

# ------------------------------------------------------------------ Khác -----
# QUIZ_CFG — cấu hình chung của cả bốn loại bài test — nằm ở
# scripts/course/quiz-config.sh.
