# Bảy loại câu hỏi — nhãn Lark → plan JSON

Dùng ở `SKILL.md` bước 7.1, lúc soạn `<course-slug>/work/questions-<test>.json`.

Chỉ đọc phần của loại đang soạn. Phần bất biến của payload (`question_topic_id`, `question_filter`, `tags`…) do `create-question.sh` tự thêm — dưới đây chỉ là các trường phải viết trong plan.

## Ba hình dạng plan

Bảy loại dùng **ba** hình dạng khác nhau. Khai nhầm trường là script dừng ngay.

| Trường | Loại dùng |
|---|---|
| `.answers` | `One Choice` · `Multiple Choice` · `True / False` |
| `.matchings` | `Matching` |
| `.blanks` (+ `.distractors` cấp câu hỏi cho Drag & Drop) | `Select Word` · `Fill Word` · `Drag & Drop` |

Bốn trường chung cho **mọi** loại:

| Trường | Giá trị |
|---|---|
| `n` | số trong nhãn `Câu <n>.` — là state key, **không đánh lại** |
| `content` | đề bài sau dấu chấm, bọc `<p>…</p>` |
| `qtype` | **chép nguyên văn** nhãn `Question Type:` |
| `layout` | **chép nguyên văn** nhãn `Question Layout:` |

`solution` là trường **tùy chọn**, dùng được cho mọi loại — lấy từ nhãn `Giải thích:`, bọc `<p>…</p>`. Không có nhãn thì bỏ hẳn trường, script giữ `""` của `QUESTION_CFG`.

`images` là trường **tùy chọn**, dùng được cho mọi loại — mảng đường dẫn ảnh của đề bài, đúng thứ tự block trong tài liệu:

```json
{ "n": 1, "content": "<p>Theo bài học, …?</p>",
  "images": ["<course-slug>/assets/q-section01-c01-img01.png",
             "<course-slug>/assets/q-section01-c01-img02.png"],
  "qtype": "One Choice", "layout": "One column", "answers": [ … ] }
```

Script tra `resource_id` trong manifest rồi nối vào sau đề bài. Thẻ giống Document TEXT, chỉ khác kích thước: mặc định `width="836" height="428"` (`QUESTION_IMAGE_WIDTH` / `QUESTION_IMAGE_HEIGHT` trong `scripts/config.sh`):

```html
<p>Theo bài học, …?</p><img src="PRESIGN_URL" title="q-section01-c01-img01.png" resource_id="…" width="836" height="428">
```

> 🚫 **Không gõ `<img>` vào `content`.** Script chặn. Ảnh phải upload bằng `upload-media.sh --folder-type QUESTION` trước — manifest không có, bị bỏ qua, hoặc `folder_type` khác `QUESTION` thì script dừng trước khi gọi API. Câu hỏi tạo rồi không sửa được, mất ảnh là mất vĩnh viễn.

### `qtype` — chép nguyên văn, bảy nhãn

| Nhãn Lark | enum API |
|---|---|
| `One Choice` | `ONE_CHOICE` |
| `Multiple Choice` | `MULTIPLE_CHOICE` |
| `True / False` | `TRUE_FALSE` |
| `Matching` | `MATCHING` |
| `Select Word` | `SELECT_WORD` |
| `Fill Word` | `FILL_WORD` |
| `Drag & Drop` | `DRAG_DROP` |

Script nhận cả hai cột (bỏ hoa thường và ký tự không phải chữ cái rồi mới khớp), nhưng plan **viết nguyên văn cột trái** — để đối chiếu với tài liệu được bằng mắt.

> 🚫 **Không khai `display_type`** cho bất kỳ loại nào. `One column` → `HORIZONTAL`, `Two column` → `VERTICAL` là cặp **ngược với trực giác**; quy đổi làm ở một chỗ duy nhất trong script.

## Ô trống — đọc trước khi soạn `Select Word` / `Fill Word` / `Drag & Drop`

Tài liệu Lark đánh ô trống trong đề bài là `[1]`, `[2]`, `[3]`… Plan viết mỗi ô là **`{{blank}}`** trong `content`, theo đúng thứ tự.

`create-question.sh` thay mỗi `{{blank}}` bằng:

```html
<span id="4a95156d-fb33-4438-aca9-a22744d51aae" class="question-content-tag" contenteditable="false">[_______]</span>
```

Backend đếm ô trống bằng regex khớp **UUID v4 chữ thường**. `id` dạng `"blank-1"`, UUID chữ HOA, hay UUID không phải v4 đều **không được đếm**.

> 🚫 **Không tự gõ thẻ `<span>` vào `content`.** Script sinh UUID và tự kiểm lại trước khi gửi. Gõ tay là mất lớp kiểm đó.
>
> ⚠️ **Bẫy im lặng:** với `DRAG_DROP`, nếu số ô trống đếm được = 0 thì server vẫn trả `201` nhưng **ép toàn bộ đáp án thành `is_correct: false`** → câu hỏi không bao giờ chấm đúng, không có thông báo lỗi nào. Script chặn trước bằng hai cửa: số `{{blank}}` phải khớp số phần tử `.blanks`, và UUID sinh ra phải đúng v4 chữ thường.

