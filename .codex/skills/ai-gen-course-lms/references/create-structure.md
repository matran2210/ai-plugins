# Dựng cấu trúc khóa học

`SKILL.md` **bước 6**. Script lo cơ khí; chỗ duy nhất cần nghĩ là **mục 3 — soạn plan**, và nghĩ ở đây nghĩa là chuyển `outline.md` thành JSON, không phải tự thiết kế khóa học.

Điều kiện vào, đủ cả bốn:

1. `outline.md` đã được **người dùng duyệt** (`SKILL.md` bước 3).
2. `SKILL.md` bước 4 đã exit 0 — đã có token OPS.
3. Bước 5 đã tạo khóa học và `scripts/course/start.sh` đã ghi `course_id` vào session — **không hỏi người dùng id này**.
4. **Bước 5 đã upload xong toàn bộ media** và `media-manifest.json` có đủ `resource_id` / `quiz_id`. Thiếu id nào thì Activity đó mất media vĩnh viễn — không có endpoint sửa Document.

Khóa học đã được **bước 5 tạo** (`status: DRAFT`). Bước này chỉ dựng nội dung bên trong.

> ⚠️ **Bước 6 không tạo bài test.** Trong plan JSON: `section_test: false`, và **không** đặt document `{"type":"QUIZ"}`. Không chạy `create-course-test.sh`.
>
> Mọi bài test — Document QUIZ, Section Test, `MID_TERM_TEST`, `FINAL_TEST` — dồn sang **bước 7**, cùng setting và câu hỏi. Không tạo Question Topic.

Chuẩn chia Activity / Tab / Document, khung HTML, cách viết outcome: `references/quality-structure.md`.

## Cây được dựng

```text
COURSE
└── SECTION                     ← endpoint backend vẫn là /course-sections/chapter
    ├── UNIT                    ← vỏ chứa Activity, mỗi Section đúng 1 Unit
    │   └── ACTIVITY            ← bài học
    │       └── TAB
    │           └── DOCUMENT    ← TEXT | QUIZ
    └── SECTION_TEST            ← con trực tiếp của SECTION

MID_TERM_TEST · FINAL_TEST      ← cùng cấp SECTION, con trực tiếp của COURSE
```

Thứ tự tạo **bất di bất dịch**, không đảo, không gộp:

```text
section → unit → learning outcome → activity → tab → document → section test
```

rồi hết mọi Section mới tới test cấp khóa (`MID_TERM_TEST`, `FINAL_TEST`).

**Tạo SECTION không tự sinh UNIT hay SECTION_TEST** — đã kiểm chứng: node con rỗng ngay sau khi POST. Script tự tạo cả hai.

> ⚠️ **Backend vẫn dùng chữ "chapter" ở ba chỗ, không đổi được:** path `/course-sections/chapter`, `quiz_for: "CHAPTER"` và `quiz_type: "CHAPTER_TEST"`. Đó là tên của API. Mọi chỗ khác — tài liệu Lark, outline, plan JSON, state key, biến trong script — đều gọi là **Section**.

## 1. Mở phiên

Cần **course_id**. Thiếu thì hỏi người dùng.

```bash
scripts/course/start.sh --course <uuid>
```

`course_id` do bước 5 vừa tạo, không hỏi người dùng. Không đưa token vào lệnh — `start.sh` đọc token từ session file mà `scripts/login.sh` đã ghi. Script in ra **tên khóa học**: đọc lại cho người dùng thấy. Tên không khớp thứ họ yêu cầu thì dừng, hỏi lại id. `=== SẴN SÀNG ===` mới đi tiếp.

Những gì phải biết về phiên:

- Session file dùng chung (`$UPBASE_ENV_FILE`, mặc định `$TMPDIR/upbase-session.env`, `chmod 600`). `start.sh` ghi lại token / course_id / base_url và giữ nguyên `UPBASE_TOPIC_ID`, nên một lần đăng nhập ở bước 4 dùng được cho cả bước 6 và bước 7.
- Hạn access token do **realm Keycloak** đặt, không phải con số cố định — `login.sh` in hạn thật sau khi đăng nhập. Token cũng mất sau khi máy reboot vì `$TMPDIR` bị dọn; muốn sống qua reboot: `export UPBASE_ENV_FILE="$HOME/.upbase-session.env"`.
- **Biến môi trường thắng session file.** Một `UPBASE_TOKEN` hoặc `UPBASE_COURSE_ID` cũ còn export trong shell sẽ âm thầm đè lên phiên vừa login / vừa start — lệnh vẫn chạy, nhưng bắn vào khóa sai. Kết quả lạ mà id thì đúng thì cho người dùng `unset` hai biến đó rồi chạy lại.
- **Không có cửa kiểm token nào trước khi chạy.** `login.sh` đăng nhập lại mỗi lượt, nên token hỏng hay hết hạn chỉ lộ ở request thật; gặp `401` ngay lệnh đầu thì nhờ người dùng đăng nhập lại.
- `start.sh` chỉ quét trang đầu `GET /courses` với `$PAGE_SIZE_COURSES` (mặc định 100, xem `scripts/config.sh`). Khóa nằm ngoài trang đầu bị báo `COURSE: id không có trong danh sách khóa học` dù id đúng — đưa nguyên thông báo đó cho người dùng, đừng kết luận id sai.

