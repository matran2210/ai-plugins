# `outline.md` — đặc tả

Dùng ở `SKILL.md` bước 3. Ghi ra `<course-slug>/outline.md` — cùng thư mục với `assets/`, `state.json` và mọi thứ khác của khóa này.

File này là **hợp đồng với người dùng**: họ duyệt cái gì thì bước 6 và 7 tạo đúng cái đó. Nên nó phải chứa đủ để họ phát hiện sai mà không cần mở tài liệu Lark, và **không được chứa thứ gì không có trong tài liệu**.

Bảy mục, đúng thứ tự này. Không thêm mục, không bỏ mục — mục nào rỗng thì ghi "không có".

## 1. Nguồn

Để đối chiếu và để biết bản outline này đọc từ phiên bản nào của tài liệu.

```markdown
## 1. Nguồn

| | |
|---|---|
| Link | https://<tổ-chức>.larksuite.com/wiki/<node_token> |
| Tiêu đề tài liệu | TEST - Khóa học Planning E2E |
| `document_id` | <obj_token> |
| Tài liệu sửa lần cuối | 1786613700 |
| Số block đọc được | 60 |
```

`document_id` là `obj_token` lấy từ `wiki_v2_space_getNode`, không phải token trong URL.

## 2. Thông tin khóa học

Nguyên văn sáu nhãn của vùng *Thông tin khóa học*. Không rút gọn, không viết lại. Đây là thứ sẽ đi thẳng vào `POST /courses` ở bước 5 — người dùng duyệt ở đây là duyệt luôn cái sẽ lên LMS.

```markdown
## 2. Thông tin khóa học

| Nhãn | Tài liệu ghi | Sẽ gửi lên |
|---|---|---|
| `Thumbnail:` | bia-khoa-hoc.png (412 KB) | `PUT /courses/image` ở bước 5.2 |
| `Course Resource:` | giao-trinh.pdf · bai-tap.xlsx | `POST /courses/<id>/add-resource` ở bước 5.4 |
| `Name:` | Planning E2E | `name` |
| `Course Category:` | Kỹ năng nghiệp vụ | `course_category_id` — search theo tên |
| `Type:` | NORMAL_COURSE | `course_type` |
| `Passpoint:` | 80 | `pass_point` |
| `Điểm thành phần:` | Tiến độ 10 · Section Test 20 · Mid 30 · Final 40 | `setting` |

**Description:** Khóa học giúp học viên hiểu và áp dụng thống nhất quy trình Planning E2E …
```

Nhãn nào tài liệu bỏ trống thì ghi **"không có"**, gắn mã SL, và ghi rõ giá trị mặc định sẽ dùng thay. Đó là con số duy nhất trong outline không đến từ tài liệu.

`Thumbnail:` ghi **tên file đã tải về và dung lượng**, để người dùng biết ảnh bìa nào sắp lên. Không có nhãn hoặc nhãn không kèm ảnh thì ghi **"không có — khóa sẽ không có ảnh bìa"** kèm mã SL; đó là trạng thái hợp lệ, không phải lỗi. Ảnh bìa cũng phải có một dòng ở mục 4 như mọi media khác, với cột *Node* ghi `Ảnh bìa khóa học`.

`Course Resource:` liệt kê **tên mọi file**, ngăn bằng ` · `. Không có nhãn hoặc nhãn không có file thì ghi **"không có"** kèm mã SL. Mỗi file cũng phải có một dòng ở mục 4, cột *Node* ghi `Tài liệu khóa học`. Đừng gộp chung với `Resource:` của Activity — hai thứ đính vào hai chỗ khác nhau, người dùng cần soát riêng.

## 3. Cây sẽ tạo trên LMS

Cột trái là tài liệu, cột phải là node LMS. Đây là mục người dùng soát kỹ nhất.

