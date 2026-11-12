---
name: ai-gen-course-lms
description: Use when the user wants to build an UpBase LMS course from a Lark/Larksuite design document — they paste a Lark doc or wiki link ("dựng khóa học từ tài liệu này", "tạo khóa theo file Lark", "lên LMS khóa Planning E2E") and expect the course structure and media assets to follow that document exactly. Quiz, Section Test, Mid Test and Final Test are created as empty shells for manual question entry. Đọc tài liệu Lark, tải ảnh/video về project, xuất outline.md cho người dùng duyệt, rồi mới call API tạo. Không tự nghĩ chủ đề, không bịa nội dung ngoài tài liệu.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__lark__drive_v1_file_list, mcp__lark__wiki_v1_node_search, mcp__lark__wiki_v2_space_getNode, mcp__lark__docx_v1_document_rawContent, mcp__lark__docx_v1_document_get, mcp__lark__docx_v1_documentBlock_list, mcp__lark__drive_v1_media_batchGetTmpDownloadUrl
---

# AI Gen Course LMS

Một luồng thẳng, không phân nhánh. **Đầu vào duy nhất là một link tài liệu Lark**; đầu ra là khóa học trên LMS đúng bằng nội dung tài liệu đó.

```text
bước 0  cửa chặn Lark          → đọc được tài liệu mới đi tiếp
bước 1  đọc tài liệu nguồn      → block list, không chỉ rawContent
bước 2  tải ảnh/video về project → đặt tên lại, map vào outline
bước 3  xuất outline.md          → NGƯỜI DÙNG DUYỆT, cửa chặn cứng
bước 4  cửa chặn đăng nhập OPS   → login.sh
bước 5  tạo khóa + ảnh bìa + media  → course_id · resource_id · quiz_id
bước 6  dựng cấu trúc khóa học   → references/create-structure.md
bước 7  tạo câu hỏi rồi bài test → câu hỏi TRƯỚC, test tham chiếu id
```

Thứ tự sau là **cố ý, không đảo được**:

- **Bước 5 trước bước 6.** Ảnh nhúng vào HTML của Document TEXT bằng `resource_id`, và **không có endpoint sửa Document sau khi tạo**. Upload sau khi dựng document là ảnh không bao giờ vào được bài học.

> 🚫 **Không tạo Question Topic.** Câu hỏi tạo thẳng vào ngân hàng câu hỏi của khóa (`question_filter.course_id`), gắn vào Section qua `question_filter.chapter_id`. Bài test tài liệu không viết câu nào thì để khung rỗng — không tự nghĩ câu hỏi.

Thứ tự bắt buộc, không đảo, không gộp, không làm trước.

> 🚫 **Không tự nghĩ chủ đề, không bịa nội dung.** Tài liệu Lark là nguồn duy nhất. Không có link → hỏi người dùng và **kết thúc lượt**, đừng đề xuất chủ đề, đừng dựng khóa mẫu.

## Thư mục làm việc

**Không bao giờ `cd`.** Mọi lệnh chạy với cwd là **thư mục dự án của người dùng**.

Mọi thứ skill sinh ra nằm gọn trong **một thư mục mang tên khóa học**, không rải ra gốc dự án:

```text
<thư mục dự án>/
└── <course-slug>/              ← tên khóa, không dấu, gạch nối: planning-e2e
    ├── outline.md              ★ thứ DUY NHẤT người dùng cần đọc
    ├── assets/                 ảnh, video, handout tải từ Lark
    │   ├── s01-a01-….mp4
    │   └── s01-a02-….png
    └── work/                   file làm việc của skill, người dùng không phải mở
        ├── state.json          id mọi node đã tạo — dùng chung bước 5→7
        ├── media-manifest.json resource_id / quiz_id của từng file
        └── plan-s1.json …      plan từng Section, bước 6
```

Ba tầng, mỗi tầng một vai trò: `outline.md` để người dùng duyệt · `assets/` là file thật · `work/` là thứ chỉ skill dùng.

> 💡 Đặt plan trong `work/` còn có lợi về mặc định: `build-section.sh` lấy `state.json` **cạnh file plan**, nên tự trỏ đúng `work/state.json` mà không cần `--state`. Các script tạo bài test vẫn phải truyền `--state` tường minh.

`<course-slug>` chốt ngay ở **bước 1**, ngay khi đọc được tên khóa trong tài liệu, rồi dùng nguyên vẹn cho cả lượt. Mọi lệnh trong tài liệu này viết đường dẫn tương đối tính từ **gốc dự án**, nên luôn có tiền tố `<course-slug>/`.

Một khóa học một thư mục: dựng khóa thứ hai là thư mục mới, `state.json` mới, không đụng gì tới khóa cũ.

Script thì nằm trong thư mục skill, là thư mục khác. **Mọi tài liệu của skill này — `SKILL.md` và cả `references/*.md` — đều viết tắt `scripts/…` cho gọn. Khi chạy thật phải đổi thành đường dẫn đầy đủ tới thư mục skill:**

```bash
# tài liệu viết:   scripts/course/start.sh --course <id>
# chạy thật:
/đường/dẫn/tới/skill/ai-gen-course-lms/scripts/course/start.sh --course <id>
```

**Việc đầu tiên của lượt**, trước cả bước 0: xác định đường dẫn thư mục skill và dùng lại nguyên văn cho mọi lệnh sau. Skill được cài qua plugin `course-builder`, nên thư mục này nằm trong cache plugin (dạng `~/.claude/plugins/cache/<marketplace>/course-builder/<version>/skills/ai-gen-course-lms/`) — lấy đúng đường dẫn ở dòng *Base directory for this skill* hiện ra khi skill được nạp, đừng đoán.

