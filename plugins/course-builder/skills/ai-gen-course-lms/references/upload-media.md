# Bước 5 — tạo khóa học, ảnh bìa, media và tài liệu khóa

Toàn bộ hình dạng request/response dưới đây lấy từ request thật của giao diện OPS.

Điều kiện vào: bước 2 đã tải media về `<course-slug>/assets/`, bước 3 outline đã được duyệt, bước 4 đã có token OPS.

Việc gọi API do `scripts/course/create-course.sh`, `scripts/course/upload-course-image.sh`, `scripts/course/upload-media.sh` và `scripts/course/add-course-resource.sh` lo. Tài liệu này để tra khi script báo lỗi — **đừng tự gõ `curl`** vào các endpoint UpBase.

## 5.1 Tạo khóa học

Khóa học phải có trước, vì thư mục media là **của khóa** (`object_id=<course_id>`).

### Call 1 — danh mục khóa học

```text
GET /course_categories?page_index=1&page_size=50&name=<Course Category:>&dateField=updated_at
```

**Search theo tên** trong `Course Category:` (giá trị được url-encode), rồi thu hẹp bằng **ba mức**, dừng ở mức đầu tiên có kết quả:

1. khớp chính xác — bỏ hoa thường và khoảng trắng thừa;
2. **tên category nằm trong giá trị tài liệu**, dài nhất thắng — tài liệu hay ghi cả cụm dài (`Thương mại điện tử – Vận hành sàn Shopee`) còn category chỉ là `Shopee`;
3. giá trị tài liệu nằm trong tên category.

Search trả rỗng thì script gọi lại **không kèm `name=`** để lấy nguyên danh sách và khớp tại chỗ theo đúng ba mức đó.

Kết thúc ba mức, xử lý theo **số kết quả còn lại**:

| Số kết quả | Làm gì |
|---|---|
| đúng 1 | dùng nó |
| 0 | **dừng**, in danh sách category hiện có |
| **>1** | **dừng**, in các tên khớp — người dùng chọn |
| `--category` không truyền | **dừng**, in danh sách để họ điền vào tài liệu |

> 🚫 **Không có mức "lấy phần tử đầu tiên".** Gắn khóa vào sai category là lỗi im lặng: API trả `201`, khóa vẫn tạo, và không ai biết cho tới khi có người đi tìm nó trên giao diện. Khớp không dứt khoát thì ghi một dòng vào *Sai lệch* của outline và hỏi người dùng.

> ⚠️ Tên mảng trong `.data` **chưa được kiểm chứng** — các endpoint khác không nhất quán (`.data.courses`, `.data.topics`). Script dò mảng đầu tiên trong `.data` có phần tử mang `.id` thay vì đoán một tên rồi hỏng im lặng. Không tìm được thì nó **dừng**.

### Call 2 — tạo khóa

```text
POST /courses
```

```json
{ "name": "<Name:>",
  "description": "<Description: → <p>…</p>>",
  "pass_point": "<Passpoint:>",
  "status": "DRAFT",
  "course_type": "<Type:>",
  "setting": { "progress": "<Tiến độ học:>", "activity_points": 0,
               "chapter_points": "<Section Test:>", "topic_points": 0,
               "mid_term_points": "<Mid Test:>", "final_test_points": "<Final Test:>" },
  "template": 3,
  "course_category_id": "<id search được ở call 1 theo Course Category:>" }
```

**Sáu trường lấy thẳng từ vùng *Thông tin khóa học*** theo luật `Nhãn: giá trị` (`references/lark-source.md`): `Name:`, `Description:`, `Course Category:`, `Type:`, `Passpoint:`, `Điểm thành phần:`. Tài liệu khai gì thì gửi nấy — **giá trị trong tài liệu thắng mặc định trong `config.sh`**.

`activity_points` và `topic_points` không có trong template → giữ `0`. `status` và `template` không do tài liệu quyết. Không truyền `code`; BE tự sinh.

Nhãn nào tài liệu bỏ trống thì script dùng fallback của `config.sh` **và in cảnh báo** — trường hợp đó phải có một dòng trong *Sai lệch* của outline.

`course_id` = `.data.id`. Xong thì chạy `scripts/course/start.sh --course <id>` để xác thực và ghi session.

> 🚫 **Khóa học không xóa được bằng bộ script này.** Key state `course:<tên>` giữ cho chạy lại in `SKIP`. Đổi `--state` giữa chừng là tạo khóa thứ hai trùng tên, và phải nhờ người có quyền xóa dọn tay.

## 5.2 Ảnh bìa khóa học

