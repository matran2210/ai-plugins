# Tài liệu Lark — đọc và bóc nội dung

Dùng ở `SKILL.md` bước 1 và bước 2. Đối chiếu với block list thật của *Template_Course Content for AI*.

**Tài liệu là nguồn duy nhất.** File này dạy cách đọc, không cho phép suy diễn chỗ tài liệu để trống.

## Nhận dạng block — theo tên trường, không theo số

Mỗi block có đúng **một trường payload trùng tên với loại của nó**. `block_type` là số, dễ nhớ sai giữa các phiên bản API; tên trường thì không.

> ✅ block nào có trường `heading2` thì nó là heading cấp 2.
> ❌ block nào `block_type == 4` thì nó là heading cấp 2.

| Trường payload | `block_type` | Nghĩa trong luồng này |
|---|---|---|
| `page` | 1 | block gốc. Tiêu đề tài liệu ở `page.elements[].text_run.content` |
| `text` | 2 | đoạn văn — chở phần lớn nhãn |
| `heading1` | 3 | **vùng tài liệu**, không phải Section khóa học |
| `heading2` | 4 | Section, hoặc bài test cấp khóa |
| `heading3` | 5 | Activity, hoặc Section Test |
| `bullet` | 12 | gạch đầu dòng — chở nhãn cấp Activity và LO |
| `divider` | 22 | kẻ ngang, bỏ qua |
| `file` | 23 | **video / pdf / tệp đính kèm.** `file.name` + `file.token` → tải được |
| `view` | 33 | vỏ hiển thị của media. Không chứa dữ liệu, token ở block con |
| `quote_container` | 34 | trích dẫn / lưu ý. Nội dung ở block con |
| `image` | — | ảnh. `image.token` → tải được |
| `table` | — | bảng docx thật. Đọc được qua các block ô con |
| `ordered` | — | danh sách số. Xử lý như `bullet` |
| `sheet` · `bitable` | 30 · — | bảng tính / Base nhúng. **KHÔNG đọc được** → ghi *Sai lệch* |
| `code` | 14 | khối code. Cây ASCII kiến trúc nếu có — **chỉ để đối chiếu** |

Gặp trường payload không có trong bảng: ghi tên trường + `block_id` vào *Sai lệch* và hỏi người dùng. **Không đoán nghĩa.**

## Luật bao trùm: `Nhãn: giá trị`

Mọi dòng có cấu trúc trong tài liệu đều một dạng:

```text
<Nhãn>: <giá trị>
```

**Nhãn nói TẠO CÁI GÌ. Phần sau dấu hai chấm mới là NỘI DUNG.**

```text
Tab 1: Kiến thức nền tảng
└─┬──┘  └────────┬──────┘
  │              └── name của Tab
  └── dấu hiệu "đây là một Tab", KHÔNG phải tên
```

Nên `name` của Tab trên là `Kiến thức nền tảng`, **không phải** `Tab 1: Kiến thức nền tảng`. Áp dụng y hệt cho `Learning Outcome 3: …`, `Time: …`, `Text: …`.

Ba hệ quả bắt buộc nhớ:

- **Số trong nhãn là số thứ tự, không phải nội dung.** `Section 1` → `section.n = 1`; `Learning Outcome 2:` → LO con số 2. Đừng ghép số vào tên.
- **Sau dấu hai chấm trống thì không có nội dung.** Dùng mặc định của trường đó nếu có, và ghi một dòng vào *Sai lệch*. Đừng lấy chính nhãn làm giá trị. **Trừ `Quiz:`, `Video:`, `Resource:`, `Text:`** — bốn nhãn này vốn không mang giá trị trên cùng dòng, trống là đúng thiết kế, **không ghi *Sai lệch***.
- Khớp nhãn thì **bỏ khoảng trắng thừa hai bên dấu hai chấm và không phân biệt hoa thường**. Tài liệu mẫu có `Final Test :` (thừa space trước dấu) và ` Text:` (thụt đầu dòng) — cả hai đều phải nhận.

> ⚠️ **Heading Section / Activity / bài test KHÔNG theo luật này.** Chúng có nhãn `Name:` riêng — xem ngay dưới.

### Tên Section / Activity / bài test lấy từ nhãn `Name:`

Heading `Section <n>`, `Activity <n>`, `Section Test`, `Midterm Test`, `Final Test` **chỉ khai loại node và số thứ tự**. Tên thật nằm ở nhãn `Name:` bên dưới heading đó, **không viết sau dấu hai chấm của heading**:

```text
Section 1                                     ← heading: loại node + số thứ tự
Name: Khởi tạo và thiết lập gian hàng Shopee  → section.name
Description: Tổng quan mô hình hoạt động…     → section.description

  Activity 1                                  ← heading: loại node + số thứ tự
  Name: Tổng quan sàn Shopee và các loại…     → activity.name
  Time: 25 phút                               → duration

  Section Test:                               ← heading (dấu hai chấm thừa, bỏ qua)
  Name: Bài kiểm tra Section 1 — …            → tên bài test
```

Ba luật:

- **Có `Name:` thì `Name:` thắng**, kể cả khi heading cũng có chữ sau dấu hai chấm.
- **Không có `Name:`** → mới lấy phần sau dấu hai chấm của heading (dạng cũ `Section 1: Giới thiệu khóa học`). Cả hai dạng đều phải đọc được.
- **Không có cả hai** → node chưa có tên. Dùng chính nhãn heading (`Section 1`, `Activity 2`, `Section Test`…) làm tên tạm và ghi một dòng vào *Sai lệch*. Đừng tự nghĩ tên.

`Name:` này là **của node đang mở**. Ba chỗ cùng nhãn `Name:`, phân biệt bằng vùng và nhãn nhóm gần nhất:

| `Name:` ở đâu | Là tên của |
|---|---|
| vùng *Thông tin khóa học* | khóa học |
| ngay sau một heading, chưa vào nhãn nhóm nào | Section / Activity / bài test đang mở |
| bên trong nhóm `Learning Outcome:` | `learning_outcome.name` (LO to) |

Giá trị hay bị **cắt làm nhiều `text_run`** vì bôi đậm loang lổ (nhãn đậm, giá trị thường, đôi khi giá trị lại đậm một khúc). Phải nối hết `elements` rồi mới tách theo `\n`; đọc từng element riêng là ra mảnh vụn.

