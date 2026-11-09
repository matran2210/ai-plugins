# Chất lượng nội dung: chia Activity / Tab / Document

Khung mặc định khi người dùng giao "tự chia và hoàn thiện Section". Người dùng nói khác thì theo người dùng.

## Chia Activity trong một Section

| Tiêu chí | Chuẩn |
|---|---|
| Số Activity | 4–6 cho một Section thường |
| Nội dung mỗi Activity | Một năng lực học viên **làm được** sau bài, không phải một chủ đề chung chung |
| `duration` | 20–50 phút; tổng cả Section 150–220 phút |
| Thứ tự | Kiến thức nền → công cụ/quy trình → tình huống nâng cao → thực hành tổng hợp → Quiz |
| Activity cuối | Bài thực hành tổng hợp và/hoặc Quiz củng cố toàn Section |

*Ngoại lệ hợp lệ:* nếu hai Section là một cặp "nền tảng + thực hành" (Section sau chính là phần thực hành của Section trước), Section nền tảng có thể chỉ 3 Activity — đừng nhân đôi bài thực hành ở cả hai.

## Chia Tab trong một Activity

| Loại Activity | Tab chuẩn |
|---|---|
| Bài lý thuyết/quy trình | 2 Tab: `Nội dung bài học` + `Ghi nhớ & Thực hành` |
| Bài thực hành tổng hợp | 2 Tab: `Đề bài thực hành` + `Đáp án gợi ý & Tiêu chí đánh giá` |
| Bài Quiz | 1 Tab: `Kiểm tra cuối Section {n}` |

Tối đa 3 Tab. Tab phải khác nhau về **vai trò** (học / luyện / kiểm tra), không phải chỉ để cắt một bài dài thành hai nửa.

## Chia Document trong một Tab

| Tab | Số Document | Nội dung |
|---|---|---|
| `Nội dung bài học` | 1–2 `TEXT` | Doc 1: khái niệm/nguyên tắc. Doc 2: quy trình + ví dụ có số liệu |
| `Ghi nhớ & Thực hành` | 1 `TEXT` | Ghi nhớ nhanh + checklist + bài tập + tiêu chí đánh giá |
| `Đề bài thực hành` | 1 `TEXT` | Bối cảnh + dữ liệu + các yêu cầu |
| `Đáp án gợi ý & Tiêu chí đánh giá` | 1 `TEXT` | Lời giải từng bước + rubric |
| `Kiểm tra cuối Section {n}` | 1 `TEXT` + 1 `QUIZ` | Doc `TEXT` hướng dẫn làm bài, đặt **trước** Doc `QUIZ` |

Document xếp theo thứ tự tạo — viết đúng thứ tự muốn học viên đọc.

## Khung HTML tối thiểu của một Document nội dung

```html
<h2>Tên bài học</h2>
<p>Mục tiêu: sau bài này học viên làm được gì.</p>
<h3>1. Khái niệm hoặc nguyên tắc</h3>
<p>Giải thích đúng ngữ cảnh nghiệp vụ.</p>
<h3>2. Quy trình thực hiện</h3>
<ol><li>Bước 1.</li><li>Bước 2.</li></ol>
<h3>3. Ví dụ có số liệu</h3>
<table>…</table>
<h3>4. Rủi ro / lỗi thường gặp</h3>
<ul><li>Dấu hiệu, tác động, cách phòng.</li></ul>
<h3>5. Thực hành</h3>
<p>Bài tập hoặc checklist áp dụng ngay.</p>
```

Độ dài mỗi Document `TEXT`: **1.500–4.000 ký tự HTML**. Ngắn hơn là sơ sài; dài hơn thì tách hai Document.

Yêu cầu chất lượng: có mục tiêu bài học, có ví dụ **kèm số liệu cụ thể**, có bảng khi so sánh, có phần thực hành. Không để lại placeholder (`Nội dung bài 1`, `lorem`).

## Viết Learning Outcome

Dùng động từ hành vi — "tính được", "phân biệt được", "xử lý được". Tránh "hiểu về", "nắm được": outcome dạng đó không kiểm tra được. Mỗi Section nên 2–4 outcome, mỗi cái là một năng lực cụ thể, đo được.

## Bài test

Bước dựng cấu trúc (`SKILL.md` bước 6) **không tạo bài test nào**. Bài test, setting và câu hỏi đều ở bước 7; không tạo Question Topic.

| Loại | Phạm vi | Đề xuất mặc định |
|---|---|---|
| Document `QUIZ` | Trong một Tab của Activity Quiz | Section nào cũng nên có, đặt ở Activity cuối |
| `SECTION_TEST` | Cuối một Section | Mỗi Section một bài |
| `MID_TERM_TEST` | Cả khóa | Khóa > 4 Section: 1 bài, đặt sau khi đi hết nửa số Section. Khóa ngắn hơn: không cần |
| `FINAL_TEST` | Cả khóa | 1 bài, cuối khóa |

Số lượng Midterm/Final phải được người dùng chốt ở bước chốt dàn ý — đây chỉ là mức đề xuất.

Doc `TEXT` hướng dẫn làm bài đứng trước Doc `QUIZ` nên ghi: phạm vi ôn tập, ngưỡng đạt, điểm dễ mất.