Ảnh dưới nhãn `Thumbnail:` của tài liệu. **Đường đi hoàn toàn khác 5.3**: không presigned S3, không sinh `resource_id` — file đi thẳng trong body và gắn luôn vào khóa.

```
PUT /courses/image
Content-Type: multipart/form-data; boundary=…      ← curl tự sinh, ĐỪNG tự đặt

  course_id      = <uuid>
  course_image   = @<file>   ; filename + Content-Type theo đuôi file
```

`scripts/course/upload-course-image.sh --image <file>` lo việc này. `course_id` lấy từ `--course`, hoặc từ session do `start.sh` ghi.

| Mã | Nghĩa |
|---|---|
| `200` · `201` · `204` | đặt xong |
| `413` | ảnh quá lớn — giảm kích thước rồi chạy lại |
| `401` | token hết hạn, đăng nhập lại rồi lặp đúng lệnh cũ |

Script chặn trước khi gửi: file không tồn tại, file rỗng, và đuôi file ngoài `.png .jpg .jpeg .gif .webp`. Kiểu MIME suy từ **đuôi file**, không đoán — gửi sai kiểu thì giao diện có thể lưu một file không hiển thị được mà API vẫn trả `200`.

State key `courseimage:<course_id>`, nên chạy lại in `SKIP`.

> 💡 **Khác mọi thứ còn lại của bước 5: ảnh bìa đặt lại được.** Media của Document và Activity phải gắn lúc *tạo* node và không có endpoint sửa; ảnh bìa thì gọi lại lúc nào cũng được. Bỏ sót hay đặt nhầm ảnh đều sửa được, không hỏng vĩnh viễn.
>
> 🚫 **Đừng đẩy ảnh bìa qua 5.3.** Lên hai lần là sinh một resource thừa trong thư mục khóa mà không nhãn nào trỏ tới, và skill không xóa được resource.

## 5.3 Upload media

### Bốn call, không đảo được

Mỗi call cần kết quả của call trước. Chạy một file hết bốn call rồi mới sang file kế.

#### 1. Folder của khóa — get-or-create

```text
GET /resources/upload/folder?type=COURSE&object_id=<course_id>
```

```json
{ "success": true,
  "data": { "id": "6e6c7fa8-…", "name": "course/28793f52-…" } }
```

| Lấy | Dùng làm |
|---|---|
| `.data.id` | `parent_id` ở call 4 |
| `.data.name` | gốc của `location` — **thêm dấu `/` vào cuối**, vì response không có mà call 2 lại cần |

Call này tự tạo folder nếu chưa có, nên gọi lại nhiều lần vô hại. Script cache lại vào khoá `_folder` của manifest để không gọi mỗi file.

**Ảnh của đề bài câu hỏi dùng folder khác** — `upload-media.sh --folder-type QUESTION`:

```text
GET /resources/upload/folder?type=QUESTION
```

Lấy `.data.id` / `.data.name` y hệt như trên; call 2–4 không đổi. Cache ở khoá `_folder_question`, và mỗi dòng manifest ghi `folder_type` (`COURSE` / `QUESTION`) để `create-question.sh` kiểm ảnh đã lên đúng folder.

#### 2. Metadata — `file_key` và presigned URL

```text
GET /resources/pre-upload/metadata
      ?content_type=video%2Fmp4
      &name=sample                 ← basename BỎ đuôi
      &location=course%2F<course_id>%2F   ← có dấu / cuối
      &size=1570024                ← number
      &display_name=sample.mp4     ← basename CÓ đuôi
```

```json
{ "success": true,
  "data": {
    "type": "SINGLE_PART",
    "file_key": "course/28793f52-…/1786637211665_Doan-…-certificate.png",
    "display_name": "Doan-…-certificate.png",
    "exist_type": null,
    "upload_url": "https://lms-staging-….s3.ap-southeast-1.amazonaws.com/…?X-Amz-Signature=…"
  } }

```

- **`file_key` do server sinh**, gồm `location` + `<epoch_ms>_<display_name>`. Call này không có tham số timestamp, nên **không được tự ghép key** — ghép tay là đẩy file lên một đường dẫn khác với đường dẫn đã ký.
- `name` (bỏ đuôi) không ảnh hưởng `file_key`; `file_key` dùng `display_name`.
- `type` trả khác **`SINGLE_PART`** nghĩa là file quá lớn, phải upload nhiều phần. **Luồng đó cố ý không hỗ trợ** — xem mục *File quá lớn* bên dưới.
- `exist_type` chưa rõ nghĩa; mẫu trả `null`. Khác `null` thì script in `⚠️` và vẫn upload tiếp.

