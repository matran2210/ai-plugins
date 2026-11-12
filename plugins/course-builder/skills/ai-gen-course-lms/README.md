# ai-gen-course-lms

Dựng khóa học trên UpBase LMS **từ một tài liệu thiết kế trên Lark**. Bạn đưa link, skill đọc tài liệu, tải ảnh/video về máy, xuất `outline.md` cho bạn duyệt, rồi mới tạo trên LMS.

Một luồng duy nhất. Skill **không tạo Question Topic** — câu hỏi tạo thẳng vào ngân hàng câu hỏi của khóa. Bài test nào tài liệu không viết câu nào thì để khung rỗng.

```text
bước 0  đăng nhập Lark        ← bạn bấm link
bước 1  đọc tài liệu
bước 2  tải ảnh/video về project
bước 3  xuất outline.md       ← BẠN DUYỆT, skill dừng ở đây
bước 4  đăng nhập OPS         ← bạn nhập vào hộp thoại
bước 5  tạo khóa học + ảnh bìa + upload ảnh/video + tài liệu khóa
bước 6  dựng cấu trúc khóa học        (chưa tạo bài test)
bước 7  tạo câu hỏi rồi tạo Quiz/Section/Mid/Final Test
```

Thứ tự không đảo được: **upload media trước khi dựng bài học** vì ảnh nhúng thẳng vào nội dung, mà nội dung đã tạo thì không sửa được.

**Skill không tự nghĩ nội dung.** Tài liệu Lark quyết định cấu trúc, tên và vị trí bài test, và cả nội dung câu hỏi — tài liệu viết bao nhiêu câu thì tạo bấy nhiêu, không tự nghĩ thêm câu nào, không tự thêm đáp án nhiễu cho đủ.

Chỉ tạo, không sửa, không xóa. Tạo trùng thì skill không dọn được — phải nhờ người có quyền xóa trong UpBase.

Mọi thứ skill sinh ra nằm gọn trong **một thư mục mang tên khóa học**, ngay trong dự án của bạn:

```text
<dự án>/planning-e2e/
├── outline.md     ← thứ duy nhất bạn cần mở
├── assets/        ảnh, video, handout tải từ Lark
└── work/          file làm việc của skill — state, plan, batch, ids
```

Dựng khóa thứ hai là thư mục mới, không đụng gì tới khóa cũ.

**Đừng xoá `work/` khi chưa kiểm xong khóa học trên LMS** — `state.json` trong đó là thứ duy nhất ngăn lần chạy sau dựng trùng cả cây, mà skill không xoá được gì trên LMS. Kiểm xong hết rồi thì xoá cả thư mục khóa. Muốn nhẹ máy sớm thì xoá riêng `assets/` được, id media đã nằm trong `work/media-manifest.json`.