> ⚠️ **Đừng đặt vào biến shell** kiểu `SKILL=$(...)`. Mỗi lệnh Bash là một shell riêng — biến không sống sang lệnh kế tiếp, và từ lệnh thứ hai trở đi đường dẫn sẽ thành `/scripts/…`.

## Bước 0 — cửa chặn Lark

Không có link tài liệu thì dừng ở đây. Có rồi thì phải **đọc được** nó mới sang bước 1: chưa đọc được thì không đăng nhập OPS, không đọc `references/` khác, không soạn gì.

### 0.0 App Lark đã khai chưa

`.mcp.json` chỉ chứa `${LARK_APP_ID}` / `${LARK_APP_SECRET}`; giá trị thật nằm ở máy người dùng.

```bash
scripts/lark-setup.sh --check
```

Exit 0 → sang 0.1. Exit 1 (`THIẾU KHAI BÁO`) → nói một câu rằng hộp thoại đang mở, rồi chạy `scripts/lark-setup.sh --gui` với timeout **600000** ms.

| Kết quả | Làm gì |
|---|---|
| `=== ĐÃ LƯU ===` | **kết thúc lượt**, bảo người dùng khởi động lại đúng host đang chạy skill — tiến trình MCP đang chạy vẫn giữ env cũ |
| `đã hủy` | báo lại, **kết thúc lượt**, đừng mở lại hộp thoại |
| máy không có GUI | nhắc người dùng tự chạy ở terminal của họ, kết thúc lượt |

> ⚠️ **Chỉ gọi `--check` và `--gui`, không bao giờ gọi bản trần** — bản trần nhận App Secret qua stdin mà stdin lúc đó là stream bạn kiểm soát. **Không bao giờ nhận App ID/Secret qua khung chat.**

### 0.1 → 0.4 Xác thực token

Token Lark sống trong RAM tiến trình `lark-mcp`, không có file cache, nên cách duy nhất biết còn hạn là gọi thật: `mcp__lark__drive_v1_file_list` với `params: {page_size: 1}`, `useUAT: true`.

- Ra JSON có `files` → sang bước 1.
- `Current user_access_token is invalid or expired` → **trong chính thông báo lỗi có sẵn `Authorization URL`**.

Link chỉ sống **60 giây**, và **mỗi lần gọi lại bất kỳ tool Lark nào sẽ sinh link mới đồng thời huỷ link cũ**. Nên tool call kế tiếp phải là lệnh mở link — không grep, không đọc file, không nghĩ thêm:

```bash
open '<Authorization URL copy nguyên văn từ thông báo lỗi>'
```

Nói trước một câu để người dùng ngó sang browser. Máy không phải macOS thì in link ra cho họ tự mở.

Rồi chờ cổng callback đóng — **tuyệt đối không gọi tool Lark trong lúc chờ**:

```bash
if command -v lsof >/dev/null 2>&1; then
  while lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1; do sleep 2; done
else
  sleep 45
fi
echo CONG_3000_DA_DONG
```

Nhánh `else` là bắt buộc: máy không có `lsof` thì `while` thoát ngay vòng đầu và bạn sẽ kết luận nhầm.

Cổng đóng **không đồng nghĩa thành công** — link hết hạn cũng đóng. Gọi lại đúng lệnh ở 0.1 để xác minh. Vẫn lỗi → làm lại từ bước mở link. **Ba lượt liên tiếp không được thì kết thúc lượt**, đừng mở link lần thứ tư.

| Hiện tượng khác | Xử lý |
|---|---|
| browser báo lỗi `redirect_uri` | app chưa khai `http://localhost:3000/callback` → thêm tại `https://open.larksuite.com/app/<app_id>/safe` rồi làm lại |
| `client_id` là chuỗi `${LARK_APP_ID}` (lỗi `20028`) | env chưa nạp — chạy lại 0.0 rồi **khởi động lại host** |
| không có tool `mcp__lark__*` | server `lark` chưa cấu hình. Nhắc người dùng thêm qua `claude mcp`, **kết thúc lượt** |
| không có `mcp__lark__drive_v1_media_batchGetTmpDownloadUrl` | thiếu tool tải media trong `-t` của `.mcp.json` → xử lý theo `references/lark-source.md` |

## Bước 1 — đọc tài liệu nguồn

Toàn bộ quy tắc đọc, bảng `block_type`, cách bóc Section / Activity / LO / bài test: **`references/lark-source.md`**. Đọc file đó trước khi gọi lệnh đầu tiên.

Chuỗi bắt buộc, rẽ theo tiền tố ngay trước token trong URL:

| Dạng URL | Làm gì |
|---|---|
| `.../wiki/<token>` | `wiki_v2_space_getNode({token})` → lấy `obj_token` + `obj_type` → dùng `obj_token` làm `document_id` |
| `.../docx/<token>` | `<token>` chính là `document_id` |
| chỉ có tên tài liệu, không URL | `wiki_v1_node_search({query})`; **đọc tên tìm được cho người dùng xác nhận** trước khi dùng |

Rồi đọc **cả hai**, không chỉ một:

1. `docx_v1_document_rawContent({document_id})` — text phẳng, để đọc nhanh và đối chiếu.
2. `docx_v1_documentBlock_list({document_id}, {page_size: 500})` — **nguồn sự thật**. Chỉ ở đây mới có token ảnh/video, mới thấy bảng nhúng, mới biết cấp heading.

> ⚠️ **`rawContent` không đủ và biết bỏ sót mà không báo.** Nó render bảng nhúng thành **rỗng** và render video/ảnh thành **tên file trần**. Lấy `rawContent` làm nguồn duy nhất là bảo đảm mất media và mất bảng.

`has_more: true` thì phải phân trang hết bằng `page_token`. Đọc thiếu trang là thiếu Section, không phải "khóa ngắn".

**Đọc tên tài liệu ra cho người dùng** (`node.title`) trước khi đi tiếp. Tên không khớp thứ họ nói → dừng, hỏi lại link.