#### 3. PUT lên S3

```text
PUT <upload_url>
Body: nguyên bytes của file
```

Ba điều đã đọc được từ chính URL presigned:

| Trong URL | Nghĩa |
|---|---|
| `X-Amz-SignedHeaders=host` | **chỉ `host` được ký** → `Content-Type` không cần khớp, gửi hay không đều được |
| `X-Amz-Content-Sha256=UNSIGNED-PAYLOAD` | không phải tính hash nội dung trước khi gửi |
| `X-Amz-Expires=3600` | URL sống **1 giờ** kể từ call 2 |

> ⚠️ **Không gửi header `Authorization` cho call này.** Auth đã nằm trong query string; thêm `Authorization` vào là S3 báo lỗi. Đây là lý do bước này không đi qua `api()` của `lib.sh`.

`403` ở đây gần như luôn là URL hết hạn hoặc chữ ký sai → chạy lại cả bốn call cho file đó.

#### 4. Tạo resource

```text
POST /resources/upload/add-file-resource
```

```json
{ "files": [ { "name": "sample.mp4",
               "file_key": "course/28793f52-…/1786637661822_sample.mp4",
               "location": "course/28793f52-…/",
               "description": "",
               "size": "1570024",
               "parent_id": "6e6c7fa8-…" } ] }
```

> ⚠️ **`size` ở đây là STRING**, dù ở call 2 nó là number. Gửi đúng như vậy, đừng "sửa cho hợp lý".

`data` trả về là **MẢNG**, mỗi file một phần tử. Hai id cần lấy nằm ở hai trường **khác nhau** trong cùng phần tử:

| Lấy | Trường | Dùng cho |
|---|---|---|
| `resource_id` | `.data[0].id` | **ảnh** |
| `quiz_id` | `.data[0].quiz_id` | **video** |
| loại file | `.data[0].suffix_type` | `VIDEO` / ảnh — để kiểm chéo |

Dùng lẫn hai id là lỗi im lặng: document vẫn `201`, nhưng video không phát được.

Một điểm lạ của response, đã thấy nhưng **không phải lỗi của mình**: `.data[0].location` trả `"Temp/"` và `.data[0].parent.name` trả `"Temp"`, dù `parent_id` gửi lên đúng là id mà call 1 trả về với tên `course/<course_id>`. Cứ truyền `parent_id` qua, đừng cố sửa theo tên.

## 5.4 Tài liệu của khóa — `Course Resource:`

**Call thứ năm, nối sau bốn call của 5.3.** File phải đã có `resource_id` trong manifest.

```text
POST /courses/<course_id>/add-resource
Content-Type: application/json

{ "attachments": [
    { "resource_id": "078ccec4-…", "type": "attached", "dom_id": "", "note": "" }
] }
```

`attachments` là **mảng** — mọi file đi chung một request.

| Trường | Giá trị |
|---|---|
| `resource_id` | `.data[0].id` của call 4 ở 5.3 |
| `type` | `"attached"` — giống `files[]` của Activity |
| `dom_id` · `note` | `""` cả hai. Chưa rõ nghĩa; gửi đúng như giao diện gửi |

`scripts/course/add-course-resource.sh <file> [<file> …] --manifest <file>` lo việc này. Nhận **đường dẫn file**, tra `resource_id` từ manifest — không nhận id trực tiếp, để không bỏ qua lớp kiểm "file này upload chưa".

| Tình huống | Script làm gì |
|---|---|
| file không có trong manifest | **dừng** — chưa chạy 5.3 cho nó |
| file có nhưng `resource_id` rỗng | **dừng** |
| file mang cờ `skipped` (quá lớn) | cảnh báo, đính những file còn lại |
| mọi file đều `skipped` | **dừng** — không còn gì để đính |

> ⚠️ **Gọi đúng MỘT lần cho mỗi khóa.** State key `courseresource:<course_id>`; chạy lại in `SKIP`. Chưa kiểm chứng được gọi lần hai thì server **cộng thêm** hay **thay thế** `attachments`, nên không có cách gửi bổ sung nào an toàn: cộng thêm mà gửi lại cả mảng là nhân đôi, thay thế mà chỉ gửi phần mới là mất phần cũ. Liệt kê đủ mọi file ngay lần đầu.
>
> Phải đính thêm về sau: xoá khoá `courseresource:<course_id>` trong `state.json` rồi chạy lại **với đủ mọi file**.

> 🚫 **Khác `Resource:` của Activity.** Cái đó gắn qua `files[]` lúc **tạo** Activity ở bước 6 — xem mục *`Resource:` — đính kèm vào Activity* cuối file này. Hai danh sách khác nhau, đừng trộn.