```markdown
## 3. Cây sẽ tạo trên LMS

Đếm thực tế từ tài liệu: **2 Section — 4 Activity — 3 LO con — 1 Section Test — 1 Final Test**.

### Section 1 — Giới thiệu khóa học
- Mô tả: Giúp học viên hiểu mục tiêu và phạm vi khóa học …  ⚠️ SL-05
- LO to: **Hiểu tổng quan Planning E2E** — Giúp học viên nắm mục tiêu và phạm vi.
- LO con:
  | # | Nội dung | Activity dùng |
  |---|---|---|
  | 1 | Xác định được mục tiêu, phạm vi, các vai trò liên quan. | 1.1, 1.2 |
  | 2 | Giải thích được ý nghĩa của các thuật ngữ cốt lõi. | **không ai dùng** ⚠️ SL-09 |
  | 3 | Phân loại được các nhóm đầu vào cần có. | 1.1 |

| # | Activity | Time | Type of Activity | LO | Tab sẽ tạo | Media |
|---|---|---|---|---|---|---|
| 1.1 | Planning E2E và hành trình khóa học | `~1 phút 30 giây` → **2 phút** | (trống) → **TEXT** ⚠️ SL-11 | 1, 3 | `Tab 1:` → 1 tab (Text) | resource `s01-a01-handout.pdf` |
| 1.2 | Những thuật ngữ cần thống nhất | `~2 phút` → **2 phút** | `Video` → **VIDEO** | 1 | `Tab 1:` → 1 tab (Video, Quiz) | `s01-a02-thuat-ngu.mp4` |
| 1.3 | Tổng kết chương | `10 phút` | `Reading` → **TEXT** ⚠️ SL-15 | 3 | `Tab 1:` → 1 tab (Text) | — |

- Section Test: **có** — `Name: Kiểm tra tổng quan` · 0 câu hỏi trong tài liệu
```

Quy tắc của mục này:

- **Tên Section và Activity lấy từ nhãn `Name:` bên dưới heading**, nguyên văn. Heading `Section 1` / `Activity 2` chỉ là nhãn loại node + số thứ tự, không phải tên; không có `Name:` thì mới lấy phần sau dấu hai chấm của heading. Không đánh số lại, không sửa chính tả.
- **Bảng LO con phải có cột *Activity dùng*.** Một LO con dùng ở nhiều Activity là bình thường; LO không Activity nào dùng thì ghi rõ và gắn mã SL — nó vẫn được tạo.
- Cột **LO** của bảng Activity ghi đúng các **số** trong dòng `Learning Outcome: 1, 3`. Trỏ tới số không tồn tại thì gắn mã SL.
- Cột **Time** ghi nguyên văn kèm số phút sẽ gửi. Không khai thì ghi *mặc định 30 phút* và gắn mã SL.
- Cột **Type of Activity** ghi nguyên văn giá trị tài liệu kèm kết quả quy đổi. Chỉ ba giá trị hợp lệ: **`TEXT` · `VIDEO` · `QUIZ`**. Giá trị khác — kể cả nghe có vẻ đúng như `Reading` hay `Test` — quy về `TEXT` và **gắn mã SL**; đừng tự map cho khớp.
- Cột *Tab sẽ tạo* liệt kê từng `Tab <n>:` kèm Document bên trong. Không có `Tab <n>:` nào thì ghi **không có tab** và gắn mã SL.
- Cuối mỗi Section ghi rõ **có / không Section Test**. Sau hết Section, ghi test cấp khóa (`MID_TERM_TEST`, `FINAL_TEST`) — mỗi bài một dòng kèm **số câu hỏi**; chi tiết ở mục 5.
- Dòng *Đếm thực tế* ở đầu mục là bắt buộc — nó đối chiếu với con số tài liệu khai ở mục 2.

## 4. Media đã tải

Một dòng cho mỗi file. Thiếu dòng nào thì coi như file đó chưa tải.