## Bước 2 — tải ảnh/video về project

Cơ chế đầy đủ, quy ước đặt tên, bảng lỗi: **`references/lark-source.md`**, mục *Media*.

Tóm tắt: gom `file.token` (block 23) và `image.token` (block 27) từ block list → `drive_v1_media_batchGetTmpDownloadUrl` lấy URL tạm → `scripts/media/download.sh` tải về `<course-slug>/assets/` với tên đã chuẩn hóa theo vị trí trong cây.

Ba điều không được làm:

1. **Không bỏ qua media vì "chỉ là minh họa".** Tài liệu có bao nhiêu file thì tải bấy nhiêu.
2. **Không đặt tên theo tên gốc trong Lark.** Tên gốc trùng lặp và có dấu cách; phải đổi theo quy ước để map được vào outline.
3. **Không đoán nội dung file.** Video/ảnh chỉ được ghi nhận là *tài sản đã tải kèm đường dẫn*, không được diễn giải thành nội dung bài học.

File nào tải lỗi thì ghi vào mục *Sai lệch* của outline; **không** lặng lẽ bỏ.

## Bước 3 — xuất outline.md và chờ người dùng duyệt

Đặc tả từng mục của file: **`references/outline-format.md`**.

Ghi ra `<course-slug>/outline.md`. Chưa có thư mục thì tạo. File này là bản dịch 1-1 từ tài liệu Lark sang thứ sẽ được tạo trên LMS — cộng bảng media đã tải, cộng mục *Sai lệch và thiếu hụt*.

> 🚫 **Cửa chặn cứng.** Xuất file xong thì **kết thúc lượt** và chờ người dùng duyệt bằng lời. Không call API tạo, không đăng nhập OPS, không soạn plan JSON, không "làm trước phần chắc chắn đúng". Người dùng sửa gì thì sửa vào `outline.md` rồi bảo bạn chạy lại — theo họ, không bẻ lại theo chuẩn.

**Không hỏi id nào cả.** Skill tự tạo khóa học ở bước 5 và các khung bài test rỗng ở bước 7. Việc duy nhất cần ở người dùng là **duyệt outline** và trả lời các mục *Sai lệch* cần họ quyết.

## Bước 4 — cửa chặn đăng nhập OPS

Chỉ tới đây mới đăng nhập, và chỉ khi outline đã được duyệt.

> 🚫 **LUÔN đăng nhập lại. Không kiểm token cũ, không giả định môi trường.**
> Không có cửa kiểm nào trước bước này: thấy còn token trong session file **cũng mặc kệ**, vẫn mở hộp thoại. Hạn token do realm Keycloak quyết định, đoán ở phía client là đoán sai — và quan trọng hơn, **người dùng phải được chọn lại môi trường mỗi lượt**.
>
> Tuyệt đối **không** nói những câu kiểu *"OPS xác thực còn hạn"*, *"môi trường đang dùng là staging"* rồi đi tiếp. Chưa chạy hộp thoại ở lượt này thì chưa biết gì cả.

Nói trước một câu rằng hộp thoại đang mở, rồi chạy lệnh sau với timeout **600000** ms — lệnh chờ người nhập tay nên lâu:

```bash
scripts/login.sh --gui
```

Hộp thoại hỏi **môi trường trước**, rồi mới tới tài khoản.

| Kết quả | Làm gì |
|---|---|
| `=== ĐÃ ĐĂNG NHẬP (<env>) ===` | sang bước 5, và **báo người dùng đang ở môi trường nào** |
| `đã hủy` | báo lại, **kết thúc lượt**, đừng mở lại hộp thoại |
| dừng vì máy không có GUI | nhắc người dùng tự chạy `scripts/login.sh` ở terminal của họ, kết thúc lượt và chờ |

### Hai môi trường OPS

Hộp thoại đăng nhập mở **panel chọn môi trường trước tiên**:

| | Base URL | Session file |
|---|---|---|
| **staging** (mặc định) | `https://uplms-api.staging.upbase.asia/ops/api/v1` | `$TMPDIR/upbase-session-staging.env` |
| **prod** | `https://uplms-api.upbase.asia/ops/api/v1` | `$TMPDIR/upbase-session-prod.env` |

Mọi endpoint và payload y hệt nhau — **khác đúng base URL**. Riêng **đăng nhập nằm ở host khác hẳn** (Keycloak, `accounts[.staging].upbase.asia`); chi tiết và bảng mã lỗi ở `references/api.md`.

> 🚫 **Không tự chọn môi trường thay người dùng.** Người dùng chọn trong panel, **mỗi lượt**. Cần chỉ định sẵn thì họ tự chạy `scripts/login.sh --env prod`; **bạn không truyền `--env`** trừ khi họ nói rõ trong chính lượt này. Môi trường của lượt trước không có giá trị gì cho lượt này.
>
> ⚠️ **Token tách theo môi trường**, mỗi môi trường một session file, và file có dấu `UPBASE_SESSION_ENV`. Lệch môi trường thì `lib.sh` **bỏ token** thay vì dùng — không có đường nào bắn token staging vào prod.

Môi trường người dùng vừa chọn ở panel quyết định mọi lệnh về sau. Chọn prod thì **mọi lệnh** từ bước 5 trở đi phải mang `UPBASE_ENV=prod`:

```bash
UPBASE_ENV=prod scripts/course/start.sh --course <id>
```

**Đọc dòng môi trường ra cho người dùng ở đầu bước 5, 6 và 7.** `start.sh` và `create-course.sh` in nó ra; prod thì có `⚠️ MÔI TRƯỜNG: PRODUCTION`. Skill này tạo được nhưng **không xóa được**, nên nhầm môi trường là hỏng thật.