## Nhét id vào document (bước 6)

### Video: một document riêng, `type: "VIDEO"`

Video **không** nhúng vào HTML. Nó là một Document riêng trong Tab. Khai trong plan JSON:

```json
{ "type": "VIDEO", "video_quiz_ids": ["<quiz_id>"] }
```

`build-section.sh` dựng thành:

```json
{ "type": "VIDEO",
  "payload": { "video_quiz_ids": ["<quiz_id>"] },
  "course_id": "<course_id>" }
```

Plan có doc `VIDEO` mà thiếu `video_quiz_ids` thì `--dry-run` chặn ngay — không để vỡ lúc Tab đã tạo xong.

### Ảnh: nhúng thẳng vào `content` của document TEXT

```html
<p>Nội dung Activity</p>
<img src="PRESIGN_URL" title="so-do-quy-trinh.png"
     resource_id="88ff4a9e-…" width="200">
<p>Nội dung Activity</p>
```

| Thuộc tính | Giá trị |
|---|---|
| `src` | **đúng chuỗi `PRESIGN_URL`**, viết nguyên văn — xem ghi chú dưới |
| `title` | `display_name` của file |
| `resource_id` | `.data[0].id` ở call 4 |
| `width` | `200` là giá trị mẫu. Tài liệu Lark không cho biết kích thước hiển thị nên giữ `200`; **đừng bịa số khác** |

> `src="PRESIGN_URL"` là **hằng chuỗi, không phải placeholder cần thay**. LMS dựng ảnh bằng `resource_id`; `src` chỉ cần khác rỗng vì `src=""` làm trang hiển thị báo lỗi ảnh. Viết đúng chín chữ cái in hoa đó — đừng thay bằng URL thật, đừng để rỗng, đừng bỏ `resource_id`.

Vì ảnh nằm trong `content`, nó phải có mặt **lúc tạo Document** — không có endpoint sửa Document. Đây là lý do bước 5 phải chạy trước bước 6.

## Manifest

`upload-media.sh` ghi `<course-slug>/work/media-manifest.json`, khoá theo đường dẫn file truyền vào (tính từ gốc dự án):

```json
{
  "_folder": { "parent_id": "6e6c7fa8-…", "location": "course/28793f52-…/" },
  "planning-e2e/assets/s01-a01-planning-e2e-va-hanh-trinh.mp4": {
    "resource_id": "5ea505e1-…",
    "quiz_id": "9b5bc233-…",
    "display_name": "s01-a01-planning-e2e-va-hanh-trinh.mp4",
    "suffix_type": "VIDEO",
    "file_key": "course/28793f52-…/1786637661822_s01-a01-….mp4",
    "size": "1570024"
  }
}
```

File đã có khoá trong manifest thì script in `SKIP` và không upload lại — chạy lại cả bước 5 an toàn. Đổi `--manifest` sang file khác là upload lại từ đầu và tạo resource trùng; **một khóa học một manifest**, nằm trong thư mục của chính khóa đó.

## File quá lớn — bỏ qua, không xử lý

Call 2 trả `type` khác `SINGLE_PART` là file vượt ngưỡng upload một phát. **Đây là quyết định thiết kế, không phải việc tồn đọng:** skill không làm luồng nhiều phần.

Script tự xử lý, không cần bạn can thiệp:

1. Ghi vào manifest `{"skipped": "<type>", "resource_id": null, "quiz_id": null}` — sticky, chạy lại không thử lại.
2. In `SKIP` kèm dung lượng và lý do.
3. **Exit 0**, để vòng lặp qua các file còn lại chạy tiếp.

Hai việc bắt buộc phải làm sau đó:

- **Bước 6 không tạo document cho file bị bỏ qua.** Video skip thì Activity đó **không có** document `VIDEO`; ảnh skip thì **không có** thẻ `<img>`. Nhét `null` vào `video_quiz_ids` hay `resource_id=""` là tạo ra document hỏng.
- **Báo người dùng theo từng Activity**, không báo chung chung: nói rõ Activity nào thiếu media gì, kèm đường dẫn file ở `<course-slug>/assets/` để họ tự upload trên giao diện.

## Bảng lỗi

