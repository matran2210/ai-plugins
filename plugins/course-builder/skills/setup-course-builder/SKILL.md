---
name: setup-course-builder
description: Kiểm tra và cài công cụ hỗ trợ cho plugin Course Builder trên macOS, Linux/WSL hoặc Windows. Dùng khi người dùng yêu cầu setup plugin, kiểm tra/cài bash, curl, jq, openssl, node, Git Bash hoặc báo thiếu các công cụ này. Không cấu hình Lark hay đăng nhập OPS.
---

# Setup Course Builder

Người vận hành chỉ cần biết máy cần công cụ hỗ trợ; script xử lý kiểm tra và cài đặt.

1. Lấy đúng Base directory khi skill được nạp. Hai script nằm ở `../../scripts/` so với thư mục skill này. Dùng đường dẫn tuyệt đối, không đoán đường dẫn cache và không đổi thư mục làm việc.
2. Chọn script theo hệ điều hành thực tế:
   - macOS/Linux/WSL: `sh "<plugin>/scripts/setup-dependencies.sh" --check`.
   - Windows native, kể cả chưa có Bash: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<plugin>\scripts\setup-dependencies.ps1" -Check`.
3. Nếu người dùng chỉ yêu cầu kiểm tra, báo kết quả và dừng. `--check`/`-Check` không cài đặt gì.
4. Nếu người dùng yêu cầu cài/setup và còn thiếu công cụ, chạy lại đúng script, bỏ cờ kiểm tra. Không yêu cầu người dùng tự cài từng công cụ. Việc cài đã nằm trong yêu cầu của họ.
5. Nếu trình cài cần nhập mật khẩu quản trị hoặc xác nhận của hệ điều hành, người dùng thao tác trực tiếp trên máy. Không nhận mật khẩu qua chat. Nếu môi trường agent không nhập được, cung cấp nguyên lệnh với đường dẫn thật để người dùng chạy trong Terminal/PowerShell của họ.
6. Windows: script in dòng `GIT BASH: <đường dẫn>`. Mọi script `.sh` của plugin phải chạy bằng đúng file đó, ví dụ `& "C:\Program Files\Git\bin\bash.exe" "<plugin>/skills/.../start.sh"`. Không gọi `bash` trần trong PowerShell/cmd: nó thường trỏ vào `C:\Windows\System32\bash.exe`, tức WSL, và báo lỗi nếu máy không có distro WSL. Agent đang chạy sẵn trong Git Bash (`uname -s` ra `MINGW*`) thì gọi `bash` như bình thường.
7. Đọc exit code và kết quả kiểm tra cuối. Chỉ báo sẵn sàng khi script thành công. Nếu dừng, nêu đúng công cụ/lý do và việc cần làm; không tự lặp cài vô hạn.

macOS dùng Homebrew (tự cài nếu thiếu); Linux/WSL dùng trình quản lý gói hệ điều hành; Windows dùng WinGet và tự cài Git Bash nếu chưa có. Node đi kèm `npx`, cũng được kiểm tra. Chạy lại sẽ bỏ qua công cụ đã có. Sau khi cài, nhắc đóng/mở lại Codex hoặc Claude Code để nhận PATH mới.

Bước này không đọc tài liệu Lark, không cấu hình Lark CLI/MCP và không tạo dữ liệu LMS.