> ⚠️ **Chỉ được gọi `--gui`. Không bao giờ gọi `scripts/login.sh` trần.** Bản trần cho phép nhập qua terminal, mà stdin lúc đó là stream bạn kiểm soát; `--gui` chặn hẳn nhánh đó nên mật khẩu chỉ có thể đi từ cửa sổ đồ hoạ vào tiến trình script. **Không bao giờ nhận tên đăng nhập hay mật khẩu qua khung chat** — dán vào đó là chúng nằm vĩnh viễn trong transcript và log phiên.

## Bước 5 — tạo khóa học, ảnh bìa, media và tài liệu khóa

Bốn việc, đúng thứ tự: khóa học phải tồn tại trước vì thư mục media là **của khóa** (`object_id=<course_id>`); ảnh bìa và tài liệu khóa đều cần `course_id`; và 5.4 cần `resource_id` do 5.3 sinh ra.

### 5.1 Tạo khóa học

```bash
scripts/course/create-course.sh \
  --name        "<Name:>" \
  --description "<Description: → <p>…</p>>" \
  --category    "<Course Category:>" \
  --type        "<Type:>" \
  --pass-point  "<Passpoint:>" \
  --setting     '{"progress":<Tiến độ học>,"activity_points":0,"chapter_points":<Section Test>,"topic_points":0,"mid_term_points":<Mid Test>,"final_test_points":<Final Test>}' \
  --state <course-slug>/work/state.json
scripts/course/start.sh --course <COURSE_ID vừa in ra>
```

**Sáu giá trị lấy từ vùng *Thông tin khóa học*** theo luật `Nhãn: giá trị` — đúng những gì `outline.md` mục 2 đã ghi. Tài liệu khai gì thì gửi nấy; **đừng dùng mặc định trong `config.sh` khi tài liệu có khai**. Nhãn nào tài liệu bỏ trống thì bỏ cờ đó, script tự dùng fallback và in cảnh báo — và outline phải đã có một dòng *Sai lệch*.

`--category` là **bắt buộc**. Script search theo tên (`GET /course_categories?name=…`) rồi thu hẹp bằng ba mức: khớp chính xác → tên category nằm trong giá trị tài liệu (dài nhất thắng) → giá trị tài liệu nằm trong tên category. Search rỗng thì lấy nguyên danh sách khớp lại.

> 🚫 **Khớp 0 hoặc >1 đều làm script DỪNG, không bao giờ tự chọn phần tử đầu.** Khớp nhiều thì ghi một dòng vào *Sai lệch* của outline, in các tên khớp và **hỏi người dùng chọn**; họ sửa `Course Category:` thành tên đầy đủ rồi chạy lại.

Không truyền `code` — BE tự sinh. `status: DRAFT` và `template` không do tài liệu quyết.

> ⚠️ **Khóa học không xóa được bằng bộ script này.** Key state `course:<tên>` khiến chạy lại in `SKIP`; đừng đổi `--state` giữa chừng, đổi là tạo khóa thứ hai trùng tên.

Đọc `COURSE_ID` ra cho người dùng, kèm tên khóa và trạng thái `DRAFT`.

`start.sh` xác thực khóa vừa tạo và ghi session; bước 6–7 dùng lại đúng phiên này, không cần mở lại.

### 5.2 Ảnh bìa khóa học

Tài liệu có nhãn `Thumbnail:` kèm ảnh thì đặt ảnh bìa ngay sau khi có `course_id`:

```bash
scripts/course/upload-course-image.sh \
  --image <course-slug>/assets/<tên ảnh thumbnail> \
  --state <course-slug>/work/state.json --dry-run
scripts/course/upload-course-image.sh \
  --image <course-slug>/assets/<tên ảnh thumbnail> \
  --state <course-slug>/work/state.json
```

`PUT /courses/image` dạng multipart — **endpoint riêng, không đi qua luồng resource của 5.3**. Không sinh `resource_id`, không nhúng vào Document nào.

Khác mọi thứ còn lại của bước 5 ở một điểm: **ảnh bìa đặt lại được bất cứ lúc nào**, không phải gắn-lúc-tạo. Nên bỏ sót nó không hỏng gì vĩnh viễn — chạy lại script là xong.

> 🚫 **Không có nhãn `Thumbnail:`, hoặc nhãn đó không có ảnh → bỏ qua 5.2.** Đừng lấy tạm ảnh nào khác trong tài liệu làm ảnh bìa. Ghi một dòng *Sai lệch* rồi đi tiếp.

### 5.3 Upload media

Lặp cho **mọi file đã tải ở bước 2, TRỪ ảnh bìa** — ảnh, video, và handout đính kèm:

> 🚫 **Đừng đẩy ảnh `Thumbnail:` qua đây.** Nó đã lên ở 5.2 bằng endpoint khác. Đẩy lại lần nữa là sinh thêm một resource thừa trong thư mục của khóa, mà không nhãn nào trong tài liệu trỏ tới.

```bash
scripts/course/upload-media.sh <course-slug>/assets/<file> \
                              --manifest <course-slug>/work/media-manifest.json --dry-run
scripts/course/upload-media.sh <course-slug>/assets/<file> \
                              --manifest <course-slug>/work/media-manifest.json
```

Script làm bốn call, mỗi call cần kết quả call trước: lấy folder khóa → xin `file_key` + presigned URL → `PUT` lên S3 → tạo resource. Chi tiết và bảng lỗi: **`references/upload-media.md`**.

**Ảnh trong đề bài câu hỏi** (`q-…-img<NN>.*`, ảnh ngay dưới `Câu <n>.`) cũng upload ở đây, nhưng thêm `--folder-type QUESTION`. Chỉ khác call đầu: `GET /resources/upload/folder?type=QUESTION` thay cho folder của khóa; ba call sau giống hệt.

