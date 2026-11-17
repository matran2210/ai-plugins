# Hướng dẫn vận hành Course Builder

**Dành cho:** đội vận hành tạo và bổ sung khóa học trên UpBase LMS từ tài liệu Lark.

Tài liệu Lark được xem là đã hoàn chỉnh và sẵn sàng sử dụng. Bạn chọn luồng, gửi link, đăng nhập và duyệt bản dự kiến. Trợ lý AI sẽ đọc tài liệu, xử lý ảnh/video và tạo nội dung trên LMS. Bạn không cần viết mã hay tự chạy lệnh tạo bài học.

## 1. Chọn đúng luồng trước khi bắt đầu

| Nhu cầu | Luồng cần dùng | Cần chuẩn bị |
|---|---|---|
| Tạo một khóa học mới từ đầu | **Gen — AI Gen Course LMS** | Một link tài liệu thiết kế khóa học trên Lark |
| Thêm Section, bài kiểm tra hoặc câu hỏi vào khóa đã có | **Update — AI Update Course LMS** | Link khóa học trên OPS **và** link tài liệu Lark chỉ chứa phần cần thêm |
| Sửa tên, sửa nội dung hoặc xóa phần đã có | Thực hiện trên giao diện OPS theo quyền được cấp | Hai luồng trên không hỗ trợ sửa/xóa nội dung cũ |

Các tên thường gặp:

| Tên trên hệ thống | Hiểu đơn giản |
|---|---|
| Section | Chương/phần của khóa học |
| Activity | Hoạt động hoặc bài học trong một Section |
| Tab | Thẻ nội dung trong một Activity |
| Learning Outcome (LO) | Mục tiêu học tập |
| Quiz / Section Test / Mid Test / Final Test | Kiểm tra trong bài / cuối Section / giữa khóa / cuối khóa |
| `outline.md` | File bản dự kiến để bạn kiểm tra và duyệt **trước khi tạo trên LMS** |
| Staging | Môi trường thử nghiệm |
| Prod / Production | Môi trường sử dụng chính thức |

## 2. Setup lần đầu

Chỉ cần cài đặt ban đầu một lần trên mỗi máy. Khi plugin có bản mới, làm theo mục 7.

### 2.1. Chuẩn bị

| Cần có | Người vận hành cần làm |
|---|---|
| Codex hoặc Claude Code đã cài và đăng nhập được | Chọn ứng dụng đội đang sử dụng; không cần cài cả hai |
| Một thư mục làm việc mở trong ứng dụng | Dùng để lưu bản dự kiến và ảnh/video của khóa học; giữ lại để tiếp tục nếu bị gián đoạn |
| Tài khoản Lark có quyền truy cập tài liệu nguồn | Mở thử link bằng tài khoản của bạn |
| Tài khoản UpBase OPS đúng môi trường, đủ quyền | Cần quyền tạo khóa học, cấu phần học và câu hỏi tương ứng với công việc |

**Không gửi mật khẩu OPS hoặc mã truy cập vào khung chat.** Nhập tài khoản OPS vào hộp thoại đăng nhập riêng.

### 2.2. Cài trên Codex

1. Mở **Terminal** trên máy. Sao chép và chạy lệnh sau; nếu chưa quen Terminal, nhờ IT thực hiện bước này:

   ```bash
   codex plugin marketplace add matran2210/ai-plugins
   ```

2. Đóng và mở lại ứng dụng ChatGPT → Codex.
3. Ở thanh menu bên trái, chọn **Plugins** → tab **Personal**.
4. Tìm **course-builder** và bấm **Install**.
5. Mở thư mục làm việc của bạn trong Codex. Trong khung chat, gõ `/` và chọn một trong hai mục:

   ```text
   /Course Builder: Ai Gen Course Lms
   /Course Builder: Ai Update Course Lms
   ```

Mục đầu để tạo khóa mới; mục sau để thêm nội dung vào khóa đã có.

### 2.3. Cài trên Claude Code

Nếu đội dùng Claude Code, nhập **lần lượt từng dòng** sau vào khung chat của Claude Code:

```text
/plugin marketplace add matran2210/ai-plugins
/plugin install course-builder@lms-plugins
```

Khởi động lại Claude Code, mở thư mục làm việc rồi chọn lệnh tương ứng theo mục 4 hoặc 5.

### 2.4. Cài công cụ hỗ trợ tự động

Máy cần có `bash`, `curl`, `jq`, `openssl`, `node`; Windows cần thêm Git Bash hoặc WSL. Bạn không cần tự tìm và cài từng công cụ: plugin có script kiểm tra và cài phần còn thiếu.

Sau khi cài plugin, gửi trong khung chat:

```text
Dùng setup-course-builder để kiểm tra và cài các công cụ hỗ trợ
còn thiếu trên máy này.
```

