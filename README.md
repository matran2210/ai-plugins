# lms-plugins

Bộ plugin LMS cho Claude Code và Codex. Mỗi plugin là một thư mục trong `plugins/`.

## Plugin hiện có

| Plugin | Skill | Việc |
|---|---|---|
| `course-builder` | `ai-gen-course-lms` | Dựng khóa học UpBase LMS từ tài liệu thiết kế trên Lark. Xem [README của skill](plugins/course-builder/skills/ai-gen-course-lms/README.md) |

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

Repo private thì máy đó phải `git clone https://github.com/matran2210/ai-plugins.git` được trước.

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

```bash
codex plugin marketplace add matran2210/ai-plugins
```

Mở Codex, gõ `/plugins`, chọn tab marketplace **LMS Plugins**, cài `course-builder`. Khởi động lại Codex.

### Cập nhật

```bash
codex plugin marketplace upgrade lms-plugins
```

Khởi động lại Codex. Chỉ có bản mới khi `version` trong `.codex-plugin/plugin.json` đã được tăng.

## Sau khi cài

Plugin không mang theo cấu hình Lark. Mỗi máy tự làm thủ công theo mục **Cài đặt** trong [README của skill](plugins/course-builder/skills/ai-gen-course-lms/README.md): khai server MCP `lark`, khai `LARK_APP_ID` / `LARK_APP_SECRET`.

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