## Cây block: lồng thật, nhưng lồng không đều

Tài liệu này **có** `children` thật ở một số chỗ, và **không có** ở một số chỗ khác — trong cùng một Activity:

| Có `children` | Phẳng ở gốc |
|---|---|
| `Nội dung:` → các `Learning Outcome N:` | `Name:` |
| `Resource:` → các File | `Time:` |
| `Tab N:` → `Text:` / `Video:` / `Quiz:` | `Type of Activity:` |
| `Text:` → block nội dung | `Learning Outcome:` (dòng tham chiếu) |

Thêm một chỗ trái khoáy: trong Tab, `Video:` và block `[Video]` của nó là **anh em**, không phải cha con; còn `Text:` thì nội dung lại là **con**.

Nên luật đọc là **lai**, theo đúng thứ tự này:

1. Block có `children` → nội dung của nhãn đó là **các block con**.
2. Không có `children` → nội dung là **các block đứng sau nó** cho tới nhãn cùng cấp kế tiếp.

Riêng cấp bậc Section/Activity thì vẫn suy ra từ **loại heading + thứ tự xuất hiện**, không bao giờ từ `parent_id`: `heading2` mở Section, `heading3` mở Activity, mỗi heading mới đóng cái cũ.

> ⚠️ Dựng cây bằng `parent_id` sẽ ra một khóa học **phẳng, không Section nào có Activity** — và không có lỗi nào báo cho bạn biết.

## Vùng của tài liệu — `heading1` chia vùng

| `heading1` | Vai trò |
|---|---|
| *Thông tin khóa học* | metadata khóa: `Name:`, `Description:`, `Course Category:`, `Type:`, `Passpoint:`, `Điểm thành phần:` |
| *Chi tiết khóa học* | Section → Activity → LO → media → bài test. **Nguồn tạo duy nhất** |

Tên `heading1` ở tài liệu khác có thể khác chữ. Nhận vùng *nguồn tạo* bằng dấu hiệu cấu trúc, không bằng khớp chuỗi: đó là vùng `heading1` mà **bên dưới có `heading2` kèm `heading3`**.

Tài liệu có thêm vùng khác (bảng tổng quan `sheet` nhúng, cây ASCII kiến trúc trong block `code`) thì **chỉ để đối chiếu**, không phải nguồn tạo. Lệch với vùng chi tiết thì **vùng chi tiết thắng**, và ghi cả hai con số vào *Sai lệch*.

## Metadata khóa — vùng *Thông tin khóa học*

| Nhãn | Đi vào đâu | Ghi chú |
|---|---|---|
| `Thumbnail:` | **ảnh bìa khóa** — không nằm trong `POST /courses` | nhãn nhóm, ảnh nằm bên dưới. Upload riêng ở bước 5.2, xem *Ảnh bìa* |
| `Course Resource:` | **tài liệu đính kèm của CẢ KHÓA** — không nằm trong `POST /courses` | nhãn nhóm, file nằm bên dưới. Upload rồi đính ở bước 5.4, xem *Tài liệu của khóa* |
| `Name:` | `name` của `POST /courses` | **không phải tiêu đề tài liệu** |
| `Description:` | `description` của `POST /courses` | mỗi đoạn một `<p>…</p>` |
| `Course Category:` | `course_category_id` | **search theo tên**: `GET /course_categories?name=<giá trị>`; khớp 0 hoặc >1 đều **dừng**, xem ngay dưới |
| `Type:` | `course_type` | trống → mặc định `$COURSE_TYPE` |
| `Passpoint:` | `pass_point` | số nguyên; trống → mặc định `$COURSE_PASS_POINT` |
| `Điểm thành phần:` | `setting` | bốn dòng con, xem ngay dưới |

`Điểm thành phần:` là nhãn nhóm, giá trị nằm ở **bốn bullet con**:

| Dòng con | Khóa trong `setting` |
|---|---|
| `Tiến độ học:` | `progress` |
| `Section Test:` | `chapter_points` |
| `Mid Test:` | `mid_term_points` |
| `Final Test:` | `final_test_points` |

`activity_points` và `topic_points` **không có trong template** → giữ `0`. Dòng nào trống thì lấy giá trị tương ứng trong `$COURSE_SETTING` và ghi một dòng vào *Sai lệch*.

> 🚫 **`Section Test:` / `Mid Test:` / `Final Test:` ở đây là TRỌNG SỐ ĐIỂM, không phải bài test.** Cùng chữ đó ở vùng *Chi tiết khóa học* mới là bài test. Phân biệt bằng vị trí: nằm trong `Điểm thành phần:` là điểm, là `heading` trong vùng chi tiết là bài test.

### `Course Category:` — khớp phải dứt khoát

Search theo tên rồi thu hẹp bằng ba mức (khớp chính xác → tên category nằm trong giá trị tài liệu, dài nhất thắng → giá trị tài liệu nằm trong tên category). Chi tiết call: `references/upload-media.md`.

| Số kết quả sau khi thu hẹp | Làm gì |
|---|---|
| đúng 1 | dùng nó |
| 0 | **dừng** — ghi *Sai lệch*, đưa người dùng danh sách tên hiện có |
| **>1** | **dừng** — ghi *Sai lệch*, liệt kê các tên khớp và **hỏi người dùng chọn cái nào** |
| tài liệu bỏ trống nhãn | **dừng** — ghi *Sai lệch*, đưa danh sách để họ điền |

> 🚫 **Không tự chọn phần tử đầu tiên trong mọi trường hợp.** Gắn khóa vào sai category là lỗi im lặng: API trả `201`, khóa vẫn tạo, và không ai biết cho tới khi có người đi tìm nó trên giao diện.

### `Description:` → `description` của khóa

Nội dung là **toàn bộ phần nằm giữa nhãn và nhãn kế tiếp**, kể cả chữ viết ngay sau dấu hai chấm trên cùng dòng.

Ở tài liệu mẫu, block `Description:` **không có chữ nào sau dấu hai chấm** — các đoạn mô tả nằm ở **những block `text` liền sau**. Đọc mỗi block chứa nhãn rồi dừng là ra mô tả rỗng.

Chuyển sang HTML: mỗi đoạn một thẻ `<p>…</p>`, nối liền nhau, nguyên văn.