**Số `{{blank}}` trong `content` phải bằng đúng số phần tử `.blanks`**, và thứ tự xuất hiện trong `content` = thứ tự phần tử trong mảng. Không khớp thì script dừng.

## `answer_position` — script tự đánh, plan không khai

| Loại | Quy tắc |
|---|---|
| `One Choice` · `Multiple Choice` · `True / False` | đánh từ 1 theo đúng thứ tự `.answers` trong file |
| `Matching` | số thứ tự của cặp trong `.matchings` |
| `Select Word` · `Fill Word` · `Drag & Drop` | số thứ tự của ô trống mà đáp án đó thuộc về |

---

## 1 · `One Choice` · `Multiple Choice` · `True / False`

Giữ nguyên như trước, không đổi gì.

```json
{ "n": 1,
  "qtype": "One Choice",
  "layout": "One column",
  "content": "<p>Nguyên nhân chính khiến doanh thu tháng 9 giảm?</p>",
  "solution": "<p>Tỷ lệ chuyển đổi rơi từ 2,7% xuống 1,9%.</p>",
  "answers": [
    { "answer": "Tỷ lệ chuyển đổi giảm", "is_correct": true },
    { "answer": "Lượt xem giảm mạnh",    "is_correct": false },
    { "answer": "Giá trị đơn giảm",      "is_correct": false }
  ] }
```

`.answers` theo **đúng thứ tự tài liệu viết**: `Đáp án đúng:` trước, rồi `Đáp án nhiễu:`. Cả ba loại dùng chung đúng hai nhãn đó — True / False **không** có nhãn riêng.

| Loại | Ràng buộc script kiểm |
|---|---|
| `One Choice` | đúng 1 đáp án đúng, tổng ≥ 2 |
| `Multiple Choice` | từ 2 đáp án đúng, tổng ≥ 2 |
| `True / False` | đúng 2 đáp án tổng cộng, 1 đúng |

## 2 · `Matching` — ghép cặp

Loại duy nhất **không gửi `answers`**; server ép `answers = undefined` khi `qType = MATCHING`.

Nhãn Lark: `Cặp ghép:` → mỗi block con là một cặp, hai vế ngăn bằng `→` (hoặc `->`).

```json
{ "n": 4,
  "qtype": "Matching",
  "layout": "One column",
  "content": "<p>Ghép mỗi chỉ số với điều nó phản ánh.</p>",
  "solution": "<p>Ba chỉ số nằm trên các chặng khác nhau của phễu.</p>",
  "matchings": [
    { "left": "Tỷ lệ chuyển đổi",   "right": "Mức độ thuyết phục của trang sản phẩm" },
    { "left": "Lượt xem sản phẩm",  "right": "Hiệu quả quảng cáo và thứ hạng tìm kiếm" },
    { "left": "Đánh giá trung bình","right": "Chất lượng trải nghiệm sau mua" }
  ] }
```

Script dựng `question_matchings: [{content: left, answer: {is_correct: true, answer: right, answer_position: <số cặp>}}]`.

| Quy tắc | Chi tiết |
|---|---|
| Số cặp | **≥ 2**. Rỗng/thiếu → `422 · MATCHING question must contain only correct answers` |
| `is_correct` | **mọi cặp đều `true`** — script tự đặt, plan không khai |
| Đáp án nhiễu | **không có.** Khai `.distractors` hay `.answers` là script dừng |
| Nội dung | Hai cặp có vế phải **trùng chữ** được chấp nhận cho nhau — tránh mô tả trùng nghĩa |

## 3 · `Select Word` — chọn từ cho mỗi ô trống

Nhãn Lark: `Ô trống <k>:` → bên trong là `Đáp án đúng:` và `Đáp án nhiễu:` **của riêng ô đó**.

```json
{ "n": 5,
  "qtype": "Select Word",
  "layout": "Two column",
  "content": "<p>doanh thu = lượt xem × {{blank}} × {{blank}}.</p>",
  "blanks": [
    { "correct": ["tỷ lệ chuyển đổi"],       "distractors": ["tỷ lệ hoàn đơn", "tỷ lệ nhấp quảng cáo"] },
    { "correct": ["giá trị đơn trung bình"], "distractors": ["chi phí quảng cáo"] }
  ] }
```

| Quy tắc | Chi tiết |
|---|---|
| Mỗi ô | **≥ 1 `correct` và ≥ 1 `distractors`**. Thiếu đáp án đúng → `422 · SELECT_WORD question must contain at least one correct answer in each answer position` |
| Nhiều `correct` một ô | được — học viên chọn trúng một trong số đó là đúng ô ấy |
| `.distractors` cấp câu hỏi | **sai** — nhiễu của loại này nằm trong từng ô |
| Chấm điểm | phải trả lời đủ mọi ô |