**Không chia phiên theo token.** Chốt bao nhiêu Section thì soạn plan đủ bấy nhiêu rồi chạy hết một lượt. Đừng ước lượng token đủ hay không đủ, đừng báo người dùng số phiên cần chạy. Hết token giữa chừng thì script dừng ở `401` — nhờ người dùng chạy `scripts/login.sh`, rồi lặp **đúng lệnh cũ**; state giữ tiến độ nên phần đã xong không bị tạo lại.

## 2. Dàn ý — đọc lại từ `outline.md`, không chốt lại

Dàn ý **đã chốt ở `SKILL.md` bước 3**. Mục này là đọc lại, không phải thương lượng: không đề xuất lại, không hỏi lại số Section, không tự thêm cho tròn, không bẻ lại theo `references/quality-structure.md`.

Người dùng sửa `outline.md` sau khi duyệt thì **đọc lại file**, không dùng bản đã nhớ trong đầu.

| Cần cho plan | Lấy ở `outline.md` mục 3 |
|---|---|
| `section.n` · `section.name` | số ở heading `Section <n>`; tên lấy từ nhãn `Name:` bên dưới heading |
| `section.description` | dòng *Mô tả* |
| `learning_outcome.name` · `.description` | dòng *LO to* |
| `learning_outcome.items[]` | bảng *LO con* — giữ nguyên **số** tài liệu đánh |
| `activities[].name` · `.duration` · `.display_icon` · `.outcome_refs[]` | các cột trong bảng Activity |
| `section_test` | dòng *Section Test* cuối mỗi Section |

### Tab và Document viết gì

**Mỗi Tab trong plan phải ứng với một nhãn `Tab <n>:` trong tài liệu.** Không có nhãn thì không có Tab — `tabs: []` là hợp lệ.

| Nhãn con trong Tab | Document trong plan |
|---|---|
| `Text:` | `{"type":"TEXT","content":"<html>"}` |
| `Video:` | `{"type":"VIDEO","video_quiz_ids":["<quiz_id>"]}` |
| `Quiz:` | **bỏ khỏi plan ở bước 6** — Document QUIZ rỗng tạo ở bước 7 bằng `create-tab-quiz.sh --tab-index <t>` |

`content` của Document TEXT = nội dung sau nhãn `Text:`, chuyển sang HTML. Ảnh nhúng bằng `<img src="PRESIGN_URL" title="<display_name>" resource_id="…" width="200">` — `src` là **hằng chuỗi `PRESIGN_URL`**, không để rỗng (rỗng thì trang học viên báo lỗi ảnh).

**Chỉ nhúng ảnh nằm TRONG chính `Text:` đó**, đúng vị trí nó xuất hiện giữa các đoạn văn. Ảnh của `Text:` khác thì thuộc document khác; file dưới `Resource:` thì **không nhúng vào document nào** — nó đi thẳng vào `files[]` của Activity.

> 🚫 **Đừng nhồi LO, thời lượng hay resource vào Document TEXT.** Ba thứ đó có chỗ riêng: LO là node `/course_learning_outcomes`, thời lượng là `duration`, resource là `files[]` của Activity.
>
> 🚫 **Cũng đừng đẩy ngược ảnh của `Text:` lên `files[]` của Activity.** Muốn một file thành resource đính kèm thì tài liệu phải ghi nó dưới nhãn `Resource:`; không có nhãn đó thì `files: []`.
>
> ⚠️ **Media bị bỏ qua ở bước 5 thì không tạo document cho nó.** Manifest có `"skipped"` hoặc thiếu id nghĩa là file chưa lên LMS: **bỏ hẳn** document `VIDEO`, **bỏ hẳn** thẻ `<img>`. Nhét `null` vào `video_quiz_ids` hay `resource_id=""` là tạo document hỏng mà vẫn `201`.

