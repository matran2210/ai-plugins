#!/usr/bin/env bash
# Cấu hình quiz của đối tượng course. Source file này; không chạy trực tiếp.
#
# QUIZ_CFG dùng chung cho cả bốn loại bài: Document QUIZ, Section Test,
# MID_TERM_TEST, FINAL_TEST. Mỗi chỗ gọi tự cộng thêm phần khác biệt
# (quiz_type, quiz_for, course_section_id) — xem build-section.sh và
# create-course-test.sh.
#
# quiz_questions ở đây luôn là []. Mỗi chỗ gọi tự thay bằng danh sách câu hỏi
# dựng từ --questions (xem build_quiz_questions trong lib.sh); bỏ cờ đó thì bài
# test tạo rỗng.
#
# Các cờ dưới đây là hardcode cho mọi bài, kể cả Midterm/Final — không cấu hình
# được theo từng bài. `is_graded` ở đây là của quiz và KHÁC hoàn toàn `is_graded`
# của Activity (cái đó lấy từ `"quiz": true` trong plan).
#
# Đây là một chuỗi JSON trải nhiều dòng, có ký tự xuống dòng nhúng. Giữ đúng cú
# pháp JSON: hỏng một dấu ngoặc là `--argjson cfg` fail ở MỌI lời gọi create(),
# không chỉ ở quiz.
QUIZ_CFG='{"quiz_question_mode":"ALL","is_published":true,"is_public":true,
"is_graded":false,"grading_method":"AUTO","grading_preference":"AFTER_ALL_QUESTIONS",
"required_percent_score":50,"is_limited":false,"is_tutor":true,
"quiz_question_type":"MULTIPLE_CHOICE","multiple_choice_multiplier":100,
"essay_multiplier":0,"score_distribution":"ALL_EVEN","quiz_questions":[]}'