> 🚫 **Không lấy `Name:` làm mô tả.** `<p><tên khóa></p>` chỉ là giá trị chống rỗng của script khi tài liệu không có `Description:`; rơi vào đó thì phải có một dòng *Sai lệch*.
>
> 🚫 **Không lấy `Description:` của Section làm mô tả khóa.** Cùng nhãn, khác cấp: cái nằm trước `heading1` *Chi tiết khóa học* là của khóa, cái nằm sau một `heading2` là `section.description`.

## Bóc vùng chi tiết

Duyệt tuần tự, mỗi block rơi vào đúng một ô:

| Thấy | Làm |
|---|---|
| `heading2` `Section <n>` | mở Section mới. `section.n` = số trong nhãn; `name` lấy từ nhãn `Name:` bên dưới |
| `heading2` `Midterm Test` / `Final Test` | **không phải Section** — bài test cấp khóa; tên lấy từ nhãn `Name:` bên dưới |
| `heading3` `Activity <n>` | mở Activity mới thuộc Section đang mở; `name` lấy từ nhãn `Name:` bên dưới |
| `heading3` `Section Test` | Section Test của Section đang mở; tên lấy từ nhãn `Name:` bên dưới |
| nhãn khi **chưa mở Activity nào** | metadata của Section đang mở — xem *Cấp Section* |
| nhãn khi **đã mở một Activity** | thuộc Activity đó — xem *Cấp Activity* |
| `quote_container` | lưu ý — đưa vào outline dạng ghi chú, không tạo thành node |
| `text` rỗng, `divider` | bỏ qua |

### Cấp Section

| Nhãn | Đi vào đâu |
|---|---|
| `Name:` | `section.name` — **tên của Section**, không phải tên khóa |
| `Description:` | `section.description` |
| `Learning Outcome:` | nhãn nhóm của **LO to** — giá trị nằm ở ba dòng con |
| ├ `Name:` | `learning_outcome.name` |
| ├ `Mô tả:` | `learning_outcome.description` |
| └ `Nội dung:` | nhãn nhóm của **LO con** — các dòng con `Learning Outcome <n>:` |
| `Learning Outcome <n>: <nội dung>` | **LO con số `n`** của Section |

### Cấp Activity

| Nhãn | Đi vào đâu |
|---|---|
| `Name:` | `activity.name` — **tên của Activity** |
| `Time: <giá trị>` | `duration` — xem *`Time:` → `duration`* |
| `Type of Activity: <giá trị>` | `display_icon` + `is_graded` — xem *`Type of Activity:`* |
| `Learning Outcome: <n>, <m>` | **tham chiếu** tới LO con số `n`, `m` — xem *Learning Outcome* |
| `Resource:` | mọi block `file` bên dưới → `files[]` của Activity |
| `Tab <n>: <tên>` | **một Tab**, tên = phần sau dấu hai chấm |

Trong một `Tab <n>:`:

| Nhãn | Tạo gì |
|---|---|
| `Text: <nội dung>` | Document `TEXT` |
| `Video:` | Document `VIDEO` — block `file` đi kèm |
| `Quiz:` | Document `QUIZ`. **Không có tên sau dấu hai chấm** — script không gửi `name`, LMS tự đặt mặc định. Các `Câu <n>.` bên dưới là câu hỏi của chính bài này, tạo ở bước 7 |

**Thứ tự Document trong Tab = thứ tự nhãn trong tài liệu.** Một Tab có thể có nhiều `Text:`; tài liệu mẫu có Tab dạng Text → Video → Text.

`Tab <n>:` để trống tên thì đặt theo **loại Document đầu tiên** bên trong: `Text` → `Nội dung bài học` · `Video` → `Video` · `Quiz` → `Kiểm tra`. Đây là mặc định có quy tắc, không phải tự nghĩ.

> 🚫 **Không có `Tab <n>:` thì Activity không có Tab nào.** `tabs: []` là trạng thái hợp lệ. Đừng dựng Document rồi nhồi LO, thời lượng, resource vào cho "đỡ trống" — mỗi thứ đó đã có chỗ riêng.
>
> Có `Tab <n>:` mà bên trong không có nhãn con nào → tab rỗng, **không tạo**, ghi vào *Sai lệch*.

## Learning Outcome — khai một chỗ, Activity tham chiếu bằng SỐ

Đây là chỗ khác nhiều nhất so với cách đọc cũ. LO con **không nằm dưới Activity**. Chúng khai tập trung ở cấp Section, đánh số; Activity chỉ ghi những **số** nó dùng.

```text
Section 1
  Name:  Giới thiệu khóa học                  → section.name
  Learning Outcome:
    Name:  Hiểu tổng quan Planning E2E        → learning_outcome.name
    Mô tả: Giúp học viên nắm mục tiêu…        → learning_outcome.description
    Nội dung:
      Learning Outcome 1: Xác định mục tiêu…  → LO con số 1
      Learning Outcome 2: Giải thích thuật…   → LO con số 2
      Learning Outcome 3: Phân loại đầu vào…  → LO con số 3
  Activity 1
    Name: Planning E2E và hành trình khóa học → activity.name
    Learning Outcome: 1, 3                    → Activity 1 dùng LO 1 và 3
  Activity 2
    Name: Những thuật ngữ cần thống nhất      → activity.name
    Learning Outcome: 1                       → Activity 2 dùng LO 1
```

Bốn luật của cơ chế này:

- **Một LO con dùng chung cho nhiều Activity là bình thường.** Ví dụ trên, LO 1 gắn vào cả hai Activity. Đừng nhân bản nó thành hai LO.
- **LO con không Activity nào tham chiếu vẫn được tạo.** LO 2 ở ví dụ trên không ai dùng — nó vẫn nằm trong `outcomes[]` của LO to, chỉ là không Activity nào gắn. Ghi một dòng vào *Sai lệch*.
- **Tham chiếu tới số không tồn tại là lỗi tài liệu.** `Learning Outcome: 4` mà Section chỉ khai 3 → bỏ tham chiếu đó, ghi *Sai lệch*, **không tự bịa LO số 4**.
- **Activity không có dòng `Learning Outcome:`** → không gắn LO nào, `course_outcome_ids: []`.

