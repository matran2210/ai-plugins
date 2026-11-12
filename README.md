# lms-plugins

Bộ plugin LMS cho Claude Code. Mỗi plugin là một thư mục trong `plugins/`.

## Plugin hiện có

| Plugin | Skill | Việc |
|---|---|---|
| `course-builder` | `ai-gen-course-lms` | Dựng khóa học UpBase LMS từ tài liệu thiết kế trên Lark. Xem [README của skill](plugins/course-builder/skills/ai-gen-course-lms/README.md) |

## Cài

```text
/plugin marketplace add <đường dẫn hoặc git URL của repo>
/plugin install course-builder@lms-plugins
```

## Cấu trúc

```text
.claude-plugin/marketplace.json     danh sách plugin của marketplace
plugins/<tên-plugin>/
├── .claude-plugin/plugin.json      manifest của plugin
├── skills/<tên-skill>/SKILL.md     skill (mỗi skill một thư mục)
├── commands/                       (tùy chọn) slash command
├── agents/                         (tùy chọn) subagent
└── hooks/hooks.json                (tùy chọn) hook
.mcp.json                           server MCP dùng chung khi làm việc trong repo này
```

## Thêm plugin mới

1. Tạo `plugins/<tên-plugin>/.claude-plugin/plugin.json`:

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

4. Kiểm tra: `claude plugin validate .`
5. Người dùng đã thêm marketplace thì chạy `/plugin marketplace update lms-plugins` rồi `/plugin install <tên-plugin>@lms-plugins`.

Sửa plugin đã phát hành thì tăng `version` ở cả `plugin.json` lẫn `marketplace.json` — Claude Code dựa vào version để biết có bản mới.
