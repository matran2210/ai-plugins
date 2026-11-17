# lms-plugins

Bộ plugin LMS cho Claude Code và Codex. Mỗi plugin là một thư mục trong `plugins/`.

## Plugin hiện có

| Plugin | Skill | Việc |
|---|---|---|
| `course-builder` | `setup-course-builder` | Kiểm tra và tự cài công cụ hỗ trợ trên macOS, Linux/WSL và Windows |
| `course-builder` | `ai-gen-course-lms` | Dựng khóa học UpBase LMS từ tài liệu thiết kế trên Lark. Xem [README của skill](plugins/course-builder/skills/ai-gen-course-lms/README.md) |
| `course-builder` | `ai-update-course-lms` | Thêm Section mới, Section/Mid/Final Test và câu hỏi vào khóa đã có, từ link khóa OPS + tài liệu Lark. Dùng chung script của `ai-gen-course-lms` |

## Claude Code

### Cài

Trong Claude Code:

```text
/plugin marketplace add matran2210/ai-plugins
/plugin install course-builder@lms-plugins
```

Hoặc từ terminal:

```bash
claude plugin marketplace add matran2210/ai-plugins && claude plugin install course-builder@lms-plugins
```

Khởi động lại Claude Code.

### Cập nhật

```bash
claude plugin marketplace update lms-plugins && claude plugin update course-builder@lms-plugins
```

Trong Claude Code thì chạy lần lượt:

```text
/plugin marketplace update lms-plugins
/plugin update course-builder@lms-plugins
```

Khởi động lại Claude Code. Chỉ có bản mới khi `version` trong `.claude-plugin/plugin.json` đã được tăng.

Muốn tự cập nhật: `/plugin` → tab **Marketplaces** → chọn `lms-plugins` → bật auto-update.

## Codex

### Cài
Bước 1: Mở terminal và gõ lệnh:
```bash
codex plugin marketplace add matran2210/ai-plugins
```

Bước 2: Khởi động lại ứng dụng ChatGPT -> Codex
Bước 3: Ở thanh menu bên trái , chọn mục Plugins -> Tab Personal
Bước 4: Tìm và install plugin course-builder
Bước 5: Trong khung chat của codex, gõ /Course Builder: Ai Gen Course Lms để tạo course.
hoặc /Course Builder: Ai Update Course Lms để update thêm cấu phần học cho course mới.

### Cập nhật

```bash
codex plugin marketplace upgrade lms-plugins
```

Khởi động lại Codex. Chỉ có bản mới khi `version` trong `.codex-plugin/plugin.json` đã được tăng.



## Cài công cụ hỗ trợ cho Course Builder

Sau khi cài plugin, gửi trong chat:

```text
Dùng setup-course-builder để kiểm tra và cài các công cụ hỗ trợ còn thiếu trên máy này.
```

Script kiểm tra `bash`, `curl`, `jq`, `openssl`, `node` và `npx`; chỉ cài phần còn thiếu. Windows tự cài Git Bash nếu cần. Người dùng xác nhận quyền quản trị trực tiếp trên máy khi trình cài yêu cầu, rồi mở lại Codex/Claude Code sau khi hoàn tất.

Chạy trực tiếp từ bản repo nếu cần:

```bash
# macOS, Linux hoặc trong WSL
sh plugins/course-builder/scripts/setup-dependencies.sh
# Chỉ kiểm tra, không cài đặt
sh plugins/course-builder/scripts/setup-dependencies.sh --check
```

```powershell
# Windows, không cần cài Git Bash trước
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/course-builder/scripts/setup-dependencies.ps1
# Chỉ kiểm tra
powershell -NoProfile -ExecutionPolicy Bypass -File plugins/course-builder/scripts/setup-dependencies.ps1 -Check
```

macOS dùng Homebrew và tự cài Homebrew nếu chưa có; Linux/WSL hỗ trợ apt, dnf, yum, apk, pacman và zypper. Windows dùng WinGet (App Installer của Microsoft). Script không thiết lập kết nối Lark hoặc đăng nhập OPS.

Hướng dẫn thao tác cho đội vận hành: [Hướng dẫn Course Builder](HUONG_DAN_VAN_HANH_COURSE_BUILDER.md).

## Cấu trúc

```text
.claude-plugin/marketplace.json     danh sách plugin cho Claude Code
.agents/plugins/marketplace.json    danh sách plugin cho Codex
plugins/<tên-plugin>/
├── .claude-plugin/plugin.json      manifest cho Claude Code
├── .codex-plugin/plugin.json       manifest cho Codex
├── skills/<tên-skill>/SKILL.md     skill (mỗi skill một thư mục)
├── commands/                       (tùy chọn) slash command
├── agents/                         (tùy chọn) subagent
└── hooks/hooks.json                (tùy chọn) hook
.mcp.json                           server MCP dùng chung khi làm việc trong repo này
```

## Thêm plugin mới

1. Tạo `plugins/<tên-plugin>/.claude-plugin/plugin.json` và `plugins/<tên-plugin>/.codex-plugin/plugin.json` (bản Codex thêm `"skills": "./skills/"`):

   ```json
   {
     "name": "<tên-plugin>",
     "version": "0.1.0",
     "description": "<mô tả ngắn>"
   }
   ```

2. Đặt skill vào `plugins/<tên-plugin>/skills/<tên-skill>/SKILL.md`.
3. Thêm một mục vào mảng `plugins` của `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<tên-plugin>",
     "source": "./plugins/<tên-plugin>",
     "description": "<mô tả ngắn>",
     "version": "0.1.0"
   }
   ```

   và một mục vào `.agents/plugins/marketplace.json`:

   ```json
   {
     "name": "<tên-plugin>",
     "source": { "source": "local", "path": "./plugins/<tên-plugin>" },
     "policy": { "installation": "AVAILABLE", "authentication": "ON_INSTALL" },
     "category": "Productivity"
   }
   ```

4. Kiểm tra: `claude plugin validate .`
5. Người dùng đã thêm marketplace thì chạy `/plugin marketplace update lms-plugins` rồi `/plugin install <tên-plugin>@lms-plugins`.

Sửa plugin đã phát hành thì tăng `version` ở cả `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` lẫn `.claude-plugin/marketplace.json` — Claude Code và Codex dựa vào version để biết có bản mới.