### LMS chỉ có một node — Activity tham chiếu id

Trên LMS, cả Section chỉ có **một node** `/course_learning_outcomes`. LO con **không phải node riêng**: chúng là các phần tử `outcomes[]` bên trong node đó. Thứ tự bắt buộc:

1. **Tạo LO to trước** — `outcomes[]` chứa **toàn bộ LO con của Section**, xếp theo đúng số thứ tự đã đánh trong tài liệu (1, 2, 3…).
2. Response trả về `id` của LO to và `id` của từng LO con.
3. **Rồi mới tạo Activity**, gắn `course_learning_outcome_id` = id LO to và `course_outcome_ids` = id của **đúng những số mà Activity đó tham chiếu**.

```json
{"name":"ACt 5","parent_id":"<UNIT_ID>","is_graded":false,"duration":72,
 "display_icon":"TEXT","files":[],"course_id":"<COURSE_ID>","position":6,
 "course_learning_outcome_id":"a6dd22da-…","course_outcome_ids":["e60d5793-…","0d7fc806-…"]}
```

> 🚫 **Không đảo thứ tự.** Activity gắn LO lúc **tạo**; không có endpoint gắn LO vào Activity đã tạo. Tạo Activity trước là mất liên kết vĩnh viễn, mà API vẫn trả `201`.
>
> 🚫 **Đừng map theo thứ tự xuất hiện.** Map theo **số** trong `Learning Outcome <n>:`. Tài liệu đánh số nhảy cóc hoặc lộn xộn thì vẫn theo số, không theo vị trí.

Section không khai `Learning Outcome:` nào → **không tạo node LO**, và Activity không gửi hai trường trên.

## `Time:` → `duration`

`duration` của Activity là **con số ghi ở `Time:`**, không phải mặc định của script và không phải con số bạn ước lượng từ độ dài video.

Quy đổi ra **số phút nguyên**:

| Tài liệu ghi | `duration` | Vì |
|---|---|---|
| `Time: 45` | 45 | số trần = phút |
| `Time: ~2 phút` | 2 | lấy số trước đơn vị phút, bỏ dấu `~` |
| `Time: ~5 phút 30 giây` | 6 | có phần giây → **làm tròn lên** |
| `Time: 45 giây` | 1 | chỉ có giây → tối thiểu 1 |

Dấu `~`, `khoảng`, `≈` bỏ qua — chúng không đổi con số. Nhãn tiếng Việt `Thời lượng:` nhận tương đương.

Hai điều bắt buộc:

- **Luôn ≥ 1.** `duration: 0` làm API trả `422 exceptions.invalid_data`. Làm tròn lên đã bảo đảm điều này; đừng ghi `0` kể cả khi tài liệu ghi `Time: 0`.
- **Không có `Time:` thì không đoán.** Để script dùng mặc định (`ACTIVITY_DEFAULT_DURATION` trong `scripts/config.sh`, 30 phút) và ghi **một dòng vào *Sai lệch***. Đừng suy ra từ thời lượng video, từ tổng thời lượng khóa, hay từ số chữ trong bài.

`Time:` ở vùng *Thông tin khóa học* là **tổng thời lượng khóa** — chỉ ghi vào outline, không thành `duration` của node nào.

## `Type of Activity:` → `display_icon`

`display_icon` chỉ nhận **đúng ba giá trị**: `TEXT`, `VIDEO`, `QUIZ`. Giá trị sau dấu hai chấm phải khớp một trong ba — **bỏ khoảng trắng thừa, không phân biệt hoa thường** (`video`, ` Quiz `, `TEXT` đều nhận).

`is_graded` suy ra từ nó, không có nhãn riêng: `QUIZ` → `true`, hai giá trị còn lại → `false`.

| `Type of Activity:` | `display_icon` | `is_graded` |
|---|---|---|
| `Text` | `TEXT` | `false` |
| `Video` | `VIDEO` | `false` |
| `Quiz` | `QUIZ` | `true` |
| **bất kỳ thứ gì khác, hoặc bỏ trống** | `TEXT` + **ghi *Sai lệch*** | `false` |

> 🚫 **Không đoán từ từ khóa gần đúng.** `Reading`, `Bài giảng`, `Practice`, `Test` **không** phải giá trị hợp lệ — quy về `TEXT` và **ghi một dòng vào *Sai lệch*** nêu rõ Activity nào ghi gì, để người dùng sửa tài liệu. Đừng tự map `Test` → `QUIZ` như thể tài liệu viết đúng.
>
> **Luôn ghi nguyên văn giá trị vào outline**, kể cả khi hợp lệ — người dùng cần đối chiếu được.

`build-section.sh --dry-run` chặn plan có `display_icon` ngoài ba giá trị đó. Tới lúc ấy là đã muộn, nên phải quy về `TEXT` ngay từ khi đọc tài liệu.

## Media đi đâu — quyết định bằng NHÃN BỌC NGOÀI

Cùng một block `file`/`image`, nằm dưới nhãn khác nhau thì thành thứ khác nhau. Bảng này là luật duy nhất:

| Block media nằm dưới | Đi vào đâu | Trường |
|---|---|---|
| `Thumbnail:` ở vùng *Thông tin khóa học* | **ảnh bìa của khóa** | endpoint riêng, xem *Ảnh bìa* ngay dưới |
| `Course Resource:` ở vùng *Thông tin khóa học* | **đính kèm cả khóa** | `attachments: [{resource_id, type: "attached"}]`, xem *Tài liệu của khóa* |
| `Resource:` của một Activity | **đính kèm Activity** | `files: [{resource_id, type: "attached"}]` |
| `Video:` bên trong một `Tab <n>:` | Document `VIDEO` của Tab đó | `{"type":"VIDEO","video_quiz_ids":["<quiz_id>"]}` |
| nội dung của một `Text:` | **nằm trong chính Document TEXT đó** | thẻ `<img src="PRESIGN_URL" resource_id="…">` trong `content` |
| ngay dưới heading `Câu <n>.`, trước nhãn đầu tiên của câu | **đề bài của câu hỏi đó** | upload `--folder-type QUESTION`, khai vào `images[]` của plan 7.1 — xem *Câu hỏi* |
| không nhãn nào bọc | không tạo gì — ghi *Sai lệch* | — |