**Không viết thêm giảng giải, ví dụ, bài tập, tóm tắt.** Tài liệu không có thì Document mỏng — cứ để mỏng và nhắc trong báo cáo cuối. Chuẩn 1.500–4.000 ký tự ở `quality-structure.md` **không áp dụng** cho luồng này.

## 3. Soạn plan

Một file JSON cho một Section, đặt tại `<course-slug>/work/plan-s<N>.json`. Soạn **hết plan của mọi Section** và **toàn bộ HTML** trước khi gọi API — tạo Tab rồi mới viết nội dung mà bị ngắt giữa chừng thì khóa học còn lại Tab rỗng.

```json
{
  "section": {
    "n": 3,
    "name": "Săn sale cơ bản",
    "description": "<p>Cách đọc chương trình sale và tính giá thực trả.</p>"
  },
  "learning_outcome": {
    "name": "Đọc và tính đúng giá thực trả",
    "description": "<p>Giúp học viên đọc chương trình sale và tính giá.</p>",
    "items": [
      { "n": 1, "description": "<p>Phân biệt 6 nhóm chương trình giảm giá.</p>" },
      { "n": 2, "description": "<p>Tính giá thực trả có phí vận chuyển.</p>" }
    ]
  },
  "activities": [
    { "name": "Bản đồ chương trình sale", "duration": 45, "display_icon": "VIDEO",
      "outcome_refs": [1, 2],
      "files": [ { "resource_id": "96d51764-…", "type": "attached" } ],
      "tabs": [
        { "name": "Nội dung bài học",
          "docs": [ { "type": "TEXT", "content": "<h2>…</h2>" },
                    { "type": "VIDEO", "video_quiz_ids": ["9b5bc233-…"] } ] },
        { "name": "Ghi nhớ & Thực hành",
          "docs": [ { "type": "TEXT", "content": "<h2>…</h2>" } ] }
      ] },
    { "name": "Kiểm tra cuối Section 3", "duration": 20, "display_icon": "QUIZ",
      "outcome_refs": [2],
      "tabs": [ { "name": "Kiểm tra", "docs": [ { "type": "TEXT", "content": "<h2>Hướng dẫn</h2>" } ] } ] }
  ],
  "section_test": false
}
```

- `section.n` — **chỉ dùng làm `position`** và làm khóa state (`section:N`). Script **không** ghép nó vào tên.
- `learning_outcome` — **LO to của Section**. `name`/`description` lấy từ hai dòng con `Name:` và `Mô tả:`; bỏ trống thì script tự đặt `Learning Outcome {n}` và mượn `section.description`.
- `learning_outcome.items[]` — **LO con**, mỗi phần tử `{n, description}`. `n` là **số tài liệu đánh** trong `Learning Outcome <n>:`, không phải chỉ số mảng. Script gửi lên theo `n` tăng dần rồi map id trở lại theo chính `n` đó.
- `activities[].outcome_refs[]` — các **số** LO con mà Activity này dùng, lấy nguyên từ dòng `Learning Outcome: 1, 3`. Một số dùng ở nhiều Activity là bình thường. Trỏ tới số không có trong `items[]` → `--dry-run` chặn.
- `duration` — số phút, từ nhãn `Time:`, làm tròn lên, tối thiểu 1. Thiếu thì script dùng 30 và Activity đó phải có một dòng *Sai lệch*. **Đừng ghi `0`**: API trả `422`.
- `display_icon` — **đúng một trong `TEXT` · `VIDEO` · `QUIZ`**, lấy từ nhãn `Type of Activity:`. `is_graded` script tự suy (`QUIZ` → `true`), **không khai riêng**. Tài liệu ghi giá trị khác thì quy về `TEXT` và ghi *Sai lệch*; plan mang giá trị lạ thì `--dry-run` chặn. Trường cũ `.quiz` bị từ chối.
- `activities[].files[]` — resource đính kèm, `{"resource_id":"…","type":"attached"}`. Lấy `resource_id` từ `media-manifest.json`. Phải có **trước khi tạo Activity**; `--dry-run` chặn nếu thiếu.
- `video_quiz_ids` — là **`quiz_id`** trong manifest, không phải `resource_id`.
- `section_test` — ở luồng này **luôn `false`**; khung bài test rỗng tạo ở bước 7.