```bash
scripts/course/upload-media.sh <course-slug>/assets/q-<test>-c<NN>-img<NN>.png --folder-type QUESTION \
                              --manifest <course-slug>/work/media-manifest.json --dry-run
```

Kết quả ghi vào `media-manifest.json`, khoá theo đường dẫn file. **Đây là bảng tra của bước 6:**

| Media nằm dưới nhãn | Lấy trường | Nhét vào |
|---|---|---|
| `Video:` trong một Tab | `quiz_id` | `{"type":"VIDEO","video_quiz_ids":["…"]}` trong plan |
| nội dung một `Text:` | `resource_id` | `<img src="PRESIGN_URL" title="<display_name>" resource_id="…" width="200">` trong `content` của **chính document TEXT đó** |
| `Resource:` của Activity | `resource_id` | `files: [{"resource_id":"…","type":"attached"}]` ở **cấp Activity** |
| ngay dưới `Câu <n>.` (trước nhãn đầu tiên của câu) | — | đường dẫn file vào `images[]` của câu đó ở plan 7.1 — **script tự tra `resource_id`** |

> 🚫 **Nhãn bọc ngoài quyết định, không phải loại file.** Chỉ file nằm dưới `Resource:` mới thành file đính kèm Activity. Ảnh nằm giữa nội dung một `Text:` là ảnh của bài viết đó — nhúng vào HTML của Document TEXT, **không** đẩy sang `files[]` của Activity. Chi tiết: *Media đi đâu* trong `references/lark-source.md`.

File dưới `Course Resource:` cũng upload ở bước này, nhưng id của nó **không vào bảng trên** — nó đi tiếp sang 5.4.

Bốn điều bắt buộc cho 5.3:

1. **Upload hết trước khi sang bước 6.** Cả ba loại đều gắn vào lúc **tạo** node — không có endpoint sửa Document hay Activity đã tạo. Thiếu một file là thiếu vĩnh viễn.
2. **Không nhầm `resource_id` với `quiz_id`.** Hai trường khác nhau trong cùng response; dùng nhầm thì video không phát được mà vẫn `201`.
3. **`src` của `<img>` là hằng chuỗi `PRESIGN_URL`** — viết nguyên văn, không thay bằng URL thật. LMS dựng ảnh bằng `resource_id`; `src` rỗng làm trang hiển thị lỗi.
4. **URL presigned sống 1 giờ.** File lớn cứ để chạy; đừng lấy URL rồi để dành sang lượt sau.

**File quá lớn thì script bỏ qua và đi tiếp** (server trả `type` khác `SINGLE_PART` — skill không làm luồng multipart). Không phải lỗi, không dừng lượt. Khi đó:

- **Bước 6 không tạo document cho file đó.** Nhét `null` vào `video_quiz_ids` hay `resource_id=""` là tạo document hỏng mà vẫn `201`.
- **Báo theo từng Activity**: Activity nào thiếu media gì, kèm đường dẫn ở `assets/` để người dùng tự upload trên giao diện.

### 5.4 Đính tài liệu của khóa

Tài liệu có nhãn `Course Resource:` kèm file thì đính chúng vào khóa, **sau khi 5.3 đã upload xong** các file đó:

```bash
scripts/course/add-course-resource.sh \
  <course-slug>/assets/<file 1> <course-slug>/assets/<file 2> \
  --manifest <course-slug>/work/media-manifest.json \
  --state <course-slug>/work/state.json --dry-run
scripts/course/add-course-resource.sh \
  <course-slug>/assets/<file 1> <course-slug>/assets/<file 2> \
  --manifest <course-slug>/work/media-manifest.json \
  --state <course-slug>/work/state.json
```

Đây là **call thứ năm** nối sau bốn call của 5.3: `POST /courses/<id>/add-resource` với `attachments: [{resource_id, type:"attached", dom_id:"", note:""}]`.

Truyền **đường dẫn file**, không phải `resource_id` — script tra id từ manifest, y như cách bước 6 tra. File nào chưa upload là script **dừng**; file nào bị bỏ qua vì quá lớn thì nó cảnh báo rồi đính những file còn lại.

> ⚠️ **Mọi file trong MỘT call.** `attachments` là mảng, và script chỉ gọi **đúng một lần** cho mỗi khóa (state key `courseresource:<course_id>`). Chưa kiểm chứng được gọi lần hai thì server cộng thêm hay thay thế danh sách, nên liệt kê **đủ mọi file ngay lần đầu**. Cần đính thêm về sau: xoá khoá đó trong `state.json` rồi chạy lại **với đủ mọi file**, không chỉ file mới.

> 🚫 **`Course Resource:` không phải `Resource:`.** Cái này đính vào **cả khóa**; `Resource:` dưới một `Activity <n>` đính vào Activity đó và gắn ở bước 6 qua `files[]`. Đừng trộn hai danh sách.

Không có nhãn, hoặc nhãn không có file → **bỏ qua 5.4**. Khóa không có tài liệu đính kèm là trạng thái hợp lệ.

## Bước 6 — dựng cấu trúc khóa học

Đọc **`references/create-structure.md`** và làm theo đúng file đó, từ `scripts/course/start.sh` cho tới báo cáo.

Khác hai điểm so với cách file đó mô tả:

1. **Dàn ý không còn phải chốt với người dùng** — đã chốt ở `outline.md` bước 3. Không đề xuất lại, không hỏi lại số Section, không tự thêm Activity cho "tròn".