> 🚫 **Chỉ `Resource:` mới sinh `files[]` của Activity.** Ảnh nằm giữa nội dung một `Text:` là **ảnh minh họa của bài viết đó**, nhúng vào HTML của Document TEXT — **không** đính kèm Activity, **không** nhân bản sang `files[]`. Muốn một file thành resource của Activity thì tài liệu phải ghi rõ nó dưới nhãn `Resource:`.
>
> Ngược lại cũng vậy: file dưới `Resource:` chỉ đính kèm Activity, **không** tự nhúng vào Document TEXT nào.

**Không phân loại theo tên file.** *File handout*, *File 1*, *File 2* trong template chỉ là chỗ điền — tên gọi không quyết định gì. Cái quyết định là **vị trí trong cây nhãn**, theo đúng bảng trên.

Mọi block `file` nằm dưới `Resource:` — children của nó, hoặc các block đứng sau tới nhãn cùng cấp kế tiếp — đều vào `files[]` của Activity đang mở. `Resource:` trống thì Activity không có file đính kèm: `files: []` là trạng thái hợp lệ.

### Ảnh bìa — nhãn `Thumbnail:`

Nằm ở vùng *Thông tin khóa học*, thường là nhãn đầu tiên. Nhãn không mang giá trị trên cùng dòng; **ảnh nằm ở block bên dưới** (`image`, hoặc `view` → `image`), đúng luật lồng lai của tài liệu này.

Đường đi khác hẳn mọi media còn lại:

| | Media thường | `Thumbnail:` |
|---|---|---|
| Upload bằng | presigned S3, `upload-media.sh` | `PUT /courses/image`, multipart |
| Sinh ra | `resource_id` / `quiz_id` | không sinh id nào — ảnh gắn thẳng vào khóa |
| Gắn vào lúc | **tạo** node, không sửa được sau | gọi riêng sau khi khóa đã có, **đặt lại được** |

Vì đi đường riêng nên **không** đẩy ảnh này vào `files[]`, **không** nhúng nó thành `<img>` trong Document nào.

> 🚫 **`Thumbnail:` không có ảnh thì khóa không có ảnh bìa.** Đừng lấy tạm ảnh đầu tiên trong tài liệu, đừng lấy ảnh của một Activity nào đó — ghi một dòng vào *Sai lệch* và đi tiếp. Khóa không ảnh bìa là trạng thái hợp lệ.
>
> ⚠️ Chỉ nhận **một** ảnh. Dưới `Thumbnail:` có nhiều ảnh thì lấy **ảnh đầu tiên**, và ghi *Sai lệch* nêu rõ đã bỏ những ảnh nào.

### Tài liệu của khóa — nhãn `Course Resource:`

Nằm ở vùng *Thông tin khóa học*. Nhãn nhóm, **file nằm ở các block bên dưới** — nhiều file đều được.

> ⚠️ **`Course Resource:` KHÁC `Resource:`.** Cùng chữ "resource", cùng `type: "attached"`, nhưng khác chủ sở hữu:
>
> | | Khai ở | Đính vào | Gắn bằng |
> |---|---|---|---|
> | `Course Resource:` | vùng *Thông tin khóa học* | **cả khóa** | `POST /courses/<id>/add-resource`, bước 5.4 |
> | `Resource:` | dưới một `Activity <n>` | **một Activity** | `files[]` lúc **tạo** Activity, bước 6 |
>
> Phân biệt bằng **vùng**: nằm trước `heading1` *Chi tiết khóa học* là của khóa; nằm dưới một `heading3` `Activity <n>` là của Activity. Nhầm chỗ là file hiện sai nơi, mà API vẫn trả 2xx.

Khác `Resource:` một điểm nữa, quyết định thứ tự làm: `Resource:` phải gắn **lúc tạo** Activity và không sửa được sau; `Course Resource:` là một call riêng chạy **sau khi khóa đã tồn tại**.

File ở đây đi **đủ bốn call upload** như mọi media khác (folder → metadata → PUT S3 → add-file-resource) để lấy `resource_id`, rồi mới tới call thứ năm đính vào khóa. Nhiều file thì **một call duy nhất** — `attachments` là mảng.

> 🚫 **Không có nhãn `Course Resource:`, hoặc nhãn không có file → khóa không có tài liệu đính kèm.** Đừng gom tạm file của Activity nào đó lên cấp khóa. Ghi *Sai lệch* rồi đi tiếp.

## Sai cấu trúc thì không tạo, chấm hết

Nội dung nằm ngoài mọi nhãn — video không có `Video:` bên trong một `Tab <n>:`, đoạn text lạc giữa hai nhãn, file không nằm dưới `Resource:` mà cũng không nằm trong `Text:`/`Video:` nào — **không tạo node nào cả**.

Đừng "cứu" nó bằng cách gán bừa vào chỗ gần nhất: một file lạc **không** được đẩy vào `Resource:` của Activity gần đó, một ảnh lạc **không** được nhét vào Document TEXT gần đó.

Không suy diễn ý người viết, không nới luật cho "có vẻ đúng ý". Ghi một dòng vào *Sai lệch* nêu rõ block nào bị bỏ và thiếu nhãn gì, để người dùng sửa tài liệu rồi chạy lại.

Gặp nhãn không có trong các bảng trên: ghi tên nhãn + `block_id` vào *Sai lệch* và hỏi người dùng. **Không đoán nghĩa.**

## Bài test

| Loại | Dấu hiệu | Node LMS |
|---|---|---|
| Quiz của Activity | nhãn `Quiz:` **bên trong một `Tab <n>:`** | Document `QUIZ` trong chính Tab đó |
| Section Test | `heading3` `Section Test:` **dưới một Section** | `SECTION_TEST` của Section đó |
| Midterm | `heading2` `Midterm Test` | `MID_TERM_TEST` |
| Final Test | `heading2` `Final Test` | `FINAL_TEST` |

Tên bài lấy ở nhãn **`Name:`** ngay dưới heading — heading chỉ là dấu hiệu. Không có `Name:` thì đặt mặc định theo loại và vị trí (`Section Test {n} - {tên Section}`), và ghi một dòng vào *Sai lệch*.

**Không phải định nghĩa bài test:** `Section Test:` / `Mid Test:` / `Final Test:` nằm trong `Điểm thành phần:` — đó là **trọng số điểm** ở cấp khóa.