> ⚠️ **Shape cũ bị script từ chối:** `.outcomes` ở cấp Section hoặc trong Activity, `.activities[].quiz`, và `.chapter_test` / `.chapter_test_name`.

## 4. Dựng cây

```bash
# in dàn ý mọi Section, chưa gửi gì
for f in <course-slug>/work/plan-s*.json; do scripts/course/build-section.sh "$f" --dry-run; done

# tạo tuần tự, ghi state sau mỗi node, dừng ngay khi có Section lỗi
for f in <course-slug>/work/plan-s*.json; do scripts/course/build-section.sh "$f" || break; done
```

Vòng lặp phải chạy **tuần tự**. Chạy song song nhiều `build-section.sh` trên cùng một state file thì chúng đua nhau ghi `$STATE.tmp` rồi `mv`, làm mất id đã lưu.

Trong `--dry-run`, Activity không có tab/doc in ra `null` chứ không phải `0` — dễ lướt qua khi soát dàn ý, cứ thấy `null` là plan thiếu doc.

Script tạo đúng thứ tự section → unit → outcome → activity → tab → document → section test và **dừng ngay khi có node lỗi**, để không để lại cây dở dang.

Xong hết Section là **hết bước 6**. Không tạo bài test ở đây — Quiz trong Activity, Section Test và Midterm/Final đều tạo ở **bước 7**.

State file của bước 6 phải được giữ lại: bước 7 đọc key `section:N` từ chính nó để lấy `SECTION_ID`.

⚠️ Hai script có **mặc định state khác nhau**: `build-section.sh` dùng `$(dirname plan)/state.json` — plan nằm trong `work/` nên nó tự đúng. Còn `create-course-test.sh` dùng `state.json` theo thư mục đang đứng, tức **luôn phải truyền `--state <course-slug>/work/state.json`**. Plan nằm ở thư mục khác mà quên `--state <đường dẫn state.json>` thì `create-course-test.sh` tự tạo state file trống ở đó và **tạo lại midterm/final lần thứ hai**, không cảnh báo gì.

## State và resume

Mọi id được ghi vào state file ngay sau từng node. Chạy lại thì mỗi node có id trong state in `SKIP` và đi tiếp — nên `401` giữa chừng chỉ cần đăng nhập lại rồi lặp đúng lệnh cũ.

| Key | Node |
|---|---|
| `section:N` · `unit:N` · `lo:N` | Section, Unit, LO to của Section N |
| `lo_outcomes:N` | **map `{"<số>": "<id>"}`** của LO con Section N — Activity tra bằng số trong `outcome_refs[]`, kể cả khi chạy lại |
| `act:N:a` · `tab:N:a:t` · `doc:N:a:t:d` | Activity thứ `a`, Tab thứ `t`, Document thứ `d` (đếm từ 0) |
| `sectiontest-shell:N` | vỏ Section Test do `build-section.sh` tạo — **không dùng ở luồng này** (`section_test: false`) |
| `sectiontest:N` | Section Test rỗng do `create-course-test.sh` tạo ở bước 7. Hai khóa cố ý khác nhau để không đụng `sectiontest-shell:N` |
| `tabquiz:<TAB_ID>` | Document QUIZ rỗng trong Tab, do `create-tab-quiz.sh` tạo ở bước 7 |
| `coursetest:MID_TERM_TEST` · `coursetest:FINAL_TEST` | Test cấp khóa |

Hai giới hạn của cách đặt key này:

- Key **không chứa course_id**. Dùng lại một state file cho khóa **khác** — hoặc cho hai plan trùng `section.n` — thì script in toàn `SKIP`, exit 0, báo "xong" mà không tạo gì; tệ hơn là nối cây mới vào id của khóa cũ. **Một state file cho đúng một khóa học**, và mỗi Section một `section.n` riêng.
- `coursetest:$TYPE` chỉ chứa được **một** `MID_TERM_TEST` và **một** `FINAL_TEST`. Khóa cần hai bài cùng loại thì bài thứ hai bị `SKIP` im lặng với exit 0 — phải dùng state file riêng cho nó.

## Báo cáo cuối

Nói đủ: số Activity / Tab / Document đã tạo, bài test cấp khóa nào đã tạo, node nào lỗi kèm nguyên nhân. Và **luôn nhắc** ba thứ:

1. Bước này **chưa tạo bài test nào** — các khung bài test rỗng dựng ở bước 7.
2. Media nào bị bỏ qua ở bước 5 (file quá lớn, `.pdf`) thì Activity tương ứng thiếu media — liệt kê theo từng Activity kèm đường dẫn ở `<course-slug>/assets/`.
3. Document nào mỏng vì tài liệu nguồn không có thân bài — liệt kê ra, đừng để người dùng tự phát hiện.

