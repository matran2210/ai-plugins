---
name: ai-update-course-lms
description: Use when the user wants to ADD learning components to an UpBase LMS course that ALREADY EXISTS — they paste an OPS course link (https://uplms-ops…/course-full/<course_id>) plus a Lark doc holding only the new parts ("thêm bài test vào khóa này", "bổ sung câu hỏi cho khóa có sẵn", "thêm Section mới vào khóa"). Adds new Sections (with Activity/Tab/Document/LO), Section Test, Mid Test, Final Test and their questions. Không sửa, không xóa node cũ; không tạo khóa mới — khóa mới dùng ai-gen-course-lms.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# AI Update Course LMS

Thêm cấu phần vào **một khóa đã có** trên LMS. Đầu vào là **hai link**: link khóa trên OPS và link tài liệu Lark chỉ chứa phần thêm. Đầu ra là phần thêm đó trên LMS, còn mọi node cũ giữ nguyên.

```text
bước 0  đầu vào                 → link khóa + link Lark, thiếu một là dừng
bước 1  đăng nhập OPS + đọc khóa → sync-course.sh, chỉ GET
bước 2  cửa chặn Lark + đọc tài liệu + tải media
bước 3  xuất outline.md          → NGƯỜI DÙNG DUYỆT, cửa chặn cứng
bước 4  đăng nhập lại + ghi state + upload media
bước 5  dựng Section mới
bước 6  tạo câu hỏi rồi bài test
```

Thêm được:

| Cấu phần | Ở đâu |
|---|---|
| Section mới, đủ Unit / LO / Activity / Tab / Document | nối **sau** Section cuối của khóa |
| Section Test | cho Section cũ hoặc Section mới |
| Mid Test, Final Test | cấp khóa |
| Câu hỏi | kèm các bài test trên, và Quiz trong Tab của **Section mới** |

> 🚫 **Ngoài phạm vi, không làm:** sửa hay xóa node cũ, thêm Activity/Tab vào Section cũ, Quiz trong Tab của Section cũ, sửa thông tin khóa (`Name:`, `Course Category:`, `Passpoint:`, `Điểm thành phần:`), ảnh bìa, `Course Resource:`. Tài liệu có những thứ này thì ghi *Sai lệch* là **bỏ qua**, không tạo.

## Dùng chung với `ai-gen-course-lms`

Skill này **không có script và references riêng**. Mọi thứ nằm ở skill anh em `ai-gen-course-lms`, cùng plugin `course-builder`:

```text
<base>/                       ← Base directory của skill này, hiện ra khi skill được nạp
<base>/../ai-gen-course-lms/  ← gọi là <gen> trong file này
```

Việc đầu tiên của lượt: lấy `<base>` ở dòng *Base directory for this skill*, rồi đổi `<gen>` thành đường dẫn đầy đủ trong mọi lệnh. **Không đặt vào biến shell**: mỗi lệnh Bash là một shell riêng.

Quy tắc của `<gen>` vẫn áp dụng nguyên vẹn, trừ khi file này nói khác:

| Cần | Đọc |
|---|---|
| Cửa chặn Lark, đọc block, tải media | `<gen>/SKILL.md` bước 0–2 · `<gen>/references/lark-source.md` |
| Đăng nhập OPS, chọn môi trường | `<gen>/SKILL.md` bước 4 |
| Upload media | `<gen>/SKILL.md` 5.3 · `<gen>/references/upload-media.md` |
| Plan Section, dựng cây | `<gen>/references/create-structure.md` |
| Câu hỏi, bài test | `<gen>/SKILL.md` bước 7 · `<gen>/references/question-types.md` |
| Định dạng các mục outline | `<gen>/references/outline-format.md` |
| Quy tắc cứng chung | `<gen>/SKILL.md`, mục *Quy tắc cứng chung* |

**Không bao giờ `cd`.** Mọi lệnh chạy với cwd là thư mục dự án của người dùng.

## Thư mục làm việc

Mỗi lượt cập nhật một thư mục riêng, có `state.json` **mới**:

```text
<course-slug>/
└── update-<YYYYMMDD-HHMM>/     ← chốt ở bước 1, dùng nguyên cho cả lượt
    ├── outline.md
    ├── assets/
    └── work/
        ├── state.json          section:1..K do sync-course.sh ghi + id mọi node mới
        ├── media-manifest.json
        ├── plan-s<N>.json
        └── questions-<test>.json
```

`<course-slug>` là tên khóa (do `sync-course.sh` in ra), không dấu, gạch nối. Khóa từng được `ai-gen-course-lms` dựng thì thư mục `<course-slug>/` đã có sẵn; thư mục `update-…` nằm bên trong nó.

> 🚫 **Không dùng lại `state.json` của lượt khác**, kể cả `<course-slug>/work/state.json` của lượt tạo khóa. State key không chứa tên bài test: `q:final:1` của lượt cũ khiến câu 1 của bài mới in `SKIP`, và bài mới nối nhầm câu hỏi cũ. Lượt mới = thư mục `update-…` mới.

## Bước 0 — đầu vào

Cần đủ hai thứ:

1. **Link khóa** dạng `https://uplms-ops.upbase.asia/course-full/<course_id>`. `course_id` là uuid cuối link. Có uuid trần cũng được.
2. **Link tài liệu Lark** chứa phần thêm.

Thiếu cái nào thì hỏi đúng cái đó rồi **kết thúc lượt**. Không đề xuất nội dung, không đoán khóa.

## Bước 1 — đăng nhập OPS và đọc khóa

Đăng nhập **đúng như `<gen>/SKILL.md` bước 4**: `<gen>/scripts/login.sh --gui`, timeout 600000 ms, người dùng chọn môi trường. Khác luồng tạo một điểm: ở đây đăng nhập **trước** outline, vì outline phải biết khóa đang có gì. Bước này chỉ **đọc**, không tạo gì.

```bash
<gen>/scripts/course/sync-course.sh --course '<link khóa>'
```

Chọn prod thì thêm `UPBASE_ENV=prod` trước lệnh, như mọi lệnh về sau.

Script gọi `GET /courses/<id>` và `GET /courses/<id>/sections` rồi in:

- tên khóa, `status`;
- từng Section theo thứ tự trên LMS (`Section 1..K`): tên, số Activity, có LO không, Section Test đã có;
- test cấp khóa đã có (`FINAL_TEST`, `MID_TERM_TEST`);
- dòng `K Section hiện có → Section mới đánh số từ K+1`.

Nó cũng ghi session (`UPBASE_COURSE_ID`). Script **thay cho `start.sh`** trong luồng này: `start.sh` chỉ thấy 100 khóa mới nhất.

**Đọc tên khóa ra cho người dùng.** Không khớp khóa họ nói → dừng, hỏi lại link.

| Lỗi | Nghĩa |
|---|---|
| `link khóa là môi trường prod, đang chạy staging` | chọn sai môi trường ở hộp thoại. Đăng nhập lại, chọn đúng |
| `GET /courses/<id> trả 404` | id không có ở môi trường này |
| `401` | token hết hạn — đăng nhập lại, chạy lại đúng lệnh |

Chốt `<course-slug>` và thư mục `update-<YYYYMMDD-HHMM>/` ngay ở đây.

## Bước 2 — đọc tài liệu Lark và tải media

Làm **đúng `<gen>/SKILL.md` bước 0, 1, 2**: cửa chặn `lark-cli`, đọc cả `rawContent` lẫn block list, tải media về `<course-slug>/update-…/assets/`. Bóc nội dung theo `<gen>/references/lark-source.md`.

Khác luồng tạo ở cách hiểu **số Section**. Số trong `Section <n>` của tài liệu là **số thật trên LMS sau khi thêm**:

| Tài liệu có | Nghĩa | Được chứa |
|---|---|---|
| `Section <n>`, `n ≤ K` | Section **cũ** số `n` | **chỉ** `Section Test` (heading `Section Test` kèm câu hỏi). `Name:` nếu có thì phải khớp tên trên LMS |
| `Section <n>`, `n > K` | Section **mới** | đủ như luồng tạo: `Name:`, LO, Activity, Tab, `Section Test` |
| `Midterm Test` / `Final Test` | test cấp khóa mới | như luồng tạo |
| vùng *Thông tin khóa học* | — | bỏ qua toàn bộ, ghi một dòng *Sai lệch* |

Ghi *Sai lệch* với **"bạn quyết"** khi:

- Section mới **không liền nhau từ `K+1`** (khóa có 6 Section mà tài liệu ghi `Section 8` không có `Section 7`). Không tự đánh lại số.
- Section cũ có Activity, Tab hay `Quiz:` → ngoài phạm vi, **không tạo**.
- `Name:` của Section cũ khác tên trên LMS → có thể tài liệu trỏ nhầm Section.
- Bài test trùng loại với bài **đã có**: Section Test cho Section đã có Section Test, hoặc Final/Mid khi khóa đã có bài cùng loại. Skill vẫn tạo được bài thứ hai, nhưng người dùng phải xác nhận.
- Câu hỏi của Mid/Final không xác định được Section (như luồng tạo). Cột *Section* được trỏ cả Section cũ lẫn Section mới.

Media đặt tên theo `<gen>/references/lark-source.md`, *Quy ước đặt tên*, với `<SS>` là số Section thật.

## Bước 3 — outline.md và chờ duyệt

Ghi `<course-slug>/update-…/outline.md`. Bảy mục, đúng thứ tự. Mục 3–6 dùng định dạng của `<gen>/references/outline-format.md`.

1. **Nguồn**: link + tiêu đề tài liệu Lark, `document_id`, số block; link khóa, `course_id`, tên khóa, `status`, môi trường.
2. **Khóa hiện có**: chép bảng `sync-course.sh` in ra (Section 1..K, Section Test đã có, test cấp khóa đã có). Ghi rõ **`K = <số>`**: bước 4.2 dùng lại con số này.
3. **Section mới sẽ tạo**: như mục 3 của `outline-format.md`, chỉ cho Section `n > K`. Không có thì ghi "không có".
4. **Media đã tải**.
5. **Bài test và câu hỏi sẽ tạo**: như mục 5 của `outline-format.md`. Mỗi bài ghi rõ thuộc Section **cũ** hay **mới**.
6. **Sai lệch và thiếu hụt**.
7. **Sẽ tạo mới trên LMS**: liệt kê tên từng Section và bài test sắp tạo, kèm mã SL cần người dùng quyết. Nhắc: **không sửa node cũ; thứ đã tạo không xóa được bằng skill.**

> 🚫 **Cửa chặn cứng.** Ghi file xong thì **kết thúc lượt**, chờ người dùng duyệt bằng lời. Không upload, không soạn plan. Người dùng sửa `outline.md` thì đọc lại file.

## Bước 4 — đăng nhập lại, ghi state, upload media

### 4.1 Đăng nhập lại

Lượt mới sau khi duyệt → **đăng nhập lại** bằng `<gen>/scripts/login.sh --gui`, như `<gen>/SKILL.md` bước 4. Môi trường phải **trùng** môi trường ghi ở outline mục 1; lệch thì dừng, hỏi người dùng.

### 4.2 Ghi state từ khóa thật

Chạy **trước mọi lệnh tạo**, kể cả upload:

```bash
<gen>/scripts/course/sync-course.sh --course '<link khóa>' \
  --state <course-slug>/update-…/work/state.json --expect-sections <K ở outline mục 2>
```

Script đọc lại cây và ghi `section:1..K` → `SECTION_ID`, cùng khóa `_course`. Nó **dừng** khi:

- số Section trên LMS khác `K`: khóa bị sửa sau khi duyệt. Xuất lại outline, không chạy tiếp;
- state file là của khóa khác, hoặc `section:N` đang trỏ id khác.

Chạy lại sau khi đã dựng Section mới vẫn an toàn **chỉ khi** truyền `--expect-sections` bằng số Section **hiện tại**.

### 4.3 Upload media

**Đúng `<gen>/SKILL.md` 5.3**, manifest ở `<course-slug>/update-…/work/media-manifest.json`. Ảnh đề bài câu hỏi thêm `--folder-type QUESTION`. Luồng này không có 5.1, 5.2, 5.4 của `<gen>`.

## Bước 5 — dựng Section mới

Không có Section mới thì bỏ qua bước 5.

Soạn `plan-s<N>.json` cho từng Section `N > K` **đúng `<gen>/references/create-structure.md`** mục 2–4: `section.n = N`, `section_test: false`, Tab có `Quiz:` thì để `deferred_quiz` theo file đó.

```bash
for f in <course-slug>/update-…/work/plan-s*.json; do <gen>/scripts/course/build-section.sh "$f" --dry-run; done
for f in <course-slug>/update-…/work/plan-s*.json; do <gen>/scripts/course/build-section.sh "$f" || break; done
```

Chạy **tuần tự**, Section số nhỏ trước. `build-section.sh` đọc state cạnh plan, tức chính `work/state.json` đã có `section:1..K`.

## Bước 6 — câu hỏi rồi bài test

Làm **đúng `<gen>/SKILL.md` bước 7** (7.1 câu hỏi, rồi 7.2 bài test), mọi lệnh truyền `--state <course-slug>/update-…/work/state.json`.

- **Section Test của Section cũ**: `--section <n>` với `n ≤ K`. Script lấy `SECTION_ID` từ key `section:<n>` do 4.2 ghi.
- **Câu hỏi Mid/Final**: `.section` trỏ Section cũ hay mới đều được. Key `section:<n>` đều đã có trong state.
- **Quiz trong Tab**: chỉ cho Tab của Section mới (`create-tab-quiz.sh --section <N>` với `N > K`).

Câu hỏi TRƯỚC, bài test SAU. `--dry-run` trước mọi lệnh tạo.

## Báo cáo kết thúc

Một tin nhắn:

1. **Đã thêm gì**: Section mới (số Activity / Tab / Document), từng bài test kèm số câu hỏi, và thuộc Section nào.
2. Mọi dòng `⚠️` của read-back.
3. Mục *Sai lệch* đã bỏ qua hoặc chưa quyết.
4. Link khóa, kèm `status` đã đọc ở bước 1.

Không xóa thư mục `update-…`: `state.json` trong đó ngăn chạy lại tạo trùng.

## Quy tắc cứng

1. **Chỉ thêm.** Không có lệnh nào sửa hay xóa node cũ. Muốn sửa thì người dùng làm trên giao diện.
2. **Tài liệu Lark là nguồn duy nhất** cho phần thêm. Không tự viết câu hỏi, không bù chỗ thiếu.
3. **Không tạo gì trước khi outline được duyệt.** Bước 1 chỉ đọc.
4. **Một lượt một `state.json` mới.**
5. **Chỉ chạm API UpBase qua script trong `<gen>/scripts/`.** Không tự gõ `curl`.
6. Không in token, không ghi token vào file trong project, không nhận mật khẩu qua chat.
7. Cửa chặn nào fail (thiếu link, chưa đăng nhập, Lark chưa đọc được) thì **dừng hẳn lượt**: nêu đúng một việc người dùng cần làm.
8. **Làm đúng phạm vi.** Không tự khảo sát, đối chiếu thêm ngoài các lệnh ở đây.