### Setting bài test

Sáu nhãn, đều là block phẳng ngay dưới heading của bài test. Nhãn nào tài liệu không khai thì **giữ mặc định `QUIZ_CFG`** và ghi một dòng vào *Sai lệch*.

| Nhãn | Trường API | Giá trị nhận |
|---|---|---|
| `Type of Test:` | `quiz_question_type` | `Multiple Choice` → `MULTIPLE_CHOICE` · `Essay` → `ESSAY` |
| `Test Mode:` | `is_tutor` | `Tutor` → `true` · `Exam` → `false` |
| `Graded Assignment:` | `is_graded` | `Yes` → `true` · `No` → `false` |
| `Pass Point:` | `required_percent_score` | số; bỏ dấu `%` (`80%` → `80`) |
| `Grading Preference:` | `grading_preference` | `After all questions` → `AFTER_ALL_QUESTIONS` · `After each question` → `AFTER_EACH_QUESTION` |
| `Attempt:` | `is_limited: true` **+ `limit_count`** | số nguyên — số lần được làm lại |

Khớp giá trị **bỏ hoa thường, khoảng trắng, dấu `/` và `-`**. Giá trị ngoài bảng thì script **dừng** — đoán bừa là tạo bài test sai cấu hình mà API vẫn trả `201`.

> ⚠️ **`is_limited` và `limit_count` đi thành cặp.** Bật `is_limited: true` mà thiếu `limit_count` thì giới hạn không có hiệu lực, và API vẫn trả `201`.

## Câu hỏi

Mỗi câu là một heading (`heading4` hoặc `heading5` — tài liệu dùng cả hai) dạng `Câu <n>. <đề bài>` — **dấu chấm, không phải dấu hai chấm**. Đề bài là phần sau dấu chấm; số `<n>` chỉ để đánh thứ tự và làm state key.

**Ảnh của đề bài:** block `image` (hoặc `view` → `image`) nằm giữa heading `Câu <n>.` và nhãn đầu tiên của câu (`Đáp án đúng:`, `Cặp ghép:`, `Ô trống <k>:`…) là ảnh minh họa đề bài. Không có nhãn bọc riêng — vị trí đó là đủ. Tải về theo tên `q-<test>-c<NN>-img<NN>`, upload bằng `--folder-type QUESTION`, khai vào `images[]` của câu đó theo đúng thứ tự block. Ảnh nằm **sau** nhãn đầu tiên của câu (lẫn giữa các đáp án) thì không gắn — ghi *Sai lệch*.

```text
heading5  Câu 1. Theo bài học, vai trò quan trọng nhất của Booking…
image     SYaVbb…   → q-section01-c01-img01.png   ┐ images[] của câu 1
image     OktDbp…   → q-section01-c01-img02.png   ┘
bullet    Đáp án đúng: …                           ← từ đây là nhãn của câu, hết vùng ảnh
```

Bên dưới mỗi `Câu <n>.` là các nhãn của chính câu đó, tới `Câu` kế tiếp thì đóng:

| Nhãn | Nghĩa |
|---|---|
| `Question Type:` | bảy loại — bảng ngay dưới. **Chép nguyên văn vào `qtype`**, script tự quy đổi |
| `Question Layout:` | `One column` → `HORIZONTAL` · `Two column` → `VERTICAL` — **chép nguyên văn vào `layout` của plan, script tự quy đổi** |
| `Đáp án đúng:` | đáp án **đúng** — `is_correct: true` |
| `Đáp án nhiễu:` | các đáp án **sai** — `is_correct: false`. Dùng cho **cả** True / False |
| `Cặp ghép:` | **chỉ `Matching`** — mỗi block con là một cặp `vế trái → vế phải` |
| `Ô trống <k>:` | **chỉ `Select Word` / `Fill Word` / `Drag & Drop`** — nhãn nhóm của ô trống số `k`, bên trong lại là `Đáp án đúng:` / `Đáp án nhiễu:` |
| `Giải thích:` | **tùy chọn, mọi loại** — lời giải hiện sau khi học viên nộp bài → `solution`, bọc `<p>…</p>` |

### `Question Type:` — bảy nhãn

| Nhãn tài liệu | enum API | Hình dạng đáp án |
|---|---|---|
| `One Choice` | `ONE_CHOICE` | `Đáp án đúng:` + `Đáp án nhiễu:` phẳng |
| `Multiple Choice` | `MULTIPLE_CHOICE` | `Đáp án đúng:` + `Đáp án nhiễu:` phẳng |
| `True / False` | `TRUE_FALSE` | `Đáp án đúng:` + `Đáp án nhiễu:` phẳng |
| `Matching` | `MATCHING` | `Cặp ghép:` |
| `Select Word` | `SELECT_WORD` | `Ô trống <k>:` → đúng + nhiễu **trong từng ô** |
| `Fill Word` | `FILL_WORD` | `Ô trống <k>:` → **chỉ** đáp án đúng |
| `Drag & Drop` | `DRAG_DROP` | `Ô trống <k>:` → 1 đúng mỗi ô, + `Đáp án nhiễu:` **phẳng ở cấp câu hỏi** |

Khớp nhãn **bỏ hoa thường và ký tự không phải chữ cái**, nên `Drag & Drop` và `DRAG_DROP` cùng về một mối. Nhưng plan vẫn **chép nguyên văn cột trái** để đối chiếu được bằng mắt.

> 🚫 **Nhãn nào dùng với loại nào là ràng buộc cứng.** `Đáp án nhiễu:` trong một câu `Matching` hay `Fill Word`, hay `Cặp ghép:` trong một câu `One Choice`, đều là **tài liệu viết sai** — ghi *Sai lệch* và hỏi người dùng, đừng tự diễn giải. `create-question.sh` cũng dừng ở đó.

### Ô trống — nhãn `Ô trống <k>:`

Tài liệu đánh ô trống trong đề bài là `[1]`, `[2]`, `[3]`…, liên tục từ 1, mỗi số đúng một lần. Mỗi ô có một nhãn `Ô trống <k>:` riêng bên dưới.

Soạn plan: **mỗi `[k]` thành một `{{blank}}`** trong `content` theo đúng thứ tự, và một phần tử `blanks[]`. Số lượng phải khớp — không khớp là script dừng.