## 4 · `Fill Word` — học viên tự gõ

Cùng cơ chế ô trống, **không có nhiễu**. Mỗi phần tử `correct` là một cách viết được chấp nhận cho ô đó.

```json
{ "n": 6,
  "qtype": "Fill Word",
  "layout": "One column",
  "content": "<p>Tỷ lệ chuyển đổi tháng 9 là {{blank}} phần trăm.</p>",
  "blanks": [ { "correct": ["1,9", "1.9"] } ] }
```

| Quy tắc | Chi tiết |
|---|---|
| `distractors` | **không được khai**, cả trong ô lẫn cấp câu hỏi. Một đáp án `false` → `422 · FILL_WORD question must only correct answers in each answer position` |
| Chấm điểm | so chuỗi sau chuẩn hóa: **chữ thường, trim, gộp khoảng trắng**. Không cần thêm biến thể hoa/thường |
| Biến thể nên có | có dấu / không dấu, dấu thập phân (`1,9` ↔ `1.9`), viết tắt hợp lệ |
| Tài liệu khai bao nhiêu | **chép đúng bấy nhiêu** — không tự nghĩ thêm biến thể ngoài tài liệu |

## 5 · `Drag & Drop` — kéo thả

Mỗi ô **đúng một** đáp án; mảnh nhiễu là **rổ dùng chung**, nằm ở `.distractors` **cấp câu hỏi**.

```json
{ "n": 7,
  "qtype": "Drag & Drop",
  "layout": "One column",
  "content": "<p>Thứ tự xử lý: đầu tiên {{blank}}, sau đó {{blank}}, cuối cùng {{blank}}.</p>",
  "blanks": [
    { "correct": ["Dừng nhà vận chuyển mới"] },
    { "correct": ["Liên hệ khách đánh giá xấu"] },
    { "correct": ["Theo dõi tỷ lệ chuyển đổi 2 tuần"] }
  ],
  "distractors": ["Tăng gấp đôi ngân sách quảng cáo", "Giảm giá toàn bộ 20%"] }
```

**Server ghi đè `is_correct` theo thứ tự phần tử trong mảng `answers`** — giá trị gửi lên bị bỏ qua hoàn toàn. Gọi `N` = số ô trống:

- `answers[0] … answers[N-1]` → ép `is_correct: true`, là đáp án của ô 1…N **theo đúng thứ tự mảng**
- `answers[N]` trở đi → ép `is_correct: false`, là nhiễu

Script tự xếp N đáp án đúng lên đầu mảng theo thứ tự `.blanks` rồi mới tới `.distractors`, nên plan **không phải lo thứ tự** — chỉ cần viết `.blanks` đúng thứ tự ô trống.

| Quy tắc | Chi tiết |
|---|---|
| Mỗi ô | **đúng 1** phần tử `correct`. Hai phần tử là script dừng |
| `.distractors` | **≥ 1**, ở cấp câu hỏi. Ít hơn N đáp án → `422 · DRAG_DROP question must only one correct answer in each answer position` |
| `distractors` trong ô | **sai** — khác hẳn `Select Word` |
| Nội dung | hai ô có đáp án **trùng chữ** thì đổi chỗ vẫn tính đúng — tránh nếu thứ tự giữa chúng là điểm cần kiểm tra |

---

## Ba loại ô trống — chỗ dễ nhầm nhất

| | `distractors` nằm ở đâu | Mỗi ô mấy `correct` |
|---|---|---|
| `Select Word` | **trong** mỗi phần tử `.blanks` | 1 hoặc nhiều |
| `Fill Word` | **không có** | nhiều = nhiều cách viết được chấp nhận |
| `Drag & Drop` | **ngoài**, `.distractors` cấp câu hỏi | **đúng 1** |

## Script kiểm gì trước khi gọi API

Mọi cửa dưới đây chạy cho **cả `--dry-run` lẫn chạy thật**, và dừng trước khi có request nào được gửi:

1. `qtype` thuộc bảy loại · `layout` đúng hai nhãn · không khai `display_type`
2. Trường khai đúng hình dạng của loại (`.answers` / `.matchings` / `.blanks`)
3. `{{blank}}` chỉ xuất hiện ở ba loại có ô trống, và số lượng khớp `.blanks`
4. Ràng buộc riêng từng loại — số đáp án đúng, số cặp, nhiễu nằm đúng chỗ
5. Không có đề bài rỗng hay chuỗi đáp án rỗng ở bất kỳ hình dạng nào

> 🚫 **Câu hỏi tạo rồi không xóa được bằng bộ script này.** Sai thì người dùng phải vào giao diện dọn tay — `--dry-run` là lần cuối chặn được.