> 🚫 **Chỉ tạo node nào tài liệu có NHÃN**, và **nội dung là phần sau dấu hai chấm**:
> `Section <n>` → Section · `Activity <n>` → Activity · `Time:` → `duration` · `Type of Activity:` → `display_icon`/`is_graded` · `Resource:` → `files[]` · `Tab <n>:` → một Tab · trong Tab: `Text:` → TEXT, `Video:` → VIDEO, `Quiz:` → QUIZ rỗng (tạo ở bước 7).
>
> 🏷️ **Tên Section / Activity / bài test nằm ở nhãn `Name:` bên dưới heading**, không phải chữ sau dấu hai chấm của heading. Heading `Section 1` / `Activity 2` / `Section Test:` chỉ khai loại node và số thứ tự. Không có `Name:` thì mới lấy phần sau dấu hai chấm của heading (dạng cũ).
>
> 🎯 **LO khai một chỗ, Activity tham chiếu bằng SỐ.** LO con nằm dưới `Learning Outcome: > Nội dung:` của Section, đánh số; Activity ghi `Learning Outcome: 1, 3` là trỏ tới số 1 và 3. Một LO con dùng chung cho nhiều Activity là bình thường. LMS chỉ có **một node LO cho cả Section** — tạo nó trước, rồi Activity gắn `course_learning_outcome_id` + `course_outcome_ids` lúc **tạo**; không có endpoint gắn sau.
>
> Bảng đầy đủ: `references/lark-source.md`.
2. **Bước này không tạo bài test nào.** Trong plan JSON để `section_test: false` và **không** đặt document `{"type":"QUIZ"}`; cũng **không** chạy `create-course-test.sh`. Mọi khung bài test rỗng dồn sang bước 7.

`start.sh` in ra **tên khóa học** đọc từ API. Đọc lại cho người dùng. Tên không khớp `outline.md` → dừng, hỏi lại `course_id`. `=== SẴN SÀNG ===` mới đi tiếp.

## Bước 7 — tạo câu hỏi rồi tạo bài test

> ⚠️ **Câu hỏi TRƯỚC, bài test SAU.** Bài test tham chiếu id câu hỏi qua `quiz_questions[]` **lúc tạo**; không có endpoint gắn câu hỏi vào bài đã tạo. Làm ngược là bài test rỗng vĩnh viễn, mà API vẫn trả `201`.

### 7.1 Tạo câu hỏi

Soạn **một file cho một bài test** tại `<course-slug>/work/questions-<test>.json`:

```json
{
  "test": "final",
  "questions": [
    { "n": 1, "section": 1,
      "content": "<p>Market Research được định nghĩa như thế nào?</p>",
      "qtype": "One Choice",
      "layout": "One column",
      "answers": [
        { "answer": "Là quá trình thu thập và phân tích bằng chứng…", "is_correct": true },
        { "answer": "Quá trình thu thập càng nhiều dữ liệu càng tốt.", "is_correct": false }
      ] },
    { "n": 2, "section": 2,
      "content": "<p>Ghép mỗi chỉ số với điều nó phản ánh.</p>",
      "qtype": "Matching",
      "layout": "One column",
      "matchings": [
        { "left": "Tỷ lệ chuyển đổi",  "right": "Mức độ thuyết phục của trang sản phẩm" },
        { "left": "Lượt xem sản phẩm", "right": "Hiệu quả quảng cáo và thứ hạng tìm kiếm" }
      ] },
    { "n": 3, "section": 2,
      "content": "<p>doanh thu = lượt xem × {{blank}} × {{blank}}.</p>",
      "qtype": "Select Word",
      "layout": "Two column",
      "blanks": [
        { "correct": ["tỷ lệ chuyển đổi"],       "distractors": ["tỷ lệ hoàn đơn"] },
        { "correct": ["giá trị đơn trung bình"], "distractors": ["chi phí quảng cáo"] }
      ] }
  ]
}
```

```bash
scripts/course/create-question.sh <course-slug>/work/questions-final.json \
  --state <course-slug>/work/state.json --dry-run
scripts/course/create-question.sh <course-slug>/work/questions-final.json \
  --state <course-slug>/work/state.json
```

- `test` — khóa đặt state key `q:<test>:<n>`: `final`, `mid`, `section:1`, `tab:1:0:0`. **Một bài test một file**, và chính chuỗi này được `--questions` dùng lại ở 7.2.
- `n` — số trong nhãn `Câu <n>.`; là state key nên **không đánh lại**.
- `section` — **chỉ có ở `final` / `mid`, và bắt buộc ở đó**: số Section chép nguyên từ cột *Section* ở mục 5 của `outline.md` **đã duyệt**. Không phân tích lại ở bước này. Script tra `SECTION_ID` từ state key `section:<section>` làm `chapter_id`. Bài `section:N` / `tab:N:A:T` **không** khai — script lấy N từ `test`, khai là script dừng.
- `content` — đề bài **sau dấu chấm**, bọc `<p>…</p>`.
- `qtype` — **chép nguyên văn nhãn `Question Type:`**, bảy loại: `One Choice` · `Multiple Choice` · `True / False` · `Matching` · `Select Word` · `Fill Word` · `Drag & Drop`. Script tự quy ra enum API.
- `layout` — **chép nguyên văn nhãn `Question Layout:`**: `One column` hoặc `Two column`. Script tự quy ra `HORIZONTAL` / `VERTICAL`.
- `solution` — **tùy chọn**, lấy từ nhãn `Giải thích:`, bọc `<p>…</p>`. Không có nhãn thì bỏ hẳn trường.
- `images` — **tùy chọn**, mảng đường dẫn ảnh của đề bài (`"<course-slug>/assets/q-section01-c01-img01.png"`), đúng thứ tự tài liệu. Script tra `resource_id` trong `<course-slug>/work/media-manifest.json` (cạnh file câu hỏi; khác chỗ thì `--manifest`) và nối `<img src="PRESIGN_URL" … resource_id="…" width="836" height="428">` vào **sau** đề bài (kích thước lấy từ `QUESTION_IMAGE_WIDTH` / `QUESTION_IMAGE_HEIGHT` trong `scripts/config.sh`). Ảnh chưa upload, bị bỏ qua, hoặc không upload bằng `--folder-type QUESTION` → script **dừng**. Không gõ `<img>` tay vào `content` — script chặn.