## Quy tắc cứng của bước 6

Cộng thêm với quy tắc cứng chung ở `SKILL.md`.

1. **Dàn ý lấy từ `outline.md` đã được duyệt.** Không tự quyết số Section, số Activity hay bố cục Tab, và không đề xuất lại. Chưa có bản duyệt thì không tạo gì.
2. **Thứ tự tạo bất di bất dịch**: section → unit → learning outcome → activity → tab → document → section test, xong hết Section mới tới test cấp khóa.
3. **`parent_id` của Activity luôn là `UNIT_ID`**, không bao giờ là `SECTION_ID` — sai chỗ này thì Activity không hiện trong Section.
4. **Learning Outcome dùng `course_section_id` = `SECTION_ID`**, không phải `UNIT_ID`.
5. **Một Section đúng một Unit**, tên chính xác `Learning activity`, `position: 1`. Không tạo Unit thứ hai.
6. **Section không gửi `parent_id`** — script chỉ dựng khóa 3 cấp. Khóa có `PART` (4 cấp) không dựng được bằng bộ script này; gặp thì báo người dùng, đừng tự lách.
7. **`MID_TERM_TEST` / `FINAL_TEST`**: `quiz_for: "COURSE"`, **không** `course_section_id`. **Section Test**: `quiz_for: "CHAPTER"` + `quiz_type: "CHAPTER_TEST"` + `course_section_id` = `SECTION_ID`. **Document QUIZ**: `quiz_type: "QUIZ"`, **không** `quiz_for`.
8. **Bước 6 không tạo bài test nào.** `section_test: false`, không có document `{"type":"QUIZ"}`, không chạy `create-course-test.sh`. Bài test, setting và câu hỏi đều ở bước 7.
9. **Doc `TEXT` hướng dẫn làm bài đứng trước Doc `QUIZ`** trong Tab kiểm tra, và ghi rõ phạm vi ôn tập, ngưỡng đạt, điểm dễ mất.
10. **Soạn xong toàn bộ HTML rồi mới gọi API.** Không placeholder — Tab đã tạo mà nội dung chưa viết thì khóa học còn lại Tab rỗng.
11. **Một state file cho đúng một khóa học**, và mỗi lúc chỉ một tiến trình `build-section.sh` ghi vào nó. Không dùng lại state file của khóa khác, không chạy song song.
12. **Không xóa gì.** `DELETE /course-sections/{id}` xóa cascade cả cây con và không hoàn tác được.

## Endpoint và payload

`BASE` = `$UPBASE_BASE_URL` — xem `scripts/config.sh`. Việc gọi API do `scripts/course/` lo — đừng tự gõ `curl`. Bảng dưới đây để tra khi script báo lỗi; toàn bộ endpoint đã gọi thật trên staging.

| Node | Path (`POST` trừ dòng cuối) | Trường bắt buộc | Ghi chú |
|---|---|---|---|
| Section | `/course-sections/chapter` | `name` (**nhãn `Name:` bên dưới heading `Section <n>`**, không phải chữ trong heading), `course_id` | `short_name`, `description`, `position` tùy chọn. `parent_id` **bỏ trống** với khóa 3 cấp |
| Unit | `/course-sections/unit` | `name` = `Learning activity`, `parent_id` = `SECTION_ID` | `position: 1` |
| Learning Outcome | `/course_learning_outcomes` | `name`, `course_section_id` = **`SECTION_ID`**, `outcomes[]` = `[{description}]` gom **mọi LO con của Section**, xếp theo **số** tăng dần | `text_editor_files: []`. Response trả `id` LO to **và `id` từng LO con** — map lại theo chính thứ tự đã gửi. **Phải tạo trước Activity** |
| Activity | `/course-sections/activity` | `name`, `parent_id` = **`UNIT_ID`**, `duration` ≥ 1, `display_icon` (`TEXT`\|`VIDEO`\|`QUIZ`), `is_graded`, `files: []`, `course_id`, `position` | server gán lại `position` toàn cục. Có LO thì thêm `course_learning_outcome_id` (id LO to) và `course_outcome_ids` (id của **đúng những số** Activity tham chiếu) — gắn lúc tạo, **không có endpoint gắn sau** |
| Tab | `/course-sections/tab` | `course_section_id` = `ACTIVITY_ID`, `tab_name`, `course_id` | |
| Document | `/course-sections/tab/{TAB_ID}/document` | `type`, `payload`, `course_id` | `TEXT` → `payload {content, attachments}` + `text_editor_files: []`. `QUIZ` → `QUIZ_CFG` + `quiz_type: "QUIZ"` |
| Section Test | `/quiz` | `name`, `quiz_for: "CHAPTER"`, `quiz_type: "CHAPTER_TEST"`, `course_section_id` = **`SECTION_ID`**, `quiz_questions: []` | tự sinh node `SECTION_TEST` rỗng dưới Section. **Không** truyền `course_id`. Tạo ở bước 7 |
| Midterm / Final | `/quiz` | `name`, `quiz_for: "COURSE"`, `quiz_type: "MID_TERM_TEST"` hoặc `"FINAL_TEST"`, `course_id`, `quiz_questions: []` | **không truyền `course_section_id`** — test cấp khóa rỗng, con trực tiếp của COURSE. Tạo ở bước 7 |
| Xóa | `DELETE /course-sections/{id}` | — | **xóa cascade cả cây con**, không hoàn tác |