Trợ lý chạy script phù hợp với máy của bạn. Trên Windows, script tự cài Git Bash nếu chưa có; nếu đang dùng WSL thì công cụ được cài trong WSL.

- Nếu trình cài yêu cầu quyền quản trị, xác nhận/nhập mật khẩu trực tiếp trên máy.
- Chờ thông báo **ĐÃ SẴN SÀNG**, rồi đóng và mở lại Codex/Claude Code.
- Chạy lại bước này vẫn được; công cụ đã có sẽ được bỏ qua.
- Nếu script báo thiếu quyền cài đặt hoặc không có WinGet trên Windows, làm theo thông báo hoặc nhờ IT hỗ trợ rồi chạy lại.

### 2.5. Setup Lark CLI
Sao chép toàn bộ nội dung sau và gửi cho AI Agent:
Hãy cài đặt Lark CLI bằng lệnh: npm install -g @larksuite/cli Sau đó cài đặt các Lark Skills liên quan bằng lệnh: npx skills add https://github.com/larksuite/cli -y -g Sau khi cài đặt xong, hãy gửi cho tôi đường dẫn cấu hình ứng dụng và hướng dẫn tôi hoàn tất từng bước.
Agent sẽ thực hiện hai công việc:
Cài đặt Lark CLI ở phạm vi global.
Cài bộ Lark Skills để nhận diện và xử lý các tác vụ liên quan Lark.
Lark CLI cần Node.js cùng npm hoặc npx trên máy. Nếu hệ thống chưa có các thành phần này, agent có thể yêu cầu cài đặt trước khi tiếp tục.

## 3. Bắt đầu sử dụng

Sau khi setup xong, chọn **Gen** ở mục 4 nếu tạo khóa mới, hoặc **Update** ở mục 5 nếu bổ sung vào khóa đã có. Dùng link tài liệu Lark đã được chuẩn bị sẵn.

## 4. Luồng Gen — tạo khóa học mới

**Đầu vào:** một link Lark chứa thiết kế khóa học đầy đủ. Bạn không cần tạo sẵn khóa trên OPS.

**Trình tự:** gửi link → đăng nhập Lark khi được yêu cầu → kiểm tra bản dự kiến → duyệt → chọn môi trường và đăng nhập OPS → tạo khóa → kiểm tra trên LMS.

### Bước 1. Gửi yêu cầu

Trong khung chat, gõ `/` và chọn lệnh:

```text
/Course Builder: Ai Gen Course Lms + link tài liệu Lark
```
Trợ lý sẽ lập `outline.md` để bạn duyệt trước khi tạo trên LMS.

### Bước 2. Đăng nhập Lark nếu được yêu cầu

Trợ lý có thể mở trang đăng nhập hoặc gửi link để bạn mở. Đăng nhập bằng tài khoản có quyền đọc tài liệu và hoàn tất cấp quyền.

Trợ lý sẽ đọc tài liệu, tải ảnh/video về thư mục làm việc và tạo file `outline.md`. Đến đây, **chưa tạo khóa học trên LMS**.

### Bước 3. Kiểm tra và duyệt bản dự kiến

Mở file theo đường dẫn trợ lý gửi, ví dụ `planning-e2e/outline.md`, để xem bản dự kiến.

Nếu cần sửa, chỉnh trực tiếp file `outline.md`, lưu lại rồi nhắn:

```text
Tôi đã sửa outline.md. Hãy đọc lại file và cập nhật các mục liên quan
để tôi kiểm tra trước khi duyệt. Chưa tạo trên LMS.
```

Khi đồng ý với bản dự kiến, nhắn:

```text
Đã duyệt outline.md
```

### Bước 4. Chọn môi trường và đăng nhập OPS

Sau khi được duyệt, trợ lý mở hộp thoại đăng nhập. Bạn:

1. Chọn **Staging** nếu đang thử nghiệm hoặc **Prod** nếu tạo trên hệ thống chính thức.
2. Nhập tài khoản OPS trong hộp thoại riêng.
3. Kiểm tra thông báo của trợ lý về môi trường đang sử dụng trước khi tiếp tục.

Không suy ra môi trường từ lần chạy trước. Mỗi lượt đăng nhập đều cho bạn chọn lại. Liên hệ với admin để được cấp tài khoản OPS. (Không SSO qua lark)

### Bước 5. Nhận kết quả và kiểm tra trên LMS

Trợ lý tạo khóa, đưa ảnh/video và tài liệu lên LMS, dựng cấu trúc bài học, sau đó tạo câu hỏi và bài kiểm tra theo bản đã duyệt.

Bạn nhận báo cáo gồm link khóa học, số lượng nội dung đã tạo và các phần còn thiếu/cảnh báo. **Khóa mới ở trạng thái DRAFT — bản nháp**, chưa phải khóa đã phát hành.