> 🚫 **Không khai `display_type`, và không ghi `VERTICAL`/`HORIZONTAL` vào `layout`.** Script từ chối cả hai. Cặp giá trị này **ngược với trực giác** (`One column` → `HORIZONTAL`, `Two column` → `VERTICAL`) nên tự quy đổi là chỗ dễ chọn sai nhất — để script làm.

**Phần đáp án khác nhau theo loại — ba hình dạng, khai nhầm là script dừng:**

| Trường | Loại dùng |
|---|---|
| `answers[]` | `One Choice` · `Multiple Choice` · `True / False` |
| `matchings[]` | `Matching` |
| `blanks[]` (+ `distractors[]` cấp câu hỏi cho `Drag & Drop`) | `Select Word` · `Fill Word` · `Drag & Drop` |

- `answers[]` — theo **đúng thứ tự tài liệu viết**: `Đáp án đúng:` trước, rồi `Đáp án nhiễu:`.
- `matchings[]` — mỗi cặp một `{left, right}`, theo thứ tự các dòng dưới nhãn `Cặp ghép:`.
- `blanks[]` — mỗi ô `[k]` của tài liệu là **một `{{blank}}` trong `content`** và một phần tử `blanks[]`, cùng thứ tự.

Script tự đánh `answer_position`. **Đừng khai tay.**

> ⚠️ **Ô trống viết là `{{blank}}`, không tự gõ thẻ `<span>`.** Script sinh UUID v4 chữ thường rồi kiểm lại — backend chỉ đếm ô trống có UUID đúng dạng đó. Với `Drag & Drop`, đếm được 0 ô thì server vẫn trả `201` nhưng ép **toàn bộ đáp án thành sai**, không báo lỗi gì.

**Hình dạng đầy đủ của từng loại, kèm ràng buộc và bẫy: `references/question-types.md`.** Đọc trước khi soạn câu đầu tiên của loại chưa từng dùng trong lượt này.

Bài test tài liệu không viết câu nào thì **bỏ qua 7.1** cho bài đó.

### 7.2 Tạo bài test, nối câu hỏi và setting

```bash
# Test cấp khóa
scripts/course/create-course-test.sh --type <MID_TERM_TEST|FINAL_TEST> \
  --name "<Name:>" \
  --questions <course-slug>/work/questions-final.json \
  --question-type      "<Type of Test:>" \
  --test-mode          "<Test Mode:>" \
  --graded             "<Graded Assignment:>" \
  --pass-point         "<Pass Point:>" \
  --grading-preference "<Grading Preference:>" \
  --attempt            "<Attempt:>" \
  --state <course-slug>/work/state.json --dry-run

# Section Test của Section N — script đọc SECTION_ID từ state key `section:N`
scripts/course/create-course-test.sh --type SECTION_TEST --section <N> \
  --name "<Name:>" --questions <course-slug>/work/questions-section-1.json \
  --state <course-slug>/work/state.json --dry-run

# Document QUIZ trong Tab — --activity và --tab-index đếm TỪ 0
scripts/course/create-tab-quiz.sh --section <N> --activity <A> --tab-index <T> \
  --questions <course-slug>/work/questions-tab-1-0-0.json \
  --state <course-slug>/work/state.json --dry-run
```

`--questions` trỏ tới **chính file đã dùng ở 7.1**. Script đọc `.test` trong file rồi lấy id từ state key `q:<test>:<n>`, xếp theo số câu tăng dần, và dựng:

```json
"quiz_questions": [
  {"question_id": "ebe7be4d-…", "setting_grade": 50},
  {"question_id": "25e94162-…", "setting_grade": 50}
]
```

> ⚠️ **`setting_grade` chia ĐỀU — mọi câu cùng một số**, là `100 / số câu` giữ thập phân và làm tròn **xuống** 2 chữ số: 3 câu → `33.33` mỗi câu, 7 câu → `14.28`, 8 câu → `12.5`. Tròn xuống là bắt buộc để tổng không vượt 100 (`14.29 × 7 = 100.03`). **Không dồn phần dư vào câu đầu.**
>
> Muốn điểm khác nhau thì khai `"grade": <số>` cho **mọi** câu trong file 7.1, chấp nhận thập phân. Script chặn nếu tổng vượt 100, cảnh báo nếu tổng thiếu.

Thiếu id nào là script **dừng** — dấu hiệu 7.1 chưa chạy xong.

Cờ setting nào tài liệu không khai thì **bỏ hẳn cờ đó**, script giữ `QUIZ_CFG`. Đừng truyền giá trị bịa. Bảng quy đổi sáu nhãn: `references/lark-source.md`, mục *Setting bài test*.

Bài test không có câu hỏi → bỏ `--questions`, bài tạo rỗng. Đó là trạng thái hợp lệ.

### Bốn điều bắt buộc

1. **`--dry-run` trước** rồi mới chạy thật, cho cả 7.1 lẫn 7.2.
2. **Luôn truyền `--state <course-slug>/work/state.json`.** Bỏ trống là script lấy `./state.json` ở gốc dự án — state rỗng, và mọi thứ bị tạo lần thứ hai.
3. **Đáp án phải khớp `qtype`** — mỗi loại một bộ ràng buộc riêng (`ONE_CHOICE` đúng 1 đáp án đúng · `MATCHING` từ 2 cặp · `DRAG_DROP` mỗi ô đúng 1 đáp án và phải có nhiễu chung…). Bảng đầy đủ: `references/question-types.md`. Sai thì script dừng trước khi gọi API.
4. **Không tự viết câu hỏi, không thêm đáp án nhiễu cho đủ.** Tài liệu khai bao nhiêu tạo bấy nhiêu.