### `QUIZ_CFG` — đã chốt, không đồng bộ theo giao diện

Đã diff với request thật của giao diện OPS: lệch `grading_preference` (skill chấm `AFTER_ALL_QUESTIONS`, giao diện chấm `AFTER_EACH_QUESTION`), lệch `is_tutor`, và không gửi bốn trường `quiz_timed` / `is_auto_pass_point` / `number_of_multiple_choice_questions` / `number_of_essay_questions`. Cả hai mẫu đều tạo được bài test.

> ✅ **Giữ nguyên `QUIZ_CFG`. Đây không phải việc tồn đọng.** Đừng tự sửa; muốn đổi thì người dùng nói.

`QUIZ_CFG` (`scripts/course/quiz-config.sh`) dùng chung cho cả bốn loại bài — Document QUIZ, Section Test, Midterm, Final — và không cấu hình được theo từng bài. `is_graded` trong `QUIZ_CFG` khác hoàn toàn `is_graded` của Activity (cái sau suy từ `display_icon == "QUIZ"`).

## Bảng lỗi

| Tình huống | Nguyên nhân & cách xử lý |
|---|---|
| `401 Unauthorized` | Token hết hạn. Nhờ người dùng chạy `scripts/login.sh` trong terminal của họ, rồi lặp lại **đúng lệnh cũ** — state giữ tiến độ. Không tự chạy `login.sh`, không đoán token, không dùng lại token cũ |
| `404 Not Found` | Sai ID. Kiểm tra `COURSE_ID`, `SECTION_ID`, `UNIT_ID`, `ACTIVITY_ID`, `TAB_ID` |
| `422 · exceptions.invalid_data` | Đọc `error.others[].property`. Hay gặp: `duration < 1` |
| `422 · quiz_for must be one of…` | Copy nhầm payload giữa Document QUIZ và Section Test. Giá trị hợp lệ: `COURSE`, `PART`, `SECTION`, `TAB_DOCUMENT`, `ENTRANCE_TEST`, `EVENT_TEST`, `STORY_ITEM_DOCUMENT` |
| Activity không hiện trong Section | `parent_id` nhận `SECTION_ID` chứ không phải `UNIT_ID` |
| Quiz tạo xong có 0 câu hỏi | Tài liệu không viết câu nào cho bài đó. Có câu hỏi thì chạy `create-question.sh` ở bước 7.2 |

`check_auth()` chỉ bắt `401`. `403`, `404`, `422`, `5xx` rơi xuống nhánh `FAIL` chung, in tối đa 300 ký tự trường `error` — tra bảng trên để hiểu. Header, phân trang và bẫy phiên dùng chung: `references/api.md`.


## Khi sửa script

- `scripts/lib.sh` không bật `set -e`. Mọi node dựa vào `|| exit 1` viết tay; thêm lời gọi `create()` mà quên `|| exit 1` thì lỗi trôi qua và các node con gắn vào id rỗng.
- `QUIZ_CFG` là chuỗi JSON trải nhiều dòng có ký tự xuống dòng nhúng. Hỏng cú pháp là `--argjson cfg` fail ở **mọi** lời gọi create, không chỉ ở quiz.
- Cùng một `state.json` được ba đường ghi (`create()`, `create-course-test.sh`, và `.tmp` → `mv`). Giữ nguyên cách ghi tuần tự đó khi thêm node mới.