> 🚫 **Không gõ thẻ `<span>` vào `content`.** Script sinh UUID v4 chữ thường rồi kiểm lại; backend chỉ đếm ô trống mang UUID đúng dạng đó.

Ba loại ô trống khác nhau ở chỗ **`Đáp án nhiễu:` nằm đâu** — nhầm chỗ là câu hỏi chấm sai:

| Loại | `Đáp án nhiễu:` | Mỗi ô mấy đáp án đúng |
|---|---|---|
| `Select Word` | **trong** mỗi `Ô trống <k>:` | 1 hoặc nhiều |
| `Fill Word` | **không có** | nhiều dòng = nhiều cách viết được chấp nhận |
| `Drag & Drop` | **phẳng ở cấp câu hỏi**, rổ dùng chung | đúng 1 |

### Cặp ghép — nhãn `Cặp ghép:`

Mỗi block con là một cặp, hai vế ngăn nhau bằng `→` (tài liệu gõ `->` cũng nhận). Thành `matchings[]` với `{left, right}` theo đúng thứ tự.

`Matching` **không có đáp án nhiễu** — mọi cặp đều đúng.

### Luật lồng lai

Hai nhóm đáp án đều theo luật lồng lai của tài liệu này:

- **có chữ ngay sau dấu hai chấm** → đó là **một** đáp án (`Đáp án đúng: Là quá trình…`);
- **trống sau dấu hai chấm, có `children`** → **mỗi block con là một đáp án** (dùng khi có nhiều đáp án đúng, hoặc liệt kê nhiều đáp án nhiễu).

Bỏ tiền tố đánh số nếu tài liệu có (`A. `, `B. `, `1. `) — nó là cách trình bày, không thuộc nội dung đáp án. Tài liệu mẫu viết `A. Sau khi Tactics Plan được duyệt.` thì đáp án là `Sau khi Tactics Plan được duyệt.`

`answer_position` đánh **từ 1 theo đúng thứ tự tài liệu viết**: hết nhóm `Đáp án đúng:` rồi tới `Đáp án nhiễu:`. Không xáo, không sắp lại.

> 🚫 **Không còn nhãn `Đáp án sai:`.** True / False trước đây dùng nhãn riêng đó; giờ dùng `Đáp án nhiễu:` như mọi loại khác. Tài liệu cũ còn viết `Đáp án sai:` thì ghi *Sai lệch* và hỏi người dùng — đừng tự suy là `Đáp án nhiễu:`.

### Điểm từng câu — chia đều, không vượt 100

Bài test nối câu hỏi qua `quiz_questions[]`, mỗi phần tử `{question_id, setting_grade}`.

Tài liệu không khai điểm riêng → **mọi câu nhận đúng cùng một số**: `100 / số câu`, giữ phần thập phân, làm tròn **XUỐNG** 2 chữ số.

| Số câu | `setting_grade` mỗi câu | Tổng |
|---|---|---|
| 2 | 50 | 100 |
| 3 | 33.33 | 99.99 |
| 4 | 25 | 100 |
| 7 | 14.28 | 99.96 |
| 8 | 12.5 | 100 |
| 9 | 11.11 | 99.99 |

> ⚠️ **Làm tròn XUỐNG, không phải làm tròn gần nhất.** `100/7 = 14.2857`; tròn lên thành `14.29` thì 7 câu cộng lại **100.03 — vượt 100**. Tròn xuống thì tổng luôn ≤ 100, và mọi câu vẫn bằng nhau.
>
> 🚫 **Không dồn phần dư vào câu đầu** để tổng tròn 100 (kiểu `33.34 · 33.33 · 33.33`). Câu hỏi cùng một bài thì điểm phải bằng nhau; lệch vài phần trăm ở tổng chấp nhận được, điểm lệch giữa các câu thì không.

Muốn điểm khác nhau thì khai `"grade"` cho **mọi** câu trong file 7.1 — chấp nhận số thập phân. Script chặn nếu tổng **vượt 100**, và cảnh báo nếu tổng thiếu (bài test không dùng hết điểm). Khai nửa vời — chỉ một số câu có `grade` — cũng bị chặn.

> 🚫 **Đừng tự quy đổi `Question Layout:` khi soạn plan.** Cặp giá trị này **ngược với trực giác**: `One column` → `HORIZONTAL`, `Two column` → `VERTICAL`. Đã có lần chọn ngược. `create-question.sh` quy đổi ở một chỗ duy nhất, từ chối plan nào khai `display_type` hoặc ghi `VERTICAL`/`HORIZONTAL` vào `layout`.

### Số đáp án phải khớp `Question Type:`

| `Question Type:` | Ràng buộc |
|---|---|
| `One Choice` | **đúng 1** đáp án đúng, và ít nhất 1 đáp án nhiễu |
| `Multiple Choice` | **từ 2** đáp án đúng trở lên |
| `True / False` | **đúng 2** đáp án tổng cộng, trong đó 1 đúng |
| `Matching` | **từ 2 cặp**, không vế nào rỗng |
| `Select Word` | mỗi ô **≥ 1 đúng và ≥ 1 nhiễu** |
| `Fill Word` | mỗi ô **≥ 1 đúng**, không ô nào có nhiễu |
| `Drag & Drop` | mỗi ô **đúng 1** đáp án, và **≥ 1** nhiễu chung ở cấp câu hỏi |

Ba loại có ô trống còn một ràng buộc nữa: **số ô `[k]` trong đề bài phải bằng số nhãn `Ô trống <k>:`**.

Không khớp thì `create-question.sh` **dừng trước khi gọi API** — câu hỏi tạo sai không xóa được bằng bộ script này, người dùng phải vào giao diện dọn tay.

> 🚫 **Không tự viết câu hỏi, không tự thêm đáp án nhiễu cho đủ số.** Tài liệu khai bao nhiêu thì tạo bấy nhiêu. Thiếu đáp án nhiễu, thiếu `Question Type:`, hay số đáp án không khớp — ghi *Sai lệch* và hỏi người dùng, đừng bù vào.

## Media

### Gom token

Duyệt block list, gom hai loại:

| Nguồn | Lấy | Loại |
|---|---|---|
| block có `file` | `file.token`, `file.name` | video, pdf, handout, tệp đính kèm |
| block có `image` | `image.token` | ảnh |