**Môi trường mặc định là STAGING.** Base URL và mọi hằng số khác nằm ở `scripts/config.sh` — xem mục [Hằng số và đổi môi trường](#hằng-số-và-đổi-môi-trường).

---

## Ai chạy cái gì

Hầu hết lệnh trong tài liệu này **không dành cho bạn**. Việc của bạn chỉ có ba: bấm link Lark, duyệt `outline.md`, nhập mật khẩu OPS vào hộp thoại.

| | Bạn làm | Claude làm |
|---|---|---|
| đăng nhập Lark trên browser | ✅ bấm vào link Claude mở ra | ❌ không đăng nhập thay bạn |
| duyệt `outline.md` | ✅ **bắt buộc** — không duyệt thì không tạo gì | ❌ không tự duyệt hộ |
| `scripts/login.sh` | được, khi muốn tự đăng nhập | ❌ không bao giờ |
| `scripts/login.sh --gui` | không cần | ✅ ở bước 4, **mỗi lượt** |
| cấu hình kết nối Lark (`.mcp.json`, `scripts/lark-setup.sh`) | ✅ **tự làm thủ công**, xem [Cài đặt](#cài-đặt) | ❌ không bao giờ |
| `scripts/media/download.sh` | chỉ khi gỡ lỗi | ✅ ở bước 2 |
| `scripts/*/start.sh` | chỉ khi gỡ lỗi | ✅ |
| `scripts/course/build-section.sh` | ⚠️ xem cảnh báo ở [Tham chiếu lệnh](#tham-chiếu-lệnh) | ✅ |
| `scripts/course/create-course-test.sh` | ⚠️ như trên | ✅ |

Bạn không phải tự gõ lệnh đăng nhập OPS: khi thấy chưa có token, Claude tự chạy `login.sh --gui` và **hộp thoại hiện lên trên màn hình bạn** — cứ nhập vào đó.

Mật khẩu vẫn không đi qua Claude. Hộp thoại là một cửa sổ riêng của hệ điều hành; giá trị bạn nhập đi thẳng vào tiến trình script, và script không bao giờ in nó ra. Claude chỉ thấy tên đăng nhập và hạn token. Cờ `--gui` chặn hẳn nhánh nhập-qua-terminal, nên không tồn tại đường nào để mật khẩu chảy qua stream mà Claude đọc được.

**Đừng bao giờ gõ mật khẩu vào khung chat** — ở đó thì nó nằm vĩnh viễn trong transcript và log phiên.

---

## Bước 0 — đăng nhập Lark

Việc của bạn: **bấm vào tab browser mà Claude mở ra và đăng nhập Lark**. Link đó **chỉ sống 60 giây**, nên khi Claude báo "đang mở link" thì ngồi sẵn ở browser.

- Claude tự phát hiện token hết hạn, tự mở link, tự chờ callback, tự kiểm lại. Bạn không gõ lệnh nào.
- Bấm không kịp 60 giây cũng không sao, Claude mở link mới. Nhưng quá ba lần liên tiếp là nó dừng và báo bạn.
- Token Lark nằm trong RAM của tiến trình MCP, **không lưu ra file**. Khởi động lại Claude Code là phải đăng nhập lại — chuyện bình thường, không phải lỗi.
- Đọc được tài liệu rồi Claude mới đi tiếp. Chưa đọc được nguồn thì nó không làm gì khác, vì mọi thứ nằm trong tài liệu đó.

### Đọc được gì, không đọc được gì

| Đọc được | Không đọc được |
|---|---|
| tài liệu `docx`, trang `wiki` | **Sheet nhúng** trong tài liệu |
| video, pdf, tệp đính kèm | **Base (bitable)** nhúng |
| ảnh | Mindnote, Slides |

Bảng tổng quan trong tài liệu thường là **Sheet nhúng** — Claude sẽ nói rõ là không đọc được và ghi vào mục *Sai lệch*. Muốn nội dung đó vào khóa học thì bạn copy nó ra dạng text trong tài liệu.

### Cần bật tool tải media

Bước 2 cần tool `drive.v1.media.batchGetTmpDownloadUrl` trong cấu hình MCP của server `lark` (`.mcp.json`, danh sách sau cờ `-t`). Thiếu nó thì Claude dừng ở bước 2 và nhắc bạn.

Sau khi thêm vào `.mcp.json`: **khởi động lại Claude Code**, rồi **đăng nhập Lark lại** (token nằm trong RAM tiến trình cũ nên restart là mất).

---

## Bước 3 — duyệt `outline.md`

Đây là cửa chặn quan trọng nhất. Claude ghi `<tên-khóa>/outline.md` rồi **dừng hẳn** và chờ bạn.

File có bảy mục; ba mục bạn cần đọc kỹ:

| Mục | Đọc để làm gì |
|---|---|
| **3. Cây sẽ tạo trên LMS** | soát tên Section, tên Activity, Learning Outcome. Sai ở đây là sai cả khóa |
| **6. Sai lệch và thiếu hụt** | những chỗ tài liệu tự mâu thuẫn, bị cắt giữa chữ, hoặc không đọc được |
| **7. Sẽ tạo mới trên LMS** | tên khóa học và tên các khung bài test rỗng sắp được tạo. Soát tên ở đây — tạo rồi thì skill không xóa được |

Sửa gì thì **sửa thẳng vào `outline.md`** rồi bảo Claude đọc lại. Đừng sửa bằng cách nhắn trong chat — file mới là thứ bước 6 trở đi đọc.

Khóa học **do skill tự tạo ở bước 5**, ở trạng thái `DRAFT`. Bạn không phải tạo trước.

### Media đi đường nào

Bước 2 tải video/ảnh về `<tên-khóa>/assets/` và đặt tên lại theo vị trí trong cây (`s01-a02-...mp4` = Section 1, Activity 1.2). Mục 4 của `outline.md` là bảng map đầy đủ.

Lúc bạn duyệt outline thì media **mới chỉ nằm ở máy**. Bước 5 upload lên LMS sau khi bạn duyệt. Chỗ gắn quyết định bằng **nhãn bọc ngoài trong tài liệu**, không phải loại file:

| File nằm dưới nhãn | Lên LMS thành |
|---|---|
| `Video:` trong một Tab | một Document riêng trong Tab đó |
| nội dung một `Text:` | ảnh nhúng thẳng vào bài học đó |
| `Resource:` của Activity | tài liệu đính kèm của chính Activity đó |

Nghĩa là: muốn một file thành **tài liệu đính kèm**, tài liệu Lark phải ghi rõ nó dưới mục `Resource:` của Activity. Ảnh nằm giữa nội dung bài viết thì nó là ảnh của bài viết đó, không thành file đính kèm. Bạn không phải gắn tay gì.

Thứ duy nhất Claude không đưa lên: **file quá lớn** phải upload nhiều phần — bỏ qua và báo bạn, xem [Việc còn thiếu](#việc-còn-thiếu).

---

## Cài đặt

Làm đủ bốn bước dưới đây **trước khi** nhờ Claude việc gì. Thiếu bước 2 thì skill tắc ngay ở bước 0 mà thông báo lỗi không nói được vì sao.

### 1. Cài plugin `course-builder`

Skill này nằm trong plugin `course-builder` của marketplace `lms-plugins` (repo này). Trong Claude Code:

```text
/plugin marketplace add <đường dẫn hoặc git URL của repo>
/plugin install course-builder@lms-plugins
```

Hoặc từ terminal:

```bash
claude plugin marketplace add <đường dẫn hoặc git URL của repo>
claude plugin install course-builder@lms-plugins
```

Khởi động lại Claude Code để nó nhận plugin mới.

Các lệnh chạy tay bên dưới viết `<skill>/scripts/…`, với `<skill>` là thư mục `plugins/course-builder/skills/ai-gen-course-lms` trong bản clone của repo.

### 2. Khai server MCP `lark`

Skill đọc tài liệu Lark qua MCP. Tạo `.mcp.json` ở **gốc thư mục dự án**:

```json
{
  "mcpServers": {
    "lark": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@larksuiteoapi/lark-mcp@0.5.1", "mcp",
        "-a", "${LARK_APP_ID}",
        "-s", "${LARK_APP_SECRET}",
        "-d", "https://open.larksuite.com",
        "--oauth", "--token-mode", "user_access_token",
        "--scope", "docx:document wiki:wiki drive:drive offline_access",
        "-t", "preset.doc.default,docx.v1.document.get,docx.v1.documentBlock.list,docx.v1.documentBlockChildren.get,drive.v1.file.list,drive.v1.media.batchGetTmpDownloadUrl",
        "-l", "en"]
    }
  }
}
```

**`.mcp.json` không chứa secret** — nó chỉ viết `${LARK_APP_ID}` / `${LARK_APP_SECRET}`, Claude Code nội suy lúc khởi chạy MCP server. File này commit được.

- `drive.v1.media.batchGetTmpDownloadUrl` là tool tải media. Thiếu nó thì bước 2 không chạy.
- Vào `https://open.larksuite.com/app/<app_id>/safe` khai redirect URL `http://localhost:3000/callback`, nếu không thì đăng nhập Lark sẽ báo lỗi `redirect_uri`.

### 2b. Khai App ID và App Secret vào máy bạn

```bash
<skill>/scripts/lark-setup.sh
```

Hộp thoại hiện lên, nhập App ID (dạng `cli_…`) và App Secret của app Lark tổ chức bạn. Script ghi vào khối `env` của `~/.claude/settings.json` và `chmod 600`.

Claude Code nạp khối `env` đó vào môi trường **trước khi** khởi chạy MCP server, và nó **ưu tiên cao hơn** biến shell. Muốn dùng shell profile thay thế cũng được — export `LARK_APP_ID` và `LARK_APP_SECRET` trước khi mở Claude Code.

Kiểm tra đã khai chưa (không in ra secret, chỉ 4 ký tự đầu):

```bash
<skill>/scripts/lark-setup.sh --check
```

> ⚠️ Secret lưu **plaintext** trong `settings.json`, giống mọi biến môi trường khác. **Đừng commit file đó.** Cần chặt hơn thì để secret trong macOS Keychain rồi export ra biến trong shell profile.

**Khởi động lại Claude Code** sau khi khai — tiến trình MCP đang chạy vẫn giữ môi trường cũ.

### 3. Cài dependency

Bắt buộc: `bash`, `curl`, `jq`, `openssl`, `node` (để `npx` chạy lark-mcp).
Tùy chọn: `lsof` — có thì Claude biết chính xác lúc nào bạn đăng nhập Lark xong, không có thì nó chờ cứng 45 giây.

| Hệ | Cách chạy |
|---|---|
| macOS | Terminal có sẵn. `brew install jq node`; `lsof` có sẵn |
| Windows | **Git Bash** hoặc **WSL** — không dùng CMD hay PowerShell trực tiếp. Git Bash không có `lsof`, vẫn chạy được |
| Linux | `apt install jq lsof nodejs` hoặc tương đương |

Trên máy không phải macOS, Claude không tự mở được browser — nó in link Lark ra cho bạn tự mở.

### 4. Tài khoản UpBase OPS

Dùng tài khoản OPS của bạn, cần quyền tạo course section và question.

Thiếu quyền thì đăng nhập vẫn được nhưng script dừng ở `403` lúc tạo — đăng nhập lại không giúp gì, phải xin thêm quyền.

### Kiểm tra nhanh đã sẵn sàng chưa

```bash
for c in bash curl jq openssl node; do command -v $c >/dev/null && echo "OK    $c" || echo "THIẾU $c  (bắt buộc)"; done
command -v lsof >/dev/null && echo "OK    lsof" || echo "thiếu lsof (tùy chọn, vẫn chạy được)"
claude mcp list | grep lark
```

---

## Đăng nhập OPS

Cách thường dùng: **không làm gì cả.** Claude tự phát hiện chưa có token ở bước 4 và mở hộp thoại.

Muốn chủ động đăng nhập trước:

```bash
<skill>/scripts/login.sh
```

Chạy từ **thư mục dự án**, đừng `cd` vào thư mục skill — mọi file dữ liệu nằm trong `<tên-khóa>/` của dự án, không nằm trong gói skill.

Hộp thoại tiêu đề **OPS Staging** hiện lên, nhập tên đăng nhập và mật khẩu:

- **macOS** — hai hộp thoại liên tiếp, ô mật khẩu ẩn ký tự
- **Windows** — một cửa sổ credential của Windows, cả hai trường trong cùng cửa sổ
- **Không có GUI** — nhập ngay tại terminal, ký tự mật khẩu không hiện

Thành công thì in `=== ĐÃ ĐĂNG NHẬP ===` kèm hạn dùng của token.

Không có gì được nhớ giữa các lần chạy: mỗi lần đăng nhập đều hỏi lại cả môi trường, tên và mật khẩu, nên đổi tài khoản hay đổi môi trường chỉ việc chạy lại lệnh trên.

**Script luôn đăng nhập lại.** Nó không kiểm token cũ còn hạn hay không và không có nhánh nào thoát sớm — đó là lý do panel chọn môi trường luôn hiện. Hạn token do realm Keycloak quyết định chứ không còn là con số cố định, nên kiểm ở phía client là kiểm một thứ không đáng tin.

---

## Skill tự tạo những gì

Bạn **không phải đưa id nào**. Skill tự tạo và tự nhớ:

| Đối tượng | Khi nào | Đặt tên theo |
|---|---|---|
| Khóa học | bước 5 | tên khóa trong tài liệu Lark. `status: DRAFT`, category lấy phần tử đầu danh sách, các thiết lập điểm để mặc định |
| Ảnh bìa khóa | bước 5 | ảnh dưới nhãn `Thumbnail:`. Không có nhãn thì khóa không có ảnh bìa |
| Tài liệu của khóa | bước 5 | file dưới nhãn `Course Resource:`, đính vào cả khóa |
| Câu hỏi | bước 7 | nội dung, loại và đáp án theo từng mục `Câu <n>.` trong tài liệu |
| Bài test | bước 7 | tên, loại và vị trí theo từng mục bài test trong tài liệu; câu hỏi nối vào lúc tạo |

Mục 7 của `outline.md` liệt kê sẵn những thứ này **trước khi** tạo — đó là lần cuối bạn chặn được một cái tên sai, vì khóa học và bài test đã tạo thì skill **không xóa được**.

Khóa tạo ra ở trạng thái **DRAFT** với thiết lập điểm mặc định (`pass_point: 65`, `final_test_points: 80`…). Tinh chỉnh sau trên giao diện.

---

## Dùng skill

Chỉ cần đưa link tài liệu Lark:

```
Dựng khóa học từ tài liệu này: <dán link Lark của bạn>
```

Không có link thì skill dừng và hỏi. Nó **không** tự nghĩ chủ đề khóa học.

---

## Tham chiếu lệnh

Bình thường Claude gọi những lệnh này. Bảng dưới dành cho lúc bạn cần chạy tay để gỡ lỗi.

**Thứ tự bắt buộc.** `login.sh` chỉ ghi token và base URL. `topic_id` / `course_id` do `start.sh` ghi. Nên ba script tạo dữ liệu **phải có `start.sh` tương ứng chạy trước**, nếu không chúng dừng ngay với `chưa có UPBASE_COURSE_ID — chạy scripts/<nhánh>/start.sh trước`.

```
login.sh  ─▶  start.sh  ─▶  script tạo dữ liệu
 (token)      (topic_id/course_id)
```

Cờ nào thiếu giá trị thì script báo `ERROR: --<cờ> cần một giá trị` và thoát.

### Chung

| Lệnh | Việc |
|---|---|
| `scripts/login.sh` | Đăng nhập, ghi session |
| `scripts/login.sh --username <tên>` | Điền sẵn ô tên cho lần chạy đó |
| `scripts/<bất kỳ>.sh --help` | In hướng dẫn của chính script đó |

### Bước 2 — tải media

```bash
scripts/media/download.sh '<url_tạm>' 'assets/<khóa>/<tên>.mp4'
```

Không cần token OPS — URL tạm do Lark ký sẵn. In `OK <byte> <đường dẫn>`, hoặc `SKIP` nếu file đã có và không rỗng nên chạy lại không tải lại. URL tạm có hạn; hết hạn thì Lark trả về **trang HTML kèm mã 200** chứ không trả mã lỗi, nên script chặn theo `Content-Type` và báo `server trả HTML`.

### Bước 5 — tạo khóa học, ảnh bìa, media và tài liệu khóa

```bash
scripts/course/create-course.sh --name "<Name:>" --description "<html>" \
                                [--category "<Course Category:>"] [--type "<Type:>"] \
                                [--pass-point <N>] [--setting '<JSON>'] \
                                [--state FILE] [--dry-run]
scripts/course/start.sh --course <COURSE_ID vừa in ra>
scripts/course/upload-course-image.sh --image <ảnh thumbnail> [--course <id>] \
                                      [--state FILE] [--dry-run]
scripts/course/upload-media.sh <file> [--display-name "<tên>"] [--manifest FILE] [--dry-run]
scripts/course/add-course-resource.sh <file> [<file> …] [--manifest FILE] \
                                      [--course <id>] [--state FILE] [--dry-run]
```

`create-course.sh` lấy sáu giá trị từ vùng *Thông tin khóa học* của tài liệu Lark; `--category` **search theo tên** qua `GET /course_categories?name=…` rồi lấy phần tử hợp lý nhất (khớp chính xác → tên category nằm trong giá trị tài liệu → ngược lại → phần tử đầu kết quả search); search rỗng thì khớp lại trên nguyên danh sách, vẫn không khớp thì dừng. Cờ nào bỏ trống thì dùng fallback trong `config.sh` và in cảnh báo. Không truyền `code` vì BE tự sinh. In dòng cuối `COURSE_ID=<uuid>`. Key state `course:<tên>` nên chạy lại in `SKIP` — **khóa học không xóa được**, đừng đổi `--state` giữa chừng.

`upload-course-image.sh` đặt **ảnh bìa** từ nhãn `Thumbnail:` của tài liệu, qua `PUT /courses/image` dạng multipart. Đây là endpoint riêng: không presigned S3, không sinh `resource_id`, và là thứ duy nhất ở bước 5 **đặt lại được** bất cứ lúc nào. Đừng đẩy ảnh bìa qua `upload-media.sh` — lên hai lần là thừa một resource không ai trỏ tới.

`upload-media.sh` làm bốn call một mạch cho mỗi file: lấy folder khóa → xin `file_key` + presigned URL → `PUT` lên S3 → tạo resource. Kết quả ghi vào `media-manifest.json` (mặc định `./media-manifest.json`), khoá theo đường dẫn file — file đã có thì in `SKIP`, chạy lại cả bước an toàn.

**Một khóa học một manifest.** Đổi `--manifest` sang file khác là upload lại và tạo resource trùng, mà skill không xóa được resource.

Video lấy `quiz_id`, ảnh lấy `resource_id` — hai trường khác nhau trong cùng response, dùng lẫn là video không phát được mà vẫn báo thành công.

`add-course-resource.sh` đính file của nhãn **`Course Resource:`** vào **cả khóa**, qua `POST /courses/<id>/add-resource`. Đây là call thứ năm nối sau bốn call upload, nên file phải đã lên ở lệnh trên. Nhận đường dẫn file chứ không nhận `resource_id` — id tra từ manifest. **Mọi file trong một call, và chỉ gọi một lần** cho mỗi khóa; chưa rõ gọi lần hai thì server cộng thêm hay thay thế, nên liệt kê đủ ngay lần đầu.

> `Course Resource:` khác `Resource:`. Cái đầu đính vào cả khóa ở bước 5; cái sau đính vào một Activity và gắn ở bước 6.

**File quá lớn thì script bỏ qua và đi tiếp**, không dừng cả luồng. Nó in `SKIP` kèm dung lượng, ghi nhận vào manifest để lần sau không thử lại, và cuối cùng báo bạn Activity nào thiếu media kèm đường dẫn file ở `assets/` để bạn tự upload trên giao diện.

### Bước 6 — dựng cấu trúc (chưa tạo bài test)

```bash
scripts/course/start.sh --course <uuid>
scripts/course/build-section.sh <plan.json> [--state FILE] [--dry-run]
```

### Bước 7 — tạo câu hỏi rồi tạo bài test

**Câu hỏi trước, bài test sau.** Bài test tham chiếu id câu hỏi qua `quiz_questions[]` **lúc tạo**; không có endpoint gắn câu hỏi vào bài đã tạo.

```bash
scripts/course/create-question.sh <questions.json> [--state FILE] [--dry-run]

scripts/course/create-course-test.sh --type SECTION_TEST --section <N> --name "<tên>" \
                                     [--questions <questions.json>] [--state FILE] [--dry-run]
scripts/course/create-course-test.sh --type MID_TERM_TEST|FINAL_TEST --name "<tên>" \
                                     [--questions <questions.json>] [--state FILE] [--dry-run]
```

`create-question.sh` nhận **bảy loại câu hỏi** — `One Choice` · `Multiple Choice` · `True / False` · `Matching` · `Select Word` · `Fill Word` · `Drag & Drop`. Mỗi loại một bộ ràng buộc riêng, kiểm hết trước khi gọi API; hình dạng file JSON ở `references/question-types.md`.

Bỏ `--questions` thì bài test tạo rỗng — đúng với bài mà tài liệu không viết câu nào.

`SECTION_TEST` đọc `SECTION_ID` từ state key `section:<N>`, nên `--state` phải trỏ đúng state file mà bước 6 đã ghi.

`setting_grade` chia đều cho mọi câu: `100 / số câu`, làm tròn **xuống** 2 chữ số để tổng không vượt 100. Muốn điểm khác nhau thì khai `"grade"` cho **mọi** câu trong file JSON.

Document QUIZ nằm trong Tab dùng script riêng, vì endpoint khác và `quiz_questions` nằm trong `payload`:

```bash
scripts/course/create-tab-quiz.sh --tab <TAB_ID> [--state FILE] [--dry-run]
scripts/course/create-tab-quiz.sh \
       --section <N> --activity <A> --tab-index <T> [--state FILE] [--dry-run]
```

`--activity` và `--tab-index` **đếm từ 0**, đúng như key `tab:N:a:t` mà `build-section.sh` ghi. Script này cũng nhận `--questions`.

> ⚠️ **`--state` của `create-course-test.sh` là bẫy tạo trùng.** Mặc định của nó là `./state.json` **theo thư mục bạn đang đứng** — khác `build-section.sh`, script này lấy `state.json` theo thư mục của file plan. Chạy tay từ thư mục khác mà không truyền `--state` trỏ đúng state file skill đã dùng thì nó thấy state rỗng và **tạo bài test lần thứ hai**.

### Chạy thử trước khi tạo thật

`--dry-run` validate và không gửi gì lên server. Luồng này dùng nó ở `build-section.sh`, `create-course-test.sh`, `create-tab-quiz.sh` và `upload-media.sh` trước khi tạo thật.

---

## Phiên và token

Hai hệ xác thực tách rời nhau:

| | Lark | UpBase OPS |
|---|---|---|
| Token nằm ở | RAM tiến trình `lark-mcp` | `$UPBASE_ENV_FILE`, mặc định `$TMPDIR/upbase-session-<env>.env`, `chmod 600` — **tách theo môi trường** |
| Sống bao lâu | tới khi tiến trình restart | theo realm Keycloak — `login.sh` in hạn thật sau khi đăng nhập |
| Đăng nhập lại thế nào | bấm link browser | hộp thoại `login.sh` |

Mật khẩu và tên đăng nhập OPS **không lưu ở đâu cả**.

Token OPS sống qua cả lúc khởi động lại máy (`$TMPDIR` bị dọn khi reboot):

```bash
export UPBASE_ENV_FILE="$HOME/.upbase-session-$UPBASE_ENV.env"
```

Kết thúc phiên — lệnh này tôn trọng `$UPBASE_ENV_FILE` nếu bạn đã đặt:

```bash
rm -f "${UPBASE_ENV_FILE:-${TMPDIR:-/tmp}/upbase-session-${UPBASE_ENV:-staging}.env}"
```

## Hằng số và đổi môi trường

**Mọi hằng số nằm ở `scripts/config.sh`** — một file duy nhất. Không giá trị nào bị hardcode rải rác trong script nữa.

Mỗi biến theo dạng `${VAR:-mặc định}`, nên có hai cách đổi: sửa file (đổi vĩnh viễn), hoặc export biến cùng tên (đổi cho một lần chạy).

| Nhóm | Biến | Mặc định |
|---|---|---|
| Môi trường | `UPBASE_BASE_URL_STAGING` · `UPBASE_BASE_URL_PROD` | staging · prod |
| | `UPBASE_ENV` | `staging` (hoặc `prod`) |
| | `UPBASE_ENV_FILE` | `$TMPDIR/upbase-session-<env>.env` |
| Tạo khóa học | `COURSE_STATUS` · `COURSE_TYPE` | `DRAFT` · `NORMAL_COURSE` |
| | `COURSE_PASS_POINT` · `COURSE_TEMPLATE` | `65` · `3` |
| | `COURSE_SETTING` | JSON điểm mặc định |
| Cấu trúc | `UNIT_NAME` · `UNIT_POSITION` | `Learning activity` · `1` |
| | `ACTIVITY_DEFAULT_DURATION` | `30` phút |
| | `IMAGE_DEFAULT_WIDTH` | `200` |
| Phân trang | `PAGE_SIZE_COURSES` · `PAGE_SIZE_CATEGORIES` | `100` · `50` |
| Mạng | `UPLOAD_*` · `DOWNLOAD_*` timeout/retry | xem file |

`QUIZ_CFG` — cấu hình chung của bốn loại bài test — nằm riêng ở `scripts/course/quiz-config.sh`, cạnh hàm dùng nó.

### Hai môi trường OPS

Mỗi môi trường có **hai** host: API và đăng nhập.

| `UPBASE_ENV` | Base URL (API) | Đăng nhập (Keycloak) |
|---|---|---|
| `staging` (mặc định) | `https://uplms-api.staging.upbase.asia/ops/api/v1` | `https://accounts.staging.upbase.asia/realms/lms/…/token` |
| `prod` | `https://uplms-api.upbase.asia/ops/api/v1` | `https://accounts.upbase.asia/realms/lms/…/token` |

Ngoài base URL thì endpoint, payload và mã lỗi y hệt nhau.

Đăng nhập dùng OAuth2 password grant với client `ops-frontend` (public, không có secret). Đổi client bằng `export UPBASE_AUTH_CLIENT_ID=…`.

> ⚠️ Client phải được **bật “Direct access grants”** trong Keycloak thì mới đăng nhập bằng script được. Chưa bật thì `login.sh` dừng với thông báo `unauthorized_client` và nói rõ phải nhờ quản trị Keycloak.

`scripts/login.sh` mở **panel chọn môi trường trước khi hỏi tên đăng nhập**.

Chỉ định thẳng, không qua panel:

```bash
scripts/login.sh --env prod          # đăng nhập vào prod, bỏ qua panel
UPBASE_ENV=prod scripts/course/start.sh --course <id>   # các lệnh về sau
```

**Token tách theo môi trường.** Mỗi môi trường một session file (`upbase-session-staging.env` / `-prod.env`), và file mang dấu `UPBASE_SESSION_ENV`. Chạy môi trường này mà đọc phải file của môi trường kia thì `lib.sh` **bỏ token** rồi báo — không có đường nào bắn token staging vào prod.

Thứ tự ưu tiên khi phân giải base URL: **biến môi trường → session file → mặc định theo `UPBASE_ENV` trong `config.sh`**.

---

## Gỡ lỗi

### Lark và media

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| Claude báo link Lark hết hạn liên tục | Link sống 60 giây. Mở sẵn browser rồi mới bảo Claude thử lại |
| `claude mcp list` hiện `⏸ Pending approval` cho `lark` | Lần kiểm tra CLI riêng, không chặn phiên đang chạy. Không phải nguyên nhân mất kết nối |
| browser báo lỗi `redirect_uri` | App Lark chưa khai `http://localhost:3000/callback` trong mục security settings |
| Claude nói thiếu tool tải media | Thêm `drive.v1.media.batchGetTmpDownloadUrl` vào `-t` trong `.mcp.json`, restart Claude Code, đăng nhập Lark lại |
| `server trả HTML … không phải media` | URL tạm hết hạn. Claude lấy URL mới rồi tải lại |
| Bảng trong tài liệu ra rỗng | Đó là Sheet nhúng, scope hiện tại không đọc được. Copy nội dung ra text trong tài liệu |
| Khóa tạo ra ít Section hơn tài liệu khai | Đúng thiết kế. Xem mục *Sai lệch* của `outline.md` — tài liệu khai nhiều hơn phần thực sự viết ra |

### OPS

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| `CHƯA CÓ TOKEN` / `TOKEN HẾT HẠN` | Chạy `scripts/login.sh` |
| `=== DỪNG ===` ngay sau khi chạy `start.sh` | Chưa đăng nhập. Chạy `scripts/login.sh` |
| `=== THIẾU n THÔNG TIN — DỪNG, KHÔNG TẠO GÌ ===` | Thiếu tham số bắt buộc hoặc id không có thật. Đọc các dòng `✗` để biết thiếu gì. Chưa tạo gì cả |
| `chưa có UPBASE_COURSE_ID` / `cần UPBASE_TOPIC_ID` | Chưa chạy `start.sh` tương ứng |
| `ERROR: --<cờ> cần một giá trị` | Gõ cờ mà quên giá trị đứng sau |
| `COURSE: id không có thật` hoặc `COURSE: id không có trong danh sách khóa học` | Khâu xác thực chỉ quét 100 khóa mới nhất. Khóa cũ hơn không được thấy dù id đúng |
| `403` khi tạo | Tài khoản thiếu quyền. Đăng nhập lại không giúp — xin thêm quyền |
| Đang chạy giữa chừng thì `401` | Token hết hạn. Chạy lại `scripts/login.sh`, rồi lặp lại **đúng lệnh cũ** — state file giữ tiến độ |
| Vừa đăng nhập xong mà script vẫn bắn vào id cũ | Biến môi trường thắng file session. Kiểm bằng `env \| grep UPBASE_` rồi `unset` cái còn sót |
| Mất token dù chưa hết hạn | Máy đã khởi động lại, `$TMPDIR` bị dọn. Đặt `UPBASE_ENV_FILE` sang `$HOME` để tránh |
| Hộp thoại không hiện trên Windows | Phải chạy trong Git Bash hoặc WSL |
| `thiếu lệnh 'jq'` / `'openssl'` / `'curl'` | Cài dependency còn thiếu |
| Script dừng ở `401` giữa lúc đang tạo | Chạy `scripts/login.sh`, rồi lặp lại **đúng lệnh cũ**. State file giữ tiến độ nên phần đã xong không bị tạo lại |
| Bài test tạo xong có 0 câu hỏi | Tài liệu không viết câu nào cho bài đó, hoặc quên `--questions`. Câu hỏi đã tạo thì chạy lại `create-course-test.sh` **không** gắn thêm được — bài test đã tạo là cố định |
| `create-question.sh` dừng trước khi gọi API | Đáp án không khớp loại câu hỏi. Thông báo lỗi chỉ rõ câu nào sai gì; bảng ràng buộc ở `references/question-types.md` |

---

## Việc còn thiếu

**Không còn việc nào chặn.** Ảnh, video và handout đều lên LMS được; câu hỏi và bài test tạo đủ theo tài liệu.

Một thứ **cố ý không làm**: **file quá lớn** — server trả `MULTI_PART`, phải upload nhiều phần. Claude bỏ qua, ghi nhận vào manifest, rồi báo bạn Activity nào thiếu media để bạn tự upload trên giao diện. Không dừng luồng.

Nguyên tắc khi gặp API chưa có đặc tả: **không đoán payload**. Server này lọc bỏ field sai tên **im lặng** rồi vẫn trả `201`, nên đoán sai không ra lỗi mà ra dữ liệu hỏng — thà dừng và xin bạn curl mẫu. Lấy curl bằng DevTools → tab Network trên giao diện OPS, làm thao tác đó một lần, rồi *Copy as cURL*.

> ⚠️ Trước khi dán curl vào chat, **xóa dòng `-H 'Authorization: Bearer …'`**. Token dán vào chat sẽ nằm vĩnh viễn trong transcript và log phiên. Skill không cần token của bạn — nó tự lấy qua `login.sh`.

---

## Cấu trúc

```
ai-gen-course-lms/
  SKILL.md                     agent đọc: luồng 8 bước (0–7), quy tắc cứng
  README.md                    file này — dành cho người
  scripts/
    config.sh                  ★ MỌI hằng số: base URL, mặc định khóa, timeout
    lark-setup.sh              khai LARK_APP_ID/SECRET vào máy (bạn chạy được)
    login.sh                   đăng nhập OPS (bạn chạy được)
    lib.sh                     session, dependency, HTTP client
    media/download.sh          tải media Lark (không cần token OPS)
    course/                    create-course.sh · start.sh · build-section.sh · upload-media.sh
                               upload-course-image.sh · add-course-resource.sh
                               create-question.sh · create-course-test.sh · create-tab-quiz.sh
                               quiz-config.sh
  references/
    lark-source.md             bảng block_type, bóc cấu trúc, tải media, đặt tên
    outline-format.md          đặc tả 7 mục của outline.md
    create-structure.md        bước 6 — schema plan, endpoint, state
    question-types.md          bước 7 — bảy loại câu hỏi, hình dạng plan, ràng buộc
    quality-structure.md       chuẩn chia Activity / Tab / Document
    api.md                     header, phân trang, bẫy phiên
```