> 🚫 **Câu hỏi và bài test tạo rồi không xóa được bằng bộ script này.** Sai thì người dùng phải vào giao diện dọn tay — `--dry-run` là lần cuối chặn được.

## Báo cáo kết thúc

Xong bước 7 thì báo người dùng, gọn trong một tin nhắn:

1. **Đã tạo gì** — số Section / Activity / Tab / Document, từng bài test kèm **số câu hỏi đã tạo**.
2. **Mọi dòng `⚠️` của read-back**, nêu đúng bài test nào và bảo họ mở LMS đối chiếu.
3. **Thiếu gì so với tài liệu** — Activity không có media vì file bị bỏ qua và mục *Sai lệch* nào họ chưa quyết. Bài test mà **tài liệu không viết câu nào** thì tạo rỗng là đúng, không phải thiếu — nói rõ để người dùng tự nhập trên giao diện nếu muốn.
4. **Link khóa học** trên LMS nếu có, và nhắc khóa đang ở `status: DRAFT`.

> 🚫 **Không xóa `<course-slug>/` và không đề nghị xóa.** `state.json` là thứ duy nhất ngăn lần chạy sau dựng trùng cả cây — mà skill **không xóa được gì trên LMS**, kể cả câu hỏi đã tạo. Người dùng còn phải kiểm lại trên giao diện.
>
> Chỉ khi họ **chủ động hỏi cách dọn** thì nói: kiểm xong hết rồi thì xóa **cả thư mục**, đừng xóa lẻ từng file. Muốn nhẹ máy sớm thì xóa riêng `assets/` được — id media đã nằm trong `media-manifest.json`.

## Quy tắc cứng chung

1. **Tài liệu Lark là nguồn duy nhất.** Mọi chữ trong `outline.md` và mọi nội dung tạo lên LMS phải truy được về một block trong tài liệu. Không suy diễn, không "làm mượt", không dịch, không bù chỗ thiếu.
2. **Số đếm cấu trúc tài liệu tự khai là tuyên bố, không phải nội dung.** "07 Section — 19 Activity" ở đầu file chỉ là chữ; đếm Section/Activity/câu hỏi thực tế từ block list.
3. **Không call API tạo trước khi `outline.md` được người dùng duyệt.**
4. Không in token ra output, không ghi token vào file trong project. Không bao giờ nhận mật khẩu qua khung chat.
5. **Chỉ chạm vào API UpBase qua script trong `scripts/`.** Không tự gõ `curl` vào endpoint UpBase, không tự `source lib.sh`. Lark là ngoại lệ có chủ đích — đi qua tool `mcp__lark__*`, còn tải media đi qua `scripts/media/download.sh`.
6. **Thiếu thông tin phiên thì hỏi một lần cho đủ.** Không đoán, không dùng lại giá trị của lần trước.
7. **Soạn xong toàn bộ nội dung rồi mới gọi API.** Không lưu nội dung placeholder.
8. **Chỉ tạo, không xóa.** Cần gỡ bỏ thì đưa người dùng danh sách id trong state file để họ tự xử lý.
9. **Không chia phiên theo token.** Chốt bao nhiêu thì soạn đủ bấy nhiêu rồi chạy hết một lượt; không ước lượng token đủ hay thiếu, không báo người dùng số phiên cần chạy. Hết hạn giữa chừng thì script dừng ở `401` — nhờ người dùng chạy `scripts/login.sh` rồi lặp lại **đúng lệnh cũ**, state giữ tiến độ nên phần đã xong không bị tạo lại.
10. **Làm đúng phạm vi được giao, không tự thêm bước.** Chỉ chạy các lệnh nêu trong tài liệu. Không tự khảo sát, thống kê, đối chiếu hay "kiểm tra cho chắc" ngoài phạm vi — kể cả khi thấy có ích. Muốn làm thêm thì hỏi trước.

## Bản đồ tài liệu

| File | Nội dung |
|---|---|
| `references/lark-source.md` | bảng `block_type`, quy tắc bóc cấu trúc, tải media, quy ước đặt tên |
| `references/outline-format.md` | đặc tả từng mục của `outline.md` |
| `references/upload-media.md` | bước 5: tạo khóa học, bốn call upload, `resource_id` vs `quiz_id` |
| `references/create-structure.md` | dựng Section / Unit / LO / Activity / Tab / Document — schema, endpoint, state |
| `references/quality-structure.md` | chuẩn chia Activity / Tab / Document, khung HTML |
| `references/api.md` | header, phân trang, mã xác thực, bẫy phiên dùng chung |
| `scripts/config.sh` | **mọi hằng số**: base URL, mặc định khóa học, timeout, phân trang |


## Môi trường

Cần `bash`, `curl`, `jq`, `openssl`, `node`; Windows dùng Git Bash hoặc WSL. `lsof` là tùy chọn. Hướng dẫn cho người vận hành: `README.md`.

Hai hệ xác thực **tách rời nhau, không thay thế nhau**:

| | Lark (bước 0) | UpBase (bước 4) |
|---|---|---|
| Cách vào | OAuth qua browser, link 60s | `login.sh --gui`, hộp thoại nhập tay |
| Token nằm ở | RAM tiến trình `lark-mcp` | `$UPBASE_ENV_FILE` |
| Mất khi | tiến trình `lark-mcp` restart | hết hạn theo realm Keycloak, hoặc `$TMPDIR` bị dọn sau reboot |
| Ai kiểm | gọi thật `drive_v1_file_list` | không kiểm — `login.sh --gui` mỗi lượt |

Token UpBase mặc định ở `$TMPDIR/upbase-session-<env>.env` (`chmod 600`), **một file cho mỗi môi trường**. Muốn sống qua reboot: `export UPBASE_ENV_FILE="$HOME/.upbase-session-$UPBASE_ENV.env"` — giữ `$UPBASE_ENV` trong tên, bỏ ra là hai môi trường đè nhau.
