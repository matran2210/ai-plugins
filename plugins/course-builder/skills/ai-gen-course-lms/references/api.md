# Quy ước API và phiên — dùng chung cho mọi đối tượng

Áp dụng cho mọi nhánh. Bảng lỗi và bẫy riêng của từng đối tượng nằm trong
`references/<đối tượng>/workflow.md`.

## Endpoint và header

`BASE` = `$UPBASE_BASE_URL`, phân giải ở **`scripts/config.sh`** theo `$UPBASE_ENV`:

| `UPBASE_ENV` | Base URL |
|---|---|
| `staging` (mặc định) | `https://uplms-api.staging.upbase.asia/ops/api/v1` |
| `prod` | `https://uplms-api.upbase.asia/ops/api/v1` |

Hai môi trường khác **đúng base URL**; endpoint, payload và mã lỗi y hệt nhau. Chọn môi trường ở panel của `login.sh`, hoặc `export UPBASE_ENV=prod`.

### Đăng nhập nằm ở HOST KHÁC

Token lấy từ Keycloak, **không phải** từ `$UPBASE_BASE_URL`. Hai host tách rời nhau, nên mạng chặn được cái này mà vẫn thông cái kia:

| `UPBASE_ENV` | `$UPBASE_AUTH_URL` |
|---|---|
| `staging` | `https://accounts.staging.upbase.asia/realms/lms/protocol/openid-connect/token` |
| `prod` | `https://accounts.upbase.asia/realms/lms/protocol/openid-connect/token` |

Luồng là OAuth2 password grant — `POST` form-urlencoded, **không phải JSON**:

```
grant_type=password · client_id=$UPBASE_AUTH_CLIENT_ID · username · password
```

Client mặc định `ops-frontend`, là **public client**, không có `client_secret`. Token nằm ở `.access_token` của response.

| Mã | `.error` | Nghĩa |
|---|---|---|
| `400` | `invalid_grant` | sai tên đăng nhập hoặc mật khẩu |
| `400` | `unauthorized_client` | Keycloak **chưa bật Direct access grants** cho client đó — cấu hình phía Keycloak, đăng nhập lại không giải quyết được |
| `401` | `invalid_client` | client id không tồn tại ở realm. Đổi bằng `export UPBASE_AUTH_CLIENT_ID=…` |

> ⚠️ **Hạn token do realm Keycloak quyết định**, không còn là con số cố định của UpBase. `login.sh` đọc `exp` trong JWT và in thời gian còn lại thật — tin con số nó in, đừng tin con số viết trong tài liệu.

**Session file tách theo môi trường** (`upbase-session-staging.env` / `-prod.env`) và mang dấu `UPBASE_SESSION_ENV`. `lib.sh` bỏ token nếu dấu đó lệch môi trường đang chạy — token của môi trường này không dùng được ở môi trường kia.

Mọi request:

```
Authorization: Bearer ${TOKEN}
Accept: application/json
```

Có body thì thêm `Content-Type: application/json`.

`scripts/lib.sh:api()` đã gắn sẵn ba header này. Bảng trên dành cho lúc đọc log
hoặc dựng lại request bằng tay khi debug.

## Phân trang — tên trường không thống nhất

`GET /courses` để metadata phân trang ở `data.metadata` (endpoint khác dùng `data.meta`). Viết nhầm thì `jq` trả `null` mà không báo lỗi, nên số trang im lặng thành rỗng.

`GET /courses` bắt buộc kèm **cả** `page_index` lẫn `page_size`; thiếu một cái
trả `422`. Danh sách sắp xếp theo `created_at` giảm dần, nên `courses[0]` là khóa
mới tạo gần nhất.

## Xác thực

| Mã | Ý nghĩa và cách xử lý |
|---|---|
| `401` | Token hết hạn. Nhờ người dùng chạy `scripts/login.sh` trong terminal của họ, rồi lặp lại **đúng lệnh cũ** — state giữ tiến độ nên phần đã xong không bị tạo lại. Không tự chạy `login.sh`, không đoán token, không dùng lại token cũ. |
| `403` | Token hợp lệ nhưng tài khoản không có quyền trên tài nguyên đó. Đăng nhập lại không giải quyết được — báo người dùng. |

`check_auth()` chỉ bắt `401`. Mọi mã khác rơi xuống nhánh xử lý lỗi của từng
script.

## Bẫy phiên đã kiểm chứng

Bốn điểm dưới đây áp dụng cho mọi đối tượng vì cả hai nhánh dùng chung
`scripts/lib.sh` và `scripts/login.sh`.

| Hiện tượng | Nguyên nhân |
|---|---|
| Vừa đăng nhập xong mà request vẫn `401` | Không còn cửa kiểm token nào ở phía client — `login.sh` đăng nhập lại mỗi lượt, token hỏng chỉ lộ ở request thật. Gặp `401` ngay lệnh đầu thì nhờ người dùng đăng nhập lại. |
| Vừa đăng nhập xong nhưng script vẫn bắn vào id cũ | `_load_env_file()` cho **biến môi trường thắng file**. Một `UPBASE_TOKEN` hoặc `UPBASE_COURSE_ID` còn `export` trong shell sẽ đè giá trị vừa ghi. Kiểm bằng `env \| grep UPBASE_`. |
| `start.sh` báo `id không có thật` với khóa chắc chắn tồn tại | Khâu xác thực chỉ quét trang đầu `GET /courses?page_index=1&page_size=100`. Khóa nằm ngoài 100 khóa mới nhất không được thấy. Truyền thẳng `--course <uuid>` không giúp được, vì chính bước đối chiếu này dùng danh sách đó. |
| Mất token dù chưa hết hạn | `$TMPDIR` bị dọn khi máy khởi động lại. Muốn session sống lâu hơn: `export UPBASE_ENV_FILE="$HOME/.upbase-session-$UPBASE_ENV.env"` — giữ `$UPBASE_ENV` trong tên để hai môi trường không đè nhau. |

## Session dùng chung

Một file cho mỗi môi trường: `$UPBASE_ENV_FILE`, mặc định
`$TMPDIR/upbase-session-<env>.env`, `chmod 600`. Chứa `UPBASE_SESSION_ENV`,
`UPBASE_TOKEN`, `UPBASE_TOPIC_ID`, `UPBASE_COURSE_ID`, `UPBASE_BASE_URL`.

Mỗi `start.sh` ghi lại file này theo kiểu atomic (`.tmp` → `chmod 600` → `mv`) và
giữ nguyên các khóa của đối tượng khác. Đăng nhập một lần dùng được cho mọi nhánh.