Gom xong thì **ghi luôn nhãn bọc ngoài của từng token** — `Resource:`, `Video:`, `Text:` nào, hay đề bài `Câu <n>.` nào. Đó là thứ quyết định file đó thành resource của Activity, Document VIDEO, hay thẻ `<img>` trong một Document TEXT; xem *Media đi đâu*. Tải về rồi mới đi tìm chỗ gắn là lúc đó không còn thông tin vị trí nữa.

Block `view` bọc ngoài **không chứa token** — nó chỉ là vỏ hiển thị. Lấy token ở block con. Bốn video của tài liệu mẫu đều nằm theo dạng `view` → `file`.

Phần mở rộng file lấy từ `file.name` (`.mp4`, `.pdf`, `.png`). **Không đoán** — block `image` không có tên thì lấy đuôi từ header `Content-Type` sau khi tải, hoặc để `.bin` và ghi vào *Sai lệch*.

`sheet` và `bitable` **không phải media** — chúng là tài liệu riêng, media API không tải được. Ghi token vào *Sai lệch*.

### Lấy URL tạm rồi tải

```text
drive_v1_media_batchGetTmpDownloadUrl({ file_tokens: [...] }, useUAT: true)
```

- Chia lô nhỏ, **≤ 5 token mỗi lần gọi** — Lark giới hạn số token mỗi request.
- URL trả về **có hạn**. Tải ngay trong lượt đó; không gom URL để dành.
- `useUAT: true` như mọi lệnh Lark khác.

```bash
scripts/media/download.sh '<tmp_url>' '<course-slug>/assets/<tên-mới>.<ext>'
```

Script tự tạo thư mục, tải có retry, chặn file rỗng, in số byte. Đừng tự gõ `curl`.

### Quy ước đặt tên

Đặt lại tên theo **vị trí trong cây**, để map một-một với outline. Tên gốc trong Lark trùng lặp, có dấu cách và dấu tiếng Việt — không dùng trực tiếp.

```text
<course-slug>/assets/s<SS>-a<AA>-<slug>.<ext>     media của Activity
<course-slug>/assets/s<SS>-<slug>.<ext>           media của Section
<course-slug>/assets/s<SS>-a<AA>-handout-<slug>.pdf   file dưới `Resource:`, đính kèm Activity
<course-slug>/assets/s<SS>-a<AA>-img<NN>.<ext>    ảnh nhúng trong Document TEXT của Activity
<course-slug>/assets/q-<test>-c<NN>-img<NN>.<ext> ảnh trong đề bài câu hỏi
```

- `<course-slug>` — tên khóa, không dấu, gạch nối: `planning-e2e`.
- `<SS>`, `<AA>` — hai chữ số, lấy đúng số trong tài liệu: Activity `2.1` → `s02-a01`.
- `<slug>` — tên Activity rút gọn, không dấu, gạch nối, tối đa ~50 ký tự.
- `<NN>` — số thứ tự ảnh trong Activity, đếm từ 01.
- `<test>` — bài test chứa câu hỏi: `final`, `mid`, `section<SS>` (Section Test), `s<SS>-a<AA>-t<TT>` (Quiz trong Tab). `c<NN>` là số `Câu <n>.`; `img<NN>` đếm từ 01 trong câu đó.

Ví dụ thật từ tài liệu mẫu:

| `file.name` gốc | token | Tên mới |
|---|---|---|
| `Chapter 1 - Act 1.1 - Ver2.0.mp4` | `Mrv4bY1Jmoo…gfe` | `s01-a01-planning-e2e-va-hanh-trinh-khoa-hoc.mp4` |
| `Chapter 1 - Act 1.2 - Ver 2.0.mp4` | `BIskbgfqHo5…gZe` | `s01-a02-nhung-thuat-ngu-can-thong-nhat.mp4` |
| `Chapter 1 - Act 1.3 - Ver2.0.mp4` | `ZIAKbE5laoP…gzc` | `s01-a03-planning-bat-dau-tu-dau.mp4` |
| `Chapter 2.mp4` | `VfYmbZFPtoV…gFe` | `s02-a01-nam-tang-tu-company-strategy-den-pl.mp4` |

Dòng cuối là ví dụ cho một quy tắc: tên gốc `Chapter 2.mp4` nghe như media cấp Section, nhưng block của nó nằm **sau `heading3` "2.1 Activity"**, nên nó thuộc Activity 2.1. **Vị trí trong cây quyết định, không phải tên file.**

### Ghi manifest

Mọi file tải về phải có một dòng trong bảng *Media* của `outline.md`: token, tên gốc, tên mới, đường dẫn, số byte. Đây là bằng chứng đã tải thật; thiếu dòng nào thì coi như chưa tải.

### Bảng lỗi

| Hiện tượng | Xử lý |
|---|---|
| không có tool `drive_v1_media_batchGetTmpDownloadUrl` | xem mục dưới |
| URL trả về rỗng cho một token | ghi token + tên gốc vào *Sai lệch*, tải tiếp các file khác. Không dừng cả bước |
| tải về 0 byte | `download.sh` báo lỗi. Thử lại một lần; vẫn lỗi thì ghi vào *Sai lệch* |
| `403` khi tải | URL tạm đã hết hạn. Lấy URL mới cho token đó rồi tải lại ngay |
| file rất lớn, tải lâu | cứ tải, đừng bỏ. Nói trước cho người dùng biết là đang tải video |

### Thiếu tool tải media

Tool `drive.v1.media.batchGetTmpDownloadUrl` phải có trong danh sách `-t` của server `lark` trong `.mcp.json`. Không có thì bước 2 **không thể chạy** — và không có cách nào lách.

Nói với người dùng đúng ba việc, rồi **kết thúc lượt**:

1. Thêm `drive.v1.media.batchGetTmpDownloadUrl` vào `-t` của server `lark` trong `.mcp.json`.
2. Khởi động lại Claude Code để tiến trình `lark-mcp` nạp tool mới.
3. Đăng nhập Lark lại — token nằm trong RAM tiến trình cũ nên restart là mất.

Không tự bỏ qua bước media để "làm tiếp phần còn lại": outline thiếu media là outline sai, người dùng duyệt trên dữ liệu thiếu.