```markdown
## 4. Media đã tải

Thư mục: `planning-e2e/assets/`

| Node | Tên gốc trong Lark | `file_token` | Tên mới | Byte |
|---|---|---|---|---|
| Activity 1.1 › Tab 1 › Video | Chapter 1 - Act 1.1 - Ver2.0.mp4 | Mrv4bY1Jmoo…gfe | s01-a01-planning-e2e-va-hanh-trinh-khoa-hoc.mp4 | 24 118 402 |
| Activity 1.1 › Resource (đính kèm) | Handout chương 1.pdf | Cxk2bVn8Uoq…gRb | s01-a01-handout-planning-e2e-chapter-1.pdf | 1 204 663 |
| Activity 1.2 › Tab 1 › Text 1 (ảnh nhúng) | image.png | Qwe7bLp3Ioz…gTa | s01-a02-img01.png | 88 214 |
| Activity 2.1 › Tab 1 › Video | Chapter 2.mp4 | VfYmbZFPtoV…gFe | s02-a01-nam-tang-tu-company-strategy-den-pl.mp4 | 58 903 117 |

**Chưa upload lên LMS** — mới tải về máy. Sẽ upload ở bước 5 sau khi bạn duyệt outline này; video thành Document riêng, ảnh nhúng vào bài học.
```

Cột **Node** phải ghi rõ **chỗ gắn**, không chỉ tên Activity — đó là thứ người dùng cần soát:

| Media nằm dưới nhãn | Ghi ở cột Node |
|---|---|
| `Video:` trong Tab | `Activity 1.1 › Tab 1 › Video` |
| nội dung một `Text:` | `Activity 1.1 › Tab 1 › Text 1 (ảnh nhúng)` |
| `Resource:` của Activity | `Activity 1.1 › Resource (đính kèm)` |

**Chỉ file dưới `Resource:` mới là file đính kèm Activity.** Ảnh nằm giữa nội dung một `Text:` thuộc chính Document TEXT đó — đừng liệt kê nó như resource của Activity.

Câu cuối là **bắt buộc**, không được bỏ: lúc bạn duyệt outline thì media vẫn chỉ nằm ở local. Nêu luôn là bước 5 sẽ upload, để người dùng không tưởng phải tự làm tay.

Không tải được file nào thì vẫn phải có dòng cho nó, ghi rõ `LỖI` ở cột Byte và trỏ mã SL — vì Activity đó sẽ thiếu media.

## 5. Bài test và câu hỏi sẽ tạo

Một khối `###` cho mỗi bài test tài liệu định nghĩa: `Quiz:` bên trong một `Tab <n>:`, hoặc heading `Section Test` / `Midterm Test` / `Final Test`. Tên bài lấy ở nhãn `Name:` dưới heading.

```markdown
## 5. Bài test và câu hỏi sẽ tạo

### Bài test 1 — Final Test
- Tên: Kiểm tra cuối khóa Market Research
- Loại LMS: `FINAL_TEST`
- Setting: `Type of Test: Multiple Choice` → `MULTIPLE_CHOICE` · `Test Mode: Tutor` → `is_tutor: true`
  · `Graded Assignment: Yes` → `is_graded: true` · `Pass Point: 80%` → `80`
  · `Grading Preference: After all questions` → `AFTER_ALL_QUESTIONS` · `Attempt: 2` → `is_limited: true` + `limit_count: 2`
- Câu hỏi: **3 câu** · điểm chia đều `33.33` mỗi câu (tổng 99.99)

| # | Đề bài | Type | Layout | Đáp án |
|---|---|---|---|---|
| 1 | Market Research được định nghĩa như thế nào trong tài liệu? | One Choice → `ONE_CHOICE` | One column → `HORIZONTAL` | 1 đúng / 3 nhiễu |
| 2 | Market Research đứng ở đâu trong quy trình Planning? | Multiple Choice → `MULTIPLE_CHOICE` | One column → `HORIZONTAL` | 2 đúng / 2 nhiễu |
| 3 | Trong mô hình Market Research, cách phân chia Internal và External nào đúng? | True / False → `TRUE_FALSE` | Two column → `VERTICAL` | 1 đúng / 1 sai |
| 4 | Ghép mỗi nguồn dữ liệu với nhóm Internal hay External | Matching → `MATCHING` | One column → `HORIZONTAL` | 4 cặp ghép |
| 5 | Điền vào công thức quy mô thị trường | Select Word → `SELECT_WORD` | Two column → `VERTICAL` | 2 ô trống · ô 1: 1 đúng/2 nhiễu · ô 2: 1 đúng/1 nhiễu |
| 6 | Tỷ lệ thâm nhập thị trường mục tiêu là bao nhiêu phần trăm | Fill Word → `FILL_WORD` | One column → `HORIZONTAL` | 1 ô trống · 2 cách viết được chấp nhận |
| 7 | Sắp xếp đúng thứ tự bốn bước nghiên cứu thị trường | Drag & Drop → `DRAG_DROP` | One column → `HORIZONTAL` | 4 ô trống · 2 mảnh nhiễu chung |

### Bài test 2 — Section Test của Section 1
- Tên: Bài kiểm tra Section 1 – Thiết lập gian hàng Shopee
- Loại LMS: `SECTION_TEST` của Section 1
- Setting: tài liệu không khai → giữ mặc định `QUIZ_CFG` ⚠️ SL-17
- Câu hỏi: **không có** — tài liệu chưa viết câu nào; tạo khung rỗng
```