Mở link khóa để xem kết quả. Việc hoàn thiện và phát hành khóa thực hiện theo quy trình vận hành của đội.

## 5. Luồng Update — bổ sung vào khóa đã có

**Đầu vào bắt buộc:** link khóa trên OPS và link Lark **chỉ chứa phần cần thêm**.

### 5.1. Update làm được những gì?

| Yêu cầu | Có hỗ trợ không? |
|---|---|
| Thêm Section mới, gồm các Activity, Tab, nội dung và mục tiêu học tập của Section mới | Có; nối sau Section cuối hiện có |
| Thêm Section Test cho Section cũ hoặc Section mới | Có |
| Thêm Mid Test hoặc Final Test cấp khóa | Có |
| Tạo câu hỏi đi kèm các bài kiểm tra trên | Có |
| Tạo Quiz trong Tab của Section mới | Có |
| Thêm Activity/Tab hoặc Quiz trong Tab của Section cũ | Không |
| Sửa/xóa nội dung cũ, sửa thông tin khóa, thay ảnh bìa hoặc thêm tài liệu cấp khóa | Không |

### Bước 1. Lấy hai link

Lấy link khóa trên OPS và link tài liệu Lark bổ sung đã chuẩn bị sẵn. Link khóa có dạng:

```text
https://uplms-ops.upbase.asia/course-full/[mã-khóa-học]
```

Sao chép link khóa thực tế từ OPS, đúng môi trường cần thao tác.

### Bước 2. Gửi yêu cầu

Trong khung chat, gõ `/` và chọn lệnh:

```text
/Course Builder: Ai Update Course Lms + Link khóa trên OPS: [Dán link khóa] + Link Lark chỉ chứa phần bổ sung: [Dán link Lark]
```

Trợ lý sẽ lập `outline.md` cho phần bổ sung để bạn duyệt trước khi thêm lên LMS.

### Bước 3. Đăng nhập và kiểm tra đúng khóa

Khác luồng Gen, trợ lý cần mở hộp thoại đăng nhập OPS **trước khi lập bản dự kiến**, để đọc tên khóa, các Section và bài kiểm tra đang có. Bước này chỉ đọc, chưa thêm nội dung.

Chọn môi trường phù hợp với link khóa, đăng nhập rồi kiểm tra **tên khóa mà trợ lý thông báo**. Nếu sai khóa, yêu cầu dừng và gửi lại link đúng.

Sau đó, đăng nhập Lark nếu được yêu cầu. Trợ lý đọc tài liệu bổ sung, tải ảnh/video và xuất `outline.md` trong một thư mục cập nhật riêng.

### Bước 4. Duyệt phần sẽ thêm

Ví dụ vị trí file: `planning-e2e/update-20261117-1430/outline.md`.

Mở file bản dự kiến theo đường dẫn trợ lý gửi. Nếu cần sửa, làm như bước duyệt của luồng Gen. Khi đồng ý, nhắn:

```text
Tôi duyệt outline.md. Hãy tiếp tục thêm nội dung vào khóa và môi trường đã ghi trong file.
```

### Bước 5. Đăng nhập lại và nhận kết quả

Sau khi duyệt, trợ lý mở lại hộp thoại OPS. Chọn **đúng môi trường đã ghi trong bản dự kiến** và đăng nhập.

Nếu số Section của khóa đã thay đổi từ lúc lập bản dự kiến, luồng sẽ dừng để lập lại bản dự kiến. Kiểm tra và duyệt lại trước khi tiếp tục.

Kết thúc, bạn nhận link khóa và danh sách Section/bài kiểm tra/câu hỏi đã thêm, kèm cảnh báo hoặc phần chưa hoàn thành. Luồng Update không tự phát hành khóa; kiểm tra trạng thái khóa trực tiếp trên OPS.

## 6. Lưu file làm việc

Giữ lại thư mục làm việc của khóa và của từng lượt cập nhật để có thể tiếp tục khi bị gián đoạn. Không tự xóa/sửa thư mục `work/` hoặc file `state.json`; đây là dữ liệu ghi nhận phần đã tạo.

## 7. Cập nhật plugin khi có bản mới

### Codex

Mở Terminal, chạy:

```bash
codex plugin marketplace upgrade lms-plugins
```

Sau đó khởi động lại Codex.

### Claude Code

Trong khung chat Claude Code, chạy lần lượt:

```text
/plugin marketplace update lms-plugins
/plugin update course-builder@lms-plugins
```

Sau đó khởi động lại Claude Code. Nếu muốn tự động cập nhật: vào `/plugin` → **Marketplaces** → chọn **lms-plugins** → bật **auto-update**.

Nếu đã cập nhật và khởi động lại nhưng chưa thấy thay đổi, báo người phụ trách plugin kiểm tra phiên bản đã phát hành. Không cần tự chỉnh các file cài đặt.