| Hiện tượng | Nguyên nhân / xử lý |
|---|---|
| `SKIP … server trả type=MULTI_PART` | Không phải lỗi. Xem mục trên |
| `bước 3 PUT trả 403` | URL presigned hết hạn (1 giờ) hoặc chữ ký sai. Chạy lại lệnh cho file đó |
| `không xác định được content_type cho '.xxx'` | Đuôi lạ. Bổ sung vào bảng trong `upload-media.sh`; fallback `file` chỉ nhận `video/*`, `image/*`, `audio/*`, `application/pdf` |
| `suffix_type=VIDEO nhưng quiz_id rỗng` | Không dựng được Document VIDEO. Báo người dùng, đừng dùng `resource_id` thay thế |
| `chưa có UPBASE_COURSE_ID` | Chưa chạy `scripts/course/start.sh --course <id>` |
| Video lên rồi nhưng chưa phát được | Có thể đang xử lý phía LMS. Không phải lỗi của luồng này — kiểm lại trên giao diện sau ít phút |

## Đọc lại document của một Tab

```text
GET /course-sections/tab/<TAB_ID>
```

`create-tab-quiz.sh` dùng call này để kiểm chéo sau khi tạo Document QUIZ — `201` không bảo đảm câu hỏi đã gắn.

Hình dạng response chưa được đặc tả, nên script **không đoán schema**: nó dò đệ quy toàn bộ JSON tìm object có `.id` trùng document vừa tạo, rồi đếm `quiz_questions` ở chính object đó hoặc trong `.payload`. Cách này đúng bất kể document nằm sâu mấy tầng, và chỉ dựa vào hai thứ đã biết chắc: id do chính mình vừa tạo, và tên trường `quiz_questions` trong payload đã gửi.

| Script in ra | Nghĩa |
|---|---|
| `read-back: 3/3 câu đã gắn` | khớp, xong |
| `⚠️ không thấy document <id>` | response không chứa id vừa tạo — kiểm trên giao diện |
| `⚠️ không đọc được quiz_questions` | thấy document nhưng không có trường đó — kiểm trên giao diện |
| `⚠️ gắn được 2/3 câu` | server nhận thiếu — kiểm trên giao diện |

Endpoint này nhận `If-None-Match` và trả `304`; script không gửi header đó nên luôn nhận `200`.

## Chưa làm được

| Thiếu | Cần gì |
|---|---|
| `payload.attachments` của Document TEXT | curl mẫu. Ảnh đã nhúng được qua `<img resource_id>`, nên trường này chưa cần tới |

Hai thứ **cố ý không làm**, đừng đưa lại vào danh sách trên:

- **Upload nhiều phần** — xem mục *File quá lớn*.
File dưới `Resource:` (thường là handout PDF) **không** nằm ở đây — nó upload và gắn được, xem mục *`Resource:` — đính kèm vào Activity*.

## `Resource:` — đính kèm vào Activity

**Dấu hiệu duy nhất: file nằm dưới nhãn `Resource:` của Activity đó.** Upload file như mọi media khác, rồi gắn `resource_id` vào `files[]` của Activity:

```json
"files": [ { "resource_id": "96d51764-…", "type": "attached" } ]
```

Khai trong plan JSON ở **cấp Activity** (ngang hàng `name`, `duration`, `tabs`):

```json
{ "name": "1.1 Planning E2E và hành trình khóa học",
  "duration": 60,
  "files": [ { "resource_id": "96d51764-…", "type": "attached" } ],
  "tabs": [ … ] }
```

`build-section.sh` tự chuẩn hóa: thiếu `type` thì mặc định `"attached"`; không có `files` thì gửi `[]`.

> ⚠️ **`resource_id` phải có TRƯỚC khi tạo Activity.** Không có endpoint gắn file vào Activity đã tạo — cùng ràng buộc như ảnh trong Document. `--dry-run` chặn nếu có phần tử `files[]` thiếu `resource_id`.

Resource thường là `.pdf` handout; `upload-media.sh` nhận `application/pdf` bình thường, không cần cờ gì thêm. Tên file trong template (*File 1*, *File 2*, *File handout*) không quyết định gì — chỉ vị trí dưới `Resource:` mới tính.

> 🚫 **Không có `Resource:` thì Activity không có file đính kèm** — `files: []`, và đó là trạng thái hợp lệ.
>
> **Ảnh nằm giữa nội dung một `Text:` KHÔNG vào đây.** Nó là ảnh minh họa của chính Document TEXT đó, nhúng bằng thẻ `<img resource_id="…">` trong `content` — xem *Media đi đâu* trong `references/lark-source.md`. Đẩy nó sang `files[]` là gắn nhầm chỗ, và ảnh sẽ vừa hiện trong bài vừa nằm ở mục tài liệu đính kèm.
>
> Dòng metadata kiểu `Handout: Có — Quick Reference…` **không phải** định nghĩa: nó không kèm file, không nằm dưới `Resource:`, không tạo gì.