Quy tắc của mục này:

- **Dòng *Setting* ghi nguyên văn nhãn kèm giá trị sẽ gửi**, đúng sáu nhãn. Nhãn nào tài liệu không khai thì ghi *giữ mặc định* và gắn mã SL — người dùng cần biết bài test sẽ ra với cấu hình nào.
- **Bảng câu hỏi chỉ ghi đề bài và ĐẾM đáp án**, không chép nội dung đáp án và **tuyệt đối không ghi đáp án nào đúng**. Outline là file nằm trong dự án, người học có thể đọc được. Với `MATCHING` thì đếm **số cặp**, đừng ghi cặp nào ghép với cặp nào.
- **Loại có ô trống ghi số ô trước, rồi mới tới đáp án.** `SELECT_WORD` đếm đúng/nhiễu **theo từng ô** — đó là chỗ tài liệu hay thiếu nhiễu ở một ô mà nhìn tổng thể không thấy. `DRAG_DROP` ghi số ô và số mảnh nhiễu chung. Số ô trống phải khớp số ô `[k]` trong đề bài tài liệu viết; lệch thì gắn mã SL ngay tại dòng đó.
- Cột *Type* và *Layout* ghi nguyên văn tài liệu kèm giá trị API sau mũi tên.
- Số đáp án không khớp `Question Type:`, hoặc nhãn dùng sai loại (`Đáp án nhiễu:` trong câu `Matching`, `Cặp ghép:` trong câu `One Choice`…), thì gắn mã SL ngay tại dòng đó — bước 7 sẽ dừng, người dùng cần biết trước khi duyệt.
- Bài test không có câu hỏi nào trong tài liệu → ghi **"không có — tạo khung rỗng"**. Đó là trạng thái hợp lệ, không phải lỗi.
- Ghi thêm **điểm mỗi câu**: tài liệu không khai thì ghi *chia đều* kèm số thực tế (3 câu → `33.33` mỗi câu). Mọi câu cùng một số; tổng không được vượt 100.
- **Không tạo Question Topic trong mọi trường hợp.**

## 6. Sai lệch và thiếu hụt

Mục quan trọng nhất và là mục dễ bị bỏ nhất. Đánh mã `SL-01`, `SL-02`… để mục 3 và 5 trỏ tới.

Ghi **mọi** chỗ cấu trúc hoặc nội dung bài học tự mâu thuẫn, bị cắt hay không đọc được. Không kiểm tra sai lệch về câu hỏi vì câu hỏi nằm ngoài phạm vi tạo tự động.

```markdown
## 6. Sai lệch và thiếu hụt

| Mã | Chỗ | Tài liệu ghi | Thực tế đọc được | Xử lý đề xuất |
|---|---|---|---|---|
| SL-01 | Cấu trúc khóa | 07 Section — 19 Activity | 2 Section — 4 Activity | Tạo theo thực tế. **Không sinh thêm cho đủ** |
| SL-05 | `Description:` Section 1 | — | bị cắt giữa chữ: "…và ba chu kỳ Planni" | Bạn bổ sung phần thiếu |
| SL-09 | LO con số 2 | — | không Activity nào tham chiếu | Vẫn tạo. Muốn gắn thì bạn thêm số 2 vào dòng `Learning Outcome:` của Activity |
| SL-11 | `Type of Activity:` Activity 1.1 | — | bỏ trống | Gửi `TEXT`. Bạn điền `Text`/`Video`/`Quiz` vào tài liệu |
| SL-15 | `Type of Activity:` Activity 1.3 | "Reading" | không thuộc `TEXT`/`VIDEO`/`QUIZ` | Gửi `TEXT`. Bạn sửa thành một trong ba giá trị hợp lệ |
| SL-12 | `Time:` Activity 1.3 | — | không có nhãn | Gửi mặc định **30 phút** |
| SL-13 | `Passpoint:` | — | bỏ trống | Gửi mặc định **65**. Bạn điền vào tài liệu rồi bảo tôi chạy lại |
| SL-14 | `Course Category:` | "Kỹ năng" | khớp 3 category: *Kỹ năng mềm* · *Kỹ năng bán hàng* · *Kỹ năng vận hành* | **Script sẽ dừng, tôi không chọn hộ.** Bạn chọn một rồi ghi tên đầy đủ vào tài liệu |
| SL-17 | Setting Section Test 1 | — | không khai nhãn nào | Giữ mặc định `QUIZ_CFG`. Muốn khác thì bạn thêm 6 nhãn vào tài liệu |

Cột *Xử lý đề xuất* chỉ được chứa hai loại nội dung: **"tạo theo thực tế"** hoặc **"bạn quyết"**. Không bao giờ là "tôi sẽ tự viết thêm".

## 7. Sẽ tạo mới những gì, và cần bạn xác nhận

Người dùng **không phải cung cấp id nào**. Mục này liệt kê thứ skill sẽ tự tạo, để họ biết trước cái gì sắp xuất hiện trên LMS.

```markdown
## 7. Sẽ tạo mới trên LMS

| Đối tượng | Giá trị | Ghi chú |
|---|---|---|
| Khóa học | `Planning E2E` | `name` lấy nguyên văn trong tài liệu; `code` do BE tự sinh; `status: DRAFT`; category lấy phần tử đầu của danh sách |
| Bài test | `Kiểm tra cuối khóa Market Research` | `FINAL_TEST`, 3 câu hỏi |
| Câu hỏi | 3 câu vào ngân hàng câu hỏi của khóa | **không xóa được** bằng skill — sai thì bạn dọn tay trên giao diện |

Duyệt xong thì trả lời:
1. Outline này đúng chưa — sửa gì thì sửa thẳng vào file rồi bảo tôi đọc lại.
2. Các mục SL cần bạn quyết: SL-04, SL-05, SL-06, SL-07, SL-08.

Tôi **không tạo gì trên LMS** cho tới khi bạn trả lời.
```

Hai lưu ý khi viết mục này:

- Liệt kê đúng những mã SL có *Xử lý đề xuất* là "bạn quyết". Đừng liệt kê hết cho đủ.
- Nêu rõ **tên khóa học và tên các khung bài test sẽ tạo**. Skill không xóa được các đối tượng đã tạo; đây là lần cuối người dùng chặn được một cái tên sai.

## Sau khi xuất file

Nói với người dùng đúng bốn thứ, ngắn gọn, rồi **kết thúc lượt**:

1. Đã ghi `outline.md` ở đâu.
2. Đếm thực tế so với con số tài liệu khai — một dòng.
3. Số file media đã tải và tổng dung lượng.
4. Có bao nhiêu mục SL, và mấy mục cần họ quyết.

Không dán cả outline vào khung chat. Không tóm tắt lại nội dung khóa học. Không bắt đầu bước 4.